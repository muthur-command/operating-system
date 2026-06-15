import json
import logging
import os
from time import sleep

import pytest

from conftest import (
    _INIT_MODULE_TIMEOUT,
    disable_supervisor_autoupdate,
    expect_boot_slot,
    wait_for_container,
    wait_for_mc_stack,
    wait_for_mc_fd_web,
    wait_for_system_ready,
)

_LOGGER = logging.getLogger(__name__)


@pytest.mark.dependency()
@pytest.mark.timeout(_INIT_MODULE_TIMEOUT)
def test_init(shell, shell_json):
    wait_for_container(shell, "mcos_supervisor")
    disable_supervisor_autoupdate(shell)
    wait_for_mc_stack(shell)
    wait_for_mc_fd_web(shell)

    # wait for the system ready and Supervisor at the latest version
    while True:
        supervisor_info = "\n".join(shell.run_check("mc supervisor info --no-progress --raw-json || true"))
        # make sure not to fail when Supervisor is restarting
        supervisor_info = json.loads(supervisor_info) if supervisor_info.startswith("{") else None
        # make sure not to fail when Supervisor is in setup state
        supervisor_data = supervisor_info.get("data") if supervisor_info else None
        if supervisor_data and supervisor_data["version"] == supervisor_data["version_latest"]:
            output = "\n".join(shell.run_check("mc os info || true"))
            if "System is not ready" not in output:
                break

        sleep(5)


@pytest.mark.dependency(depends=["test_init"])
@pytest.mark.timeout(int(os.environ.get("OS_UPDATE_TEST_TIMEOUT", "7200" if os.environ.get("NO_KVM") else "600")))
def test_os_update(shell, shell_json, target):
    def check_container_running(container_name):
        out = shell.run_check(
            f"docker container inspect -f '{{{{.State.Status}}}}' {container_name} || true"
        )
        return "running" in out

    # fetch version info and OTA URL
    shell.run_check("mc su reload --no-progress")

    # update OS to latest stable - in tests it should never be the same version
    version_json = shell_json("curl -sSL https://version.muthur-command.com/stable.json")
    stable_version = (version_json["mcos"])["ova"]

    # Core (and maybe Supervisor) might be downloaded at this point, so we need to keep trying
    while True:
        output = "\n".join(shell.run_check(f"mc os update --no-progress --version {stable_version} || true", timeout=120))
        if "Don't have an URL for OTA updates" in output:
            shell.run_check("mc su reload --no-progress")
        elif "Command completed successfully" in output:
            break

        sleep(5)

    expect_boot_slot(shell, target)

    # temporary needed for OS 17.0 -> 16.x path, where all containers must be re-downloaded
    while True:
        if check_container_running("mcos_supervisor") and check_container_running("mcos_cli"):
            break

        sleep(1)

    # wait for the system to be ready after update
    while True:
        output = "\n".join(shell.run_check("mc os info || true"))
        if "System is not ready" not in output:
            break

        sleep(1)

    # check the updated version
    os_info = shell_json("mc os info --no-progress --raw-json")
    assert os_info["data"]["version"] == stable_version, "OS did not update successfully"


@pytest.mark.dependency(depends=["test_os_update"])
@pytest.mark.timeout(int(os.environ.get("BOOT_SLOT_TEST_TIMEOUT", "900" if os.environ.get("NO_KVM") else "180")))
def test_boot_other_slot(shell, shell_json, target):
    # switch to the other slot
    os_info = shell_json("mc os info --no-progress --raw-json")
    other_version = os_info["data"]["boot_slots"]["A"]["version"]

    # as we sometimes don't get another shell prompt after the boot slot switch,
    # use plain sendline instead of the run_check method
    shell.console.sendline(f"mc os boot-slot other --no-progress || true")

    expect_boot_slot(shell, target)

    # wait for the system to be ready after switching slots
    while True:
        output = "\n".join(shell.run_check("mc os info || true"))
        if "System is not ready" not in output:
            break

        sleep(1)

    # check that the boot slot has changed
    os_info = shell_json("mc os info --no-progress --raw-json")
    assert os_info["data"]["version"] == other_version
