import json
import logging
import os
from time import sleep

from labgrid.driver import ShellDriver
import pytest


logger = logging.getLogger(__name__)

DISABLE_AUTO_UPDATE_CMD = (
    "rm -f /run/supervisor/startup-marker"
    " && jq '.auto_update = false' /mnt/data/supervisor/updater.json > /tmp/updater.json"
    " && mv /tmp/updater.json /mnt/data/supervisor/updater.json"
    " && systemctl restart mcos-supervisor.service"
)


def wait_for_container(shell, container_name: str, *, timeout_s: int = 300) -> None:
    for _ in range(timeout_s):
        out = shell.run_check(
            f"docker container inspect -f '{{{{.State.Status}}}}' {container_name} || true"
        )
        if "running" in out:
            return
        sleep(1)
    shell.run_check(f"docker logs {container_name} 2>&1 | tail -80 || true")
    pytest.fail(f"container {container_name} not running after {timeout_s}s")


def disable_supervisor_autoupdate(shell) -> None:
    """Disable Supervisor auto-updates without triggering image corruption recovery."""
    shell.run_check(DISABLE_AUTO_UPDATE_CMD)


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
