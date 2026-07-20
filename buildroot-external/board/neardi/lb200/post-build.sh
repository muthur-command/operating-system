#!/bin/bash
# Neardi LB200 post-build: Rockchip A/B rootfs (no RAUC).
set -euo pipefail

# Persistent data on userdata; keep MCOS paths working via symlinks.
mkdir -p "${TARGET_DIR}/userdata"
mkdir -p "${TARGET_DIR}/mnt/udisk" "${TARGET_DIR}/mnt/sdcard"
ln -sf ../userdata "${TARGET_DIR}/udisk"
ln -sf udisk "${TARGET_DIR}/mnt/usb_storage"
ln -sf mnt/udisk "${TARGET_DIR}/mnt/usb_storage"

# Root filesystem on system_a / system_b
cat > "${TARGET_DIR}/etc/fstab" <<'EOF'
# <file system>  <mount point>  <type>  <options>         <dump>  <pass>
PARTLABEL=system_a  /              ext4    defaults,rw          0  1
PARTLABEL=oem       /oem           ext4    defaults             0  2
PARTLABEL=userdata  /userdata      ext4    defaults             0  2
EOF

# MCOS services expect /mnt/data, /mnt/overlay and /mnt/boot.  This board has
# no mcos-data/mcos-overlay/mcos-boot labelled partitions (Rockchip A/B GPT
# layout), so override the label-based units in /etc with real mounts:
#   /mnt/data    = ext4 on PARTLABEL=userdata
#   /mnt/overlay = bind of /mnt/data/overlay
#   /mnt/boot    = bind of /mnt/data/boot
mkdir -p "${TARGET_DIR}/mnt/boot" "${TARGET_DIR}/mnt/data" "${TARGET_DIR}/mnt/overlay"

cat > "${TARGET_DIR}/etc/systemd/system/mnt-data.mount" <<'EOF'
[Unit]
Description=MCOS data partition (Rockchip userdata)
DefaultDependencies=no
Requires=dev-disk-by\x2dpartlabel-userdata.device
After=dev-disk-by\x2dpartlabel-userdata.device
Before=umount.target local-fs.target
Conflicts=umount.target
Wants=systemd-growfs@mnt-data.service

[Mount]
What=/dev/disk/by-partlabel/userdata
Where=/mnt/data
Type=ext4
Options=commit=30

[Install]
WantedBy=local-fs.target
EOF

cat > "${TARGET_DIR}/etc/systemd/system/mcos-rockchip-compat.service" <<'EOF'
[Unit]
Description=MCOS path compatibility on Rockchip userdata layout
DefaultDependencies=no
Requires=mnt-data.mount
Wants=systemd-growfs@mnt-data.service
After=mnt-data.mount systemd-growfs@mnt-data.service
Before=mnt-overlay.mount mnt-boot.mount

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'mkdir -p /mnt/data/docker /mnt/data/overlay /mnt/data/boot'

[Install]
WantedBy=local-fs.target
EOF

cat > "${TARGET_DIR}/etc/systemd/system/mnt-overlay.mount" <<'EOF'
[Unit]
Description=MCOS overlay partition (bind on userdata)
DefaultDependencies=no
Requires=mnt-data.mount mcos-rockchip-compat.service
After=mnt-data.mount mcos-rockchip-compat.service
Before=umount.target local-fs.target
Conflicts=umount.target

[Mount]
What=/mnt/data/overlay
Where=/mnt/overlay
Type=none
Options=bind

[Install]
WantedBy=local-fs.target
EOF

cat > "${TARGET_DIR}/etc/systemd/system/mnt-boot.mount" <<'EOF'
[Unit]
Description=MCOS boot partition (bind on userdata)
DefaultDependencies=no
Requires=mnt-data.mount mcos-rockchip-compat.service
After=mnt-data.mount mcos-rockchip-compat.service
Before=umount.target local-fs.target
Conflicts=umount.target

[Mount]
What=/mnt/data/boot
Where=/mnt/boot
Type=none
Options=bind

[Install]
WantedBy=local-fs.target
EOF

mkdir -p "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants" \
	"${TARGET_DIR}/etc/systemd/system/local-fs.target.wants"
