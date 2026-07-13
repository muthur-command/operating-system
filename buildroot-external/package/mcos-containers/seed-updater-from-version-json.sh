#!/usr/bin/env bash
# Build a supervisor updater.json snapshot from the channel version.json fetched
# at MCOS image build time. Enables MC stack / plugins on first boot without
# waiting for a successful online version fetch.
#
# Usage: seed-updater-from-version-json.sh <version.json> <channel> <output>

set -euo pipefail

version_json="${1:?version.json path required}"
channel="${2:?channel required}"
output="${3:?output path required}"

if [[ ! -f "${version_json}" ]]; then
	echo "::error::seed-updater: missing ${version_json}" >&2
	exit 1
fi

jq --arg channel "${channel}" '
  {
    channel: $channel,
    supervisor: .supervisor,
    cli: .cli,
    dns: .dns,
    audio: .audio,
    observer: .observer,
    multicast: .multicast,
    mc_bd: .mc_bd,
    mc_fd: .mc_fd,
    landingpage: .landingpage,
    postgresql: .postgresql,
    redis: .redis,
    mcos_upgrade: .mcos_upgrade,
    ota: .ota,
    image: (
      .images
      | if .mc_bd and (.muthurcommand == null) then
          . + {muthurcommand: .mc_bd}
        else
          .
        end
    )
  }
  | with_entries(select(.value != null))
' "${version_json}" > "${output}"
