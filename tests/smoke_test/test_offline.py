import logging
from time import sleep

import pytest
from labgrid.driver import ExecutionError

from conftest import (
    _INIT_MODULE_TIMEOUT,
    curl_mc_fd_web,
    wait_for_container,
    wait_for_mc_stack,
    wait_for_mc_fd_web,
)

_LOGGER = logging.getLogger(__name__)


def _check_connectivity(shell, *, connected):
    for target in ["muthur-command.com", "1.1.1.1"]:
        try:
            output = shell.run_check(f"ping {target}")
            if f"{target} is alive!" in output:
                if connected:
                    return True
                else:
                    raise AssertionError(f"expecting disconnected but {target} is alive")
        except ExecutionError as exc:
            if not connected:
                stdout = "\n".join(exc.stdout)
                assert ("Network is unreachable" in stdout
                        or "bad address" in stdout
                        or "No response" in stdout)

    if connected:
        raise AssertionError(f"expecting connected but all targets are down")


@pytest.mark.timeout(_INIT_MODULE_TIMEOUT)
@pytest.mark.usefixtures("without_internet")
def test_ha_runs_offline(shell):
    def check_container_running(container_name):
        out = shell.run_check(
            f"docker container inspect -f '{{{{.State.Status}}}}' {container_name} || true"
        )
        return "running" in out

    wait_for_container(shell, "mcos_supervisor")

    # wait for supervisor to create network
    while True:
        nm_conns = shell.run_check('nmcli con show')
        if "Supervisor" in " ".join(nm_conns):
            break
        sleep(1)

    # To simulate situation where MCOS is not connected to internet, we need to add
    # default gateway to the supervisor connection. So we add a default route to
    # a non-existing IP address in the VM's subnet. Maybe there is a better way?
    shell.run_check('nmcli con modify "Supervisor enp0s3" ipv4.addresses "192.168.76.10/24" '
                    '&& nmcli con modify "Supervisor enp0s3" ipv4.gateway 192.168.76.1 '
                    '&& nmcli device reapply enp0s3')

    _check_connectivity(shell, connected=False)

    wait_for_mc_stack(shell)
    wait_for_mc_fd_web(shell)

    web_index = curl_mc_fd_web(shell)
    assert "</html>" in " ".join(web_index)