ln -sf /etc/systemd/system/mnt-data.mount \
	"${TARGET_DIR}/etc/systemd/system/local-fs.target.wants/mnt-data.mount"
ln -sf /etc/systemd/system/mnt-overlay.mount \
	"${TARGET_DIR}/etc/systemd/system/local-fs.target.wants/mnt-overlay.mount"
ln -sf /etc/systemd/system/mnt-boot.mount \
	"${TARGET_DIR}/etc/systemd/system/local-fs.target.wants/mnt-boot.mount"
ln -sf /etc/systemd/system/mcos-rockchip-compat.service \
	"${TARGET_DIR}/etc/systemd/system/local-fs.target.wants/mcos-rockchip-compat.service"

# Drop-ins from older LB200 images tried to patch rauc Requires via overrides;
# the full /etc unit is installed in post-preset.sh instead.
rm -rf "${TARGET_DIR}/etc/systemd/system/mcos-supervisor.service.d"

# Units tied to the mcos-data/mcos-boot filesystem labels do not exist on
# LB200 (Rockchip userdata layout). Disable via preset before preset-all; mask
# after preset in post-preset.sh so systemctl preset does not warn.
mkdir -p "${TARGET_DIR}/usr/lib/systemd/system-preset"
cat > "${TARGET_DIR}/usr/lib/systemd/system-preset/99-lb200-disable.preset" <<'EOF'
disable mcos-data.service
disable mcos-expand.service
disable mcos-data-disk-detach.service
disable mcos-wipe.service
disable mcos-swapfile.service
disable raucdb-update.service
disable wpa_supplicant.service
disable NetworkManager.service
disable NetworkManager-wait-online.service
disable NetworkManager-dispatcher.service
disable systemd-resolved.service
disable systemd-networkd-wait-online.service
disable rpcbind.service
disable rpcbind.socket
disable nfs-server.service
disable nfs-mountd.service
EOF

# No systemd-resolved on LB200: dhclient writes /etc/resolv.conf directly.
sed -i 's/^\(hosts:\).*$/\1 files dns/' "${TARGET_DIR}/etc/nsswitch.conf"
sed -i '/resolve/d' "${TARGET_DIR}/etc/nsswitch.conf"
grep -q '^hosts:' "${TARGET_DIR}/etc/nsswitch.conf" || echo 'hosts: files dns' >> "${TARGET_DIR}/etc/nsswitch.conf"
rm -f "${TARGET_DIR}/etc/systemd/resolved.conf"
rm -f "${TARGET_DIR}/etc/resolv.conf" "${TARGET_DIR}/etc/tmpfiles.d/nm.conf"
: > "${TARGET_DIR}/etc/resolv.conf"
chmod 0644 "${TARGET_DIR}/etc/resolv.conf"

# Docker must not reboot the board when userdata mounts are still settling.
mkdir -p "${TARGET_DIR}/etc/systemd/system/docker.service.d"
cat > "${TARGET_DIR}/etc/systemd/system/docker.service.d/lb200.conf" <<'EOF'
[Unit]
# Keep global FailureAction=reboot; ensure userdata/docker mounts are up first.
# LB200 has no NetworkManager; do not soft-block on network-online.
Wants=
Wants=var-lib-docker.mount docker-prepare.service containerd.service
After=mnt-data.mount systemd-growfs@mnt-data.service mnt-overlay.mount mnt-boot.mount \
	mcos-rockchip-compat.service mcos-bind.target var-lib-docker.mount \
	docker-prepare.service containerd.service
RequiresMountsFor=/mnt/data /var/lib/docker
EOF

mkdir -p "${TARGET_DIR}/etc/systemd/system/mcos-apparmor.service.d"
cat > "${TARGET_DIR}/etc/systemd/system/mcos-apparmor.service.d/lb200.conf" <<'EOF'
[Unit]
# Profile is pre-seeded on userdata; do not wait for network-online.
Wants=
Wants=time-sync.target
After=time-sync.target mnt-data.mount mcos-rockchip-compat.service
EOF

