import json
import logging
import os
from time import sleep

from labgrid.driver import ExecutionError, ShellDriver
import pytest


logger = logging.getLogger(__name__)

# Without KVM, QEMU is much slower; allow longer waits (override via env).
_SLOW_ENV = bool(os.environ.get("NO_KVM"))
_CONTAINER_TIMEOUT = int(os.environ.get("CONTAINER_TIMEOUT", "900" if _SLOW_ENV else "300"))
_MC_STACK_TIMEOUT = int(os.environ.get("MC_STACK_TIMEOUT", "3600" if _SLOW_ENV else "600"))
_SYSTEM_READY_TIMEOUT = int(os.environ.get("SYSTEM_READY_TIMEOUT", "900" if _SLOW_ENV else "300"))
_MC_FD_WEB_TIMEOUT = int(os.environ.get("MC_FD_WEB_TIMEOUT", "300" if _SLOW_ENV else "60"))
_REBOOT_EXPECT_TIMEOUT = int(os.environ.get("REBOOT_EXPECT_TIMEOUT", "600" if _SLOW_ENV else "60"))
_INIT_MODULE_TIMEOUT = int(os.environ.get("INIT_MODULE_TIMEOUT", "7200" if _SLOW_ENV else "600"))
_POLL_CMD_TIMEOUT = 30 if _SLOW_ENV else 15

_DISABLE_AUTO_UPDATE_APPLY_CMD = (
    "jq '.auto_update = false' /mnt/data/supervisor/updater.json > /tmp/updater.json"
    " && mv /tmp/updater.json /mnt/data/supervisor/updater.json"
    " && systemctl restart mcos-supervisor.service"
)

# MC application stack containers (replaces legacy ``muthurcommand`` when unused).
MC_STACK_CONTAINERS = (
    "mcos_mc_postgres",
    "mcos_mc_redis",
    "mcos_mc_bd",
    "mcos_mc_fd",
)


def check_container_running(shell, container_name: str) -> bool:
    out = shell.run_check(
        f"docker container inspect -f '{{{{.State.Status}}}}' {container_name} || true",
        timeout=_POLL_CMD_TIMEOUT,
    )
    return "running" in out


def wait_for_container(shell, container_name: str, *, timeout_s: int | None = None) -> None:
    if timeout_s is None:
        timeout_s = _CONTAINER_TIMEOUT
    for _ in range(timeout_s):
        out = shell.run_check(
            f"docker container inspect -f '{{{{.State.Status}}}}' {container_name} || true",
            timeout=_POLL_CMD_TIMEOUT,
        )
        if "running" in out:
            return
        sleep(1)
    shell.run_check(f"docker logs {container_name} 2>&1 | tail -80 || true")
    pytest.fail(f"container {container_name} not running after {timeout_s}s")


def wait_for_mc_stack(shell, *, timeout_s: int | None = None) -> None:
    """Wait until all MC stack containers are running."""
    if timeout_s is None:
        timeout_s = _MC_STACK_TIMEOUT
    for _ in range(timeout_s):
        if all(check_container_running(shell, name) for name in MC_STACK_CONTAINERS):
            return
        sleep(1)
    for name in MC_STACK_CONTAINERS:
        shell.run_check(f"docker logs {name} 2>&1 | tail -40 || true")
    pytest.fail(f"MC stack not running after {timeout_s}s")


def wait_for_system_ready(shell, *, timeout_s: int | None = None) -> None:
    """Wait until ``mc os info`` reports the system is ready."""
    if timeout_s is None:
        timeout_s = _SYSTEM_READY_TIMEOUT
    for _ in range(timeout_s):
        output = "\n".join(shell.run_check("mc os info || true"))
        if "System is not ready" not in output and "connection refused" not in output:
            return
        sleep(1)
    pytest.fail(f"system not ready after {timeout_s}s")


