#!/bin/bash
set -e

USER="root"

# Optional registry mirror for nested dockerd (e.g. when Docker Hub is slow/blocked).
if [ -n "${DOCKER_REGISTRY_MIRROR:-}" ]; then
	mkdir -p /etc/docker /etc/containers/registries.conf.d
	printf '%s\n' \
		'{' \
		"  \"registry-mirrors\": [\"${DOCKER_REGISTRY_MIRROR}\"]" \
		'}' \
		> /etc/docker/daemon.json

	# skopeo does not read daemon.json; mirror docker.io the same way.
	mirror_host="${DOCKER_REGISTRY_MIRROR#*://}"
	mirror_host="${mirror_host%%/*}"
	printf '%s\n' \
		'[[registry]]' \
		'prefix = "docker.io"' \
		'location = "docker.io"' \
		'' \
		'[[registry.mirror]]' \
		"location = \"${mirror_host}\"" \
		> /etc/containers/registries.conf.d/000-docker-mirror.conf
fi

# Nested dockerd often has no IPv6 route but still resolves AAAA records first.
if [ "${MCOS_CONTAINERS_DISABLE_IPV6:-1}" = "1" ]; then
	sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1 || true
	sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null 2>&1 || true
fi

# Run dockerd
dockerd -s vfs &> /dev/null &


# Setup local group, if not existing
if [ "${BUILDER_GID:-0}" -ne 0 ] && ! getent group "${BUILDER_GID:-0}"; then
  groupadd -g "${BUILDER_GID}" builder
fi

# Setup local user
if [ "${BUILDER_UID:-0}" -ne 0 ]; then
  useradd -m -u "${BUILDER_UID}" -g "${BUILDER_GID}" -G docker,sudo builder
  echo "builder ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
  # Make sure cache is accessible by builder
  chown "${BUILDER_UID}:${BUILDER_GID}" /cache
  # Make sure output is accessible by builder (if anonymous volume is used)
  chown "${BUILDER_UID}:${BUILDER_GID}" /build/output || true
  USER="builder"
fi

if CMD="$(command -v "$1")"; then
  shift
  sudo -H -u ${USER} "$CMD" "$@"
else
  echo "Command not found: $1"
  exit 1
fi