# Bring up GMAC (end0/end1) without NetworkManager: PHY init + LED + DHCP.
install -d "${TARGET_DIR}/usr/libexec"
cat > "${TARGET_DIR}/usr/libexec/mcos-ethernet-up" <<'EOF'
#!/bin/sh
# Do not call ip link at boot: kernel netdev open can wedge rtnl and freeze
# the serial shell (any ip(8) command blocks).  Bring-up runs after login via
# mcos-ethernet-bringup.service (multi-user.target).
exit 0
EOF
chmod 0755 "${TARGET_DIR}/usr/libexec/mcos-ethernet-up"

cat > "${TARGET_DIR}/usr/libexec/mcos-ethernet-down" <<'EOF'
#!/bin/sh
# Drop DHCP lease and IPv4 config when carrier is lost (cable unplug).
iface=${1:?iface required}
[ -e "/sys/class/net/${iface}" ] || exit 0

pf="/run/dhclient-${iface}.pid"

echo "mcos-ethernet: carrier down on ${iface}, flushing IPv4" > /dev/kmsg

if [ -f "$pf" ]; then
	pid=$(cat "$pf" 2>/dev/null)
	if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
		kill "$pid" 2>/dev/null || true
		sleep 1
		kill -9 "$pid" 2>/dev/null || true
	fi
	rm -f "$pf"
fi
# Also clear any orphaned dhclient for this iface.
pkill -f "dhclient.*${iface}" 2>/dev/null || true

ip -4 addr flush dev "${iface}" 2>/dev/null || true
while ip -4 route show default dev "${iface}" 2>/dev/null | grep -q .; do
	ip -4 route del default dev "${iface}" 2>/dev/null || break
done
EOF
chmod 0755 "${TARGET_DIR}/usr/libexec/mcos-ethernet-down"

cat > "${TARGET_DIR}/usr/libexec/mcos-ethernet-dhcp" <<'EOF'
#!/bin/sh
# Run dhclient in the foreground (-d) so systemd Type=simple keeps it alive.
# Without -d, dhclient daemonizes, the parent exits 0, and systemd KillMode
# (control-group) kills the child — so the interface never gets an IPv4 lease.
iface=${1:?iface required}
[ -e "/sys/class/net/${iface}" ] || exit 0

waited=0
while [ "$waited" -lt 30 ]; do
	if [ "$(cat "/sys/class/net/${iface}/carrier" 2>/dev/null)" = "1" ]; then
		break
	fi
	sleep 1
	waited=$((waited + 1))
done

if [ "$(cat "/sys/class/net/${iface}/carrier" 2>/dev/null)" != "1" ]; then
	echo "mcos-ethernet: ${iface} no carrier, skip DHCP" > /dev/kmsg
	exit 1
fi

pf="/run/dhclient-${iface}.pid"
lf="/var/lib/dhcp/dhclient-${iface}.leases"
sf="/sbin/dhclient-script"

# Ensure lease dir exists (tmpfiles may not have run yet).
mkdir -p /var/lib/dhcp /run

if [ -f "$pf" ]; then
	pid=$(cat "$pf" 2>/dev/null)
	if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
		kill "$pid" 2>/dev/null || true
		sleep 1
		kill -9 "$pid" 2>/dev/null || true
	fi
	rm -f "$pf"
fi
pkill -f "dhclient.*${iface}" 2>/dev/null || true

ip link set "${iface}" up
# Clear stale IPv4 so dhclient must rebind after replug.
ip -4 addr flush dev "${iface}" 2>/dev/null || true
while ip -4 route show default dev "${iface}" 2>/dev/null | grep -q .; do
	ip -4 route del default dev "${iface}" 2>/dev/null || break
done

echo "mcos-ethernet: starting dhclient -d on ${iface}" > /dev/kmsg
# -d: foreground (required for systemd Type=simple).
exec dhclient -4 -d -pf "$pf" -lf "$lf" -sf "$sf" "${iface}"
EOF
chmod 0755 "${TARGET_DIR}/usr/libexec/mcos-ethernet-dhcp"