_MC_FD_WEB_PROBE = (
    "sh -c '"
    "curl -sf --connect-timeout 3 --max-time 10 http://127.0.0.1:8123/ 2>/dev/null && exit 0; "
    "for c in mcos_mc_fd mcos_landingpage; do "
    "ip=$(docker inspect -f \"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}\" \"$c\" 2>/dev/null); "
    "[ -n \"$ip\" ] && curl -sf --connect-timeout 3 --max-time 10 \"http://${ip}/\" 2>/dev/null && exit 0; "
    "done; exit 1'"
)


def wait_for_mc_fd_web(shell, *, timeout_s: int | None = None) -> list[str]:
    """Wait until the MC frontend answers HTTP on host :8123 or container IP."""
    if timeout_s is None:
        timeout_s = _MC_FD_WEB_TIMEOUT
    for _ in range(timeout_s):
        try:
            return shell.run_check(_MC_FD_WEB_PROBE, timeout=_POLL_CMD_TIMEOUT)
        except ExecutionError:
            sleep(1)
    shell.run_check("docker ps --filter name=mcos_mc --filter name=mcos_landingpage 2>&1 || true")
    shell.run_check("curl -sv --max-time 5 http://127.0.0.1:8123/ 2>&1 | tail -30 || true")
    pytest.fail(f"MC frontend not reachable after {timeout_s}s")


def curl_mc_fd_web(shell) -> list[str]:
    """Fetch the mc_fd login page via host port or container bridge network."""
    return wait_for_mc_fd_web(shell)


def expect_boot_slot(shell, target) -> None:
    """Wait for GRUB slot boot after reboot and re-login via ShellDriver."""
    shell.console.expect("Booting `Slot ", timeout=_REBOOT_EXPECT_TIMEOUT)
    target.deactivate(shell)
    target.activate(shell)


def disable_supervisor_autoupdate(shell) -> None:
    """Disable Supervisor auto-updates without triggering image corruption recovery."""
    already_disabled = shell.run_check(
        "jq -e '.auto_update == false' /mnt/data/supervisor/updater.json >/dev/null 2>&1; echo $?"
    )
    if already_disabled and already_disabled[-1].strip() == "0":
        return

    shell.run_check(
        "rm -f /run/supervisor/startup-marker && " + _DISABLE_AUTO_UPDATE_APPLY_CMD
    )
    # Restart stops all managed containers; wait for Supervisor before MC stack checks.
    wait_for_container(shell, "mcos_supervisor")


@pytest.fixture(scope="function")
def without_internet(strategy):
    default_nic = strategy.qemu.nic
    if strategy.status.name == "shell":
        strategy.transition("off")
    strategy.qemu.nic = "user,net=192.168.76.0/24,dhcpstart=192.168.76.10,restrict=yes"
    strategy.transition("shell")
    yield
    strategy.transition("off")
    strategy.qemu.nic = default_nic


@pytest.fixture(autouse=True, scope="module")
def restart_qemu(strategy):
    """Use fresh QEMU instance for each module."""
    if strategy.status.name == "shell":
        logger.info("Restarting QEMU before %s module tests.", strategy.target.name)
        strategy.transition("off")
        strategy.transition("shell")


@pytest.hookimpl
def pytest_runtest_setup(item):
    log_dir = item.config.option.lg_log

    if not log_dir:
        return

    logging_plugin = item.config.pluginmanager.get_plugin("logging-plugin")
    log_name = item.nodeid.replace(".py::", "/")
    logging_plugin.set_log_path(os.path.join(log_dir, f"{log_name}.log"))


@pytest.fixture
def shell(target, strategy) -> ShellDriver:
    """Fixture for accessing shell."""
    strategy.transition("shell")
    shell = target.get_driver("ShellDriver")
    return shell


@pytest.fixture
def shell_json(target, strategy) -> callable:
    """Fixture for running CLI commands returning JSON string as output."""
    strategy.transition("shell")
    shell = target.get_driver("ShellDriver")

    def get_json_response(command, *, timeout=None) -> dict:
        return json.loads("\n".join(shell.run_check(command, timeout=timeout)))

    return get_json_response
