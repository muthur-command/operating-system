import logging
from time import sleep

import pytest
from labgrid.driver import ExecutionError

from conftest import (
    _INIT_MODULE_TIMEOUT,
    disable_supervisor_autoupdate,
    wait_for_container,
    wait_for_mc_stack,
    wait_for_system_ready,
)


logger = logging.getLogger(__name__)


@pytest.fixture(scope="module")
def stash() -> dict:
    """Simple stash for sharing data between tests in this module."""
    stash = {}
    return stash


@pytest.mark.dependency()
@pytest.mark.timeout(_INIT_MODULE_TIMEOUT)
def test_start_supervisor(shell, shell_json):
    wait_for_container(shell, "mcos_supervisor")
    disable_supervisor_autoupdate(shell)

    wait_for_mc_stack(shell)
    wait_for_system_ready(shell)

    supervisor_ip = "\n".join(
        shell.run_check("docker inspect --format='{{.NetworkSettings.Networks.bridge.IPAddress}}' mcos_supervisor")
    )

    while True:
        try:
            if shell_json(f"curl -sSL http://{supervisor_ip}/supervisor/ping").get("result") == "ok":
                break
        except ExecutionError:
            pass  # avoid failure when the container is restarting

        sleep(1)


@pytest.mark.dependency(depends=["test_start_supervisor"])
def test_check_supervisor(shell_json):
    # check supervisor info
    supervisor_info = shell_json("mc supervisor info --no-progress --raw-json")
    assert supervisor_info.get("result") == "ok", "supervisor info failed"
    logger.info("Supervisor info: %s", supervisor_info)
    # check network info
    network_info = shell_json("mc network info --no-progress --raw-json")
    assert network_info.get("result") == "ok", "network info failed"
    logger.info("Network info: %s", network_info)


@pytest.mark.dependency(depends=["test_check_supervisor"])
@pytest.mark.timeout(120)
@pytest.mark.parametrize("component", ["supervisor", "audio", "cli", "dns", "observer", "multicast"])
def test_update_components(shell_json, component):
    info = shell_json(f"mc {component} info --no-progress --raw-json")
    version = info.get("data").get("version")
    version_latest = info.get("data").get("version_latest")
    assert version_latest, f"Missing latest {component} version info"
    if version == version_latest:
        logger.info("%s is already up to date", component)
        pytest.skip(f"{component} is already up to date")
    else:
        result = shell_json(f"mc {component} update --no-progress --raw-json")
        if result.get("result") == "error" and "Another job is running" in result.get("message"):
            pass
        else:
            assert result.get("result") == "ok", f"{component} update failed: {result}"

        while True:
            try:
                info = shell_json(f"mc {component} info --no-progress --raw-json")
                data = info.get("data")
                if data and data.get("version") == data.get("version_latest"):
                    logger.info(
                        "%s updated from %s to %s: %s",
                        component,
                        version,
                        data.get("version"),
                        info,
                    )
                    break
            except ExecutionError:
                pass  # avoid failure when the container is restarting

            sleep(1)


@pytest.mark.dependency(depends=["test_check_supervisor"])
def test_supervisor_is_updated(shell_json):
    supervisor_info = shell_json("mc supervisor info --no-progress --raw-json")
    data = supervisor_info.get("data")
    assert data and data.get("version") == data.get("version_latest")


@pytest.mark.dependency(depends=["test_supervisor_is_updated"])
def test_app_install(shell_json):
    # install Core SSH app
    assert (
        shell_json("mc apps install core_ssh --no-progress --raw-json").get("result") == "ok"
    ), "Core SSH app install failed"
    # check Core SSH app is installed
    assert (
        shell_json("mc apps info core_ssh --no-progress --raw-json").get("data", {}).get("version") is not None
    ), "Core SSH app not installed"
    # start Core SSH app
    assert (
        shell_json("mc apps start core_ssh --no-progress --raw-json").get("result") == "ok"
    ), "Core SSH app start failed"
    # check Core SSH app is running
    ssh_info = shell_json("mc apps info core_ssh --no-progress --raw-json")
    assert ssh_info.get("data", {}).get("state") == "started", "Core SSH app not running"
    logger.info("Core SSH app info: %s", ssh_info)