cat > "${TARGET_DIR}/usr/libexec/mcos-ethernet-carrier" <<'EOF'
#!/bin/sh
# udev helper: ATTR{carrier} matching is racy; always re-check sysfs here.
iface=${1:?iface required}
[ -e "/sys/class/net/${iface}" ] || exit 0

# Small settle delay for PHY/link state.
sleep 1
carrier=$(cat "/sys/class/net/${iface}/carrier" 2>/dev/null || echo 0)
echo "mcos-ethernet: carrier event on ${iface}: ${carrier}" > /dev/kmsg

if [ "$carrier" = "1" ]; then
	/usr/bin/systemctl --no-block restart "mcos-ethernet-dhcp@${iface}.service"
else
	/usr/bin/systemctl --no-block stop "mcos-ethernet-dhcp@${iface}.service"
fi
EOF
chmod 0755 "${TARGET_DIR}/usr/libexec/mcos-ethernet-carrier"

cat > "${TARGET_DIR}/usr/libexec/mcos-ethernet-bringup" <<'EOF'
#!/bin/sh
# Bring up end0/end1, wait for PHY link, then DHCP via systemd unit.
wait_carrier_and_dhcp() {
	iface=$1
	[ -e "/sys/class/net/${iface}" ] || return
	echo "mcos-ethernet: bringing up ${iface}" > /dev/kmsg
	ip link set "${iface}" up || return
	waited=0
	while [ "$waited" -lt 60 ]; do
		if [ "$(cat "/sys/class/net/${iface}/carrier" 2>/dev/null)" = "1" ]; then
			break
		fi
		sleep 1
		waited=$((waited + 1))
	done
	if [ "$(cat "/sys/class/net/${iface}/carrier" 2>/dev/null)" != "1" ]; then
		echo "mcos-ethernet: ${iface} no carrier after ${waited}s" > /dev/kmsg
		return
	fi
	echo "mcos-ethernet: ${iface} carrier up after ${waited}s, start DHCP" > /dev/kmsg
	/usr/bin/systemctl --no-block restart "mcos-ethernet-dhcp@${iface}.service"
}

for iface in end0 end1; do
	wait_carrier_and_dhcp "${iface}" &
done
# Keep oneshot alive briefly so background waiters are past the first link set.
sleep 2
EOF
chmod 0755 "${TARGET_DIR}/usr/libexec/mcos-ethernet-bringup"

cat > "${TARGET_DIR}/etc/systemd/system/mcos-ethernet-bringup.service" <<'EOF'
[Unit]
Description=LB200 GMAC bring-up (end0/end1)
After=network-pre.target systemd-udev-trigger.service
Before=network.target
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
KillMode=process
ExecStart=/usr/libexec/mcos-ethernet-bringup
TimeoutStartSec=90s

[Install]
WantedBy=multi-user.target
EOF

# DHCP client package symlinks /var/lib/dhcp -> /tmp; use a persistent directory.
rm -rf "${TARGET_DIR}/var/lib/dhcp"
install -d -m 0755 "${TARGET_DIR}/var/lib/dhcp"
touch "${TARGET_DIR}/var/lib/dhcp/dhclient-end0.leases" \
	"${TARGET_DIR}/var/lib/dhcp/dhclient-end1.leases"
install -m 0755 "${BOARD_DIR}/dhclient-script" "${TARGET_DIR}/sbin/dhclient-script"

mkdir -p "${TARGET_DIR}/usr/lib/tmpfiles.d"
cat > "${TARGET_DIR}/usr/lib/tmpfiles.d/dhclient.conf" <<'EOF'
d /var/lib/dhcp 0755 - - -
EOF

cat > "${TARGET_DIR}/etc/systemd/system/mcos-ethernet-dhcp@.service" <<'EOF'
[Unit]
Description=LB200 DHCP on %i
BindsTo=sys-subsystem-net-devices-%i.device
After=sys-subsystem-net-devices-%i.device network-pre.target
ConditionPathExists=/sys/class/net/%i

[Service]
Type=simple
# dhclient runs with -d (foreground); keep it as MainPID.
KillMode=control-group
Restart=on-failure
RestartSec=3
ExecStart=/usr/libexec/mcos-ethernet-dhcp %i
ExecStop=/usr/libexec/mcos-ethernet-down %i

