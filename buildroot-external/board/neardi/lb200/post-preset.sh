#!/bin/bash
# Run after systemctl preset-all (see scripts/post-build.sh).
set -euo pipefail

for unit in mcos-data.service mcos-expand.service mcos-data-disk-detach.service \
	    mcos-wipe.service mcos-swapfile.service \
	    raucdb-update.service wpa_supplicant.service \
	    NetworkManager.service NetworkManager-wait-online.service \
	    NetworkManager-dispatcher.service systemd-resolved.service \
	    systemd-networkd-wait-online.service rpcbind.service rpcbind.socket \
	    nfs-server.service nfs-mountd.service; do
	ln -sf /dev/null "${TARGET_DIR}/etc/systemd/system/${unit}"
done

# MCOS supervisor: LB200 unit in /etc (no RAUC / network-online). Install after
# preset-all so multi-user.target.wants symlinks are not reset by preset.
rm -rf "${TARGET_DIR}/etc/systemd/system/mcos-supervisor.service.d"
cat > "${TARGET_DIR}/etc/systemd/system/mcos-supervisor.service" <<'EOF'
[Unit]
Description=MCOS supervisor
Wants=docker.service docker.socket containerd.service dbus.socket mcos-apparmor.service \
	systemd-journal-gatewayd.socket time-sync.target
Requires=dbus.socket
After=local-fs.target docker.socket containerd.service docker-prepare.service \
	docker.service dbus.socket mcos-apparmor.service \
	mnt-data.mount systemd-growfs@mnt-data.service mnt-overlay.mount mnt-boot.mount \
	mcos-rockchip-compat.service var-lib-docker.mount mcos-ethernet-bringup.service \
	systemd-journal-gatewayd.socket time-sync.target
RequiresMountsFor=/mnt/data /mnt/overlay /mnt/boot
StartLimitIntervalSec=30m
StartLimitBurst=3

[Service]
Type=simple
Restart=always
RestartSec=5s
ExecStartPre=-/usr/bin/docker stop mcos_supervisor
ExecStartPre=/usr/libexec/mcos-wait-docker
ExecStart=/usr/sbin/mcos-supervisor
ExecStop=-/usr/bin/docker stop mcos_supervisor
ExecStopPost=-/bin/rm -f /run/supervisor/startup-marker

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants"
for unit in docker.service mcos-apparmor.service; do
	ln -sf "/usr/lib/systemd/system/${unit}" \
		"${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/${unit}"
done
ln -sf /etc/systemd/system/mcos-supervisor.service \
	"${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/mcos-supervisor.service"