@pytest.mark.dependency(depends=["test_supervisor_is_updated"])
def test_supervisor_errors(shell_json):
    # run Supervisor health check
    health_check = shell_json("mc resolution healthcheck --no-progress --raw-json")
    assert health_check.get("result") == "ok", "Supervisor health check failed"
    logger.info("Supervisor health check result: %s", health_check)
    # get resolution center info
    resolution_info = shell_json("mc resolution info --no-progress --raw-json")
    logger.info("Resolution center info: %s", resolution_info)
    # check supervisor is healthy
    unhealthy = resolution_info.get("data").get("unhealthy")
    assert len(unhealthy) == 0, "Supervisor is unhealthy"
    # check for unsupported entries
    unsupported = resolution_info.get("data").get("unsupported")
    # generic-x86-64 dev images run under QEMU; OVA images are used in CI instead.
    os_board = shell_json("mc os info --no-progress --raw-json").get("data", {}).get("board")
    if os_board == "generic-x86-64":
        unsupported = [entry for entry in unsupported if entry != "virtualization_image"]
    assert len(unsupported) == 0, "Unsupported entries found"


@pytest.mark.dependency(depends=["test_supervisor_is_updated"])
def test_create_backup(shell_json, stash):
    result = shell_json("mc backups new --no-progress --raw-json")
    assert result.get("result") == "ok", f"Backup creation failed: {result}"
    slug = result.get("data", {}).get("slug")
    assert slug is not None
    stash.update(slug=slug)
    logger.info("Backup creation result: %s", result)


@pytest.mark.dependency(depends=["test_app_install"])
def test_app_uninstall(shell_json):
    result = shell_json("mc apps uninstall core_ssh --no-progress --raw-json")
    assert result.get("result") == "ok", f"Core SSH app uninstall failed: {result}"
    logger.info("Core SSH app uninstall result: %s", result)


@pytest.mark.dependency(depends=["test_supervisor_is_updated"])
@pytest.mark.timeout(120)
def test_restart_supervisor(shell, shell_json):
    result = shell_json("mc supervisor restart --no-progress --raw-json")
    assert result.get("result") == "ok", f"Supervisor restart failed: {result}"

    supervisor_ip = "\n".join(
        shell.run_check("docker inspect --format='{{.NetworkSettings.Networks.bridge.IPAddress}}' mcos_supervisor")
    )

    while True:
        try:
            if shell_json(f"curl -sSL http://{supervisor_ip}/supervisor/ping").get("result") == "ok":
                if shell_json("mc os info --no-progress --raw-json").get("result") == "ok":
                    break
        except ExecutionError:
            pass  # avoid failure when the container is restarting

        sleep(1)


@pytest.mark.dependency(depends=["test_create_backup"])
def test_restore_backup(shell_json, stash):
    result = shell_json(f"mc backups restore {stash.get('slug')} --app core_ssh --no-progress --raw-json")
    assert result.get("result") == "ok", f"Backup restore failed: {result}"
    logger.info("Backup restore result: %s", result)

    app_info = shell_json("mc apps info core_ssh --no-progress --raw-json")
    assert app_info.get("data", {}).get("version") is not None, "Core SSH app not installed"
    assert app_info.get("data", {}).get("state") == "started", "Core SSH app not running"
    logger.info("Core SSH app info: %s", app_info)


@pytest.mark.dependency(depends=["test_create_backup"])
def test_restore_ssl_directory(shell_json, stash):
    result = shell_json(f"mc backups restore {stash.get('slug')} --folders ssl --no-progress --raw-json")
    assert result.get("result") == "ok", f"Backup restore failed: {result}"
    logger.info("Backup restore result: %s", result)


@pytest.mark.dependency(depends=["test_start_supervisor"])
def test_no_apparmor_denies(shell):
    """Check there are no AppArmor denies in the logs raised during Supervisor tests."""
    output = shell.run_check("journalctl -t audit | grep DENIED || true")
    assert not output, f"AppArmor denies found: {output}"


@pytest.mark.dependency(depends=["test_start_supervisor"])
def test_kernel_not_tainted(shell):
    """Check if the kernel is not tainted - do it at the end of the
    test suite to increase the chance of catching issues."""
    output = shell.run_check("cat /proc/sys/kernel/tainted")
    assert "\n".join(output) == "0", f"Kernel tainted: {output}"