[Install]
WantedBy=multi-user.target
EOF

cat > "${TARGET_DIR}/usr/lib/udev/rules.d/70-lb200-ethernet.rules" <<'EOF'
# Do not match ATTR{carrier} here — it races with the change event.
# Delegate to a helper that re-reads sysfs and start/stops DHCP.
ACTION=="change", SUBSYSTEM=="net", KERNEL=="end[01]", \
	RUN+="/usr/libexec/mcos-ethernet-carrier %k"
EOF

cat > "${TARGET_DIR}/etc/systemd/system/mcos-ethernet.service" <<'EOF'
[Unit]
Description=LB200 GMAC early hook (no netdev open at boot)
DefaultDependencies=no
After=local-fs.target
Before=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=5s
ExecStart=/usr/libexec/mcos-ethernet-up

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/mcos-ethernet.service \
	"${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/mcos-ethernet.service"
ln -sf /etc/systemd/system/mcos-ethernet-bringup.service \
	"${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/mcos-ethernet-bringup.service"

# skwifi modprobe blocks multi-user for ~10s+; load driver in background on LB200.
mkdir -p "${TARGET_DIR}/etc/systemd/system/skwifi.service.d"
cat > "${TARGET_DIR}/etc/systemd/system/skwifi.service.d/lb200.conf" <<'EOF'
[Service]
TimeoutStartSec=15s
ExecStart=
ExecStart=/bin/sh -c '/sbin/modprobe skw_sdio_v20 && sleep 2 && /sbin/modprobe skw6316 & exit 0'
EOF

# Rockchip updateEngine writes slot metadata via /dev/block/by-name/<part>
mkdir -p "${TARGET_DIR}/usr/lib/udev/rules.d"
cat > "${TARGET_DIR}/usr/lib/udev/rules.d/61-rockchip-by-name.rules" <<'EOF'
# Rockchip tools (updateEngine) expect /dev/block/by-name/<partname>
ENV{DEVTYPE}=="partition", ENV{PARTNAME}=="?*", SYMLINK+="block/by-name/$env{PARTNAME}"
EOF

if [ -f "${TARGET_DIR}/usr/bin/updateEngine" ]; then
	cat > "${TARGET_DIR}/etc/systemd/system/rockchip-bootcontrol.service" <<'EOF'
[Unit]
Description=Rockchip A/B slot boot control
After=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/updateEngine --misc=now

[Install]
WantedBy=multi-user.target
EOF
	ln -sf /etc/systemd/system/rockchip-bootcontrol.service \
		"${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/rockchip-bootcontrol.service"
fi

# U-disk OTA helper (manual): updateEngine --update --image_url=/mnt/udisk/update-ota.img
install -d "${TARGET_DIR}/usr/local/sbin"
cat > "${TARGET_DIR}/usr/local/sbin/mcos-udisk-update" <<'EOF'
#!/bin/sh
set -e
IMG="${1:-/mnt/udisk/update-ota.img}"
if [ ! -f "$IMG" ]; then
	IMG="/mnt/udisk/update.img"
fi
if [ ! -f "$IMG" ]; then
	echo "No update image on U-disk (update-ota.img / update.img)" >&2
	exit 1
fi
exec /usr/bin/updateEngine --update --image_url="$IMG" --reboot
EOF
chmod 0755 "${TARGET_DIR}/usr/local/sbin/mcos-udisk-update"

cat > "${TARGET_DIR}/usr/libexec/mcos-wait-docker" <<'EOF'
#!/bin/sh
# docker.socket may be up while docker.service is still inactive (socket activation).
systemctl start docker.service 2>/dev/null || true
retries=60
while [ "$retries" -gt 0 ]; do
	if docker info >/dev/null 2>&1; then
		exit 0
	fi
	sleep 2
	retries=$((retries - 1))
done
echo "mcos-wait-docker: dockerd not ready" >&2
exit 1
EOF
chmod 0755 "${TARGET_DIR}/usr/libexec/mcos-wait-docker"

rm -f "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/raucdb-update.service"
