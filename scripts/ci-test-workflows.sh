#!/usr/bin/env bash
# Local CI workflow smoke tests (no Buildroot build).
# Usage: ./scripts/ci-test-workflows.sh [--skip-actionlint]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

SKIP_ACTIONLINT=false
for arg in "$@"; do
  case "${arg}" in
    --skip-actionlint) SKIP_ACTIONLINT=true ;;
    -h|--help)
      echo "Usage: $0 [--skip-actionlint]"
      exit 0
      ;;
    *) echo "Unknown option: ${arg}" >&2; exit 2 ;;
  esac
done

pass=0
fail=0

run_case() {
  local name="$1"
  shift
  if "$@"; then
    echo "  OK  ${name}"
    pass=$((pass + 1))
  else
    echo "  FAIL ${name}" >&2
    fail=$((fail + 1))
  fi
}

# --- Mirrors build.yaml "Get channel" step ---
resolve_channel_outputs() {
  local event_name="$1"
  local prerelease="$2"
  local mcio_channel="$3"

  if [[ "${event_name}" == "release" ]]; then
    if [[ "${prerelease}" == "true" ]]; then
      CHANNEL=beta
    else
      CHANNEL=stable
    fi
  else
    CHANNEL=dev
  fi

  if [[ -z "${mcio_channel}" || "${mcio_channel}" == "default" ]]; then
    if [[ "${event_name}" == "release" ]]; then
      MCIO_CHANNEL_OPTION=BR2_PACKAGE_MCIO_CHANNEL_STABLE
    else
      MCIO_CHANNEL_OPTION=BR2_PACKAGE_MCIO_CHANNEL_DEV
    fi
  elif [[ "${mcio_channel}" == "stable" ]]; then
    MCIO_CHANNEL_OPTION=BR2_PACKAGE_MCIO_CHANNEL_STABLE
  elif [[ "${mcio_channel}" == "beta" ]]; then
    MCIO_CHANNEL_OPTION=BR2_PACKAGE_MCIO_CHANNEL_BETA
  elif [[ "${mcio_channel}" == "dev" ]]; then
    MCIO_CHANNEL_OPTION=BR2_PACKAGE_MCIO_CHANNEL_DEV
  else
    return 1
  fi
}

assert_channel() {
  local event_name="$1" prerelease="$2" mcio_channel="$3"
  local want_channel="$4" want_mcio="$5"

  resolve_channel_outputs "${event_name}" "${prerelease}" "${mcio_channel}" || return 1
  [[ "${CHANNEL}" == "${want_channel}" && "${MCIO_CHANNEL_OPTION}" == "${want_mcio}" ]]
}

# --- Mirrors check_publish step ---
resolve_publish_build() {
  local repo="$1" publish_flag="$2" event_name="$3"

  if [[ "${repo}" == "muthur-command/operating-system" ]]; then
    if [[ "${publish_flag}" != "true" && "${event_name}" != "release" ]]; then
      PUBLISH_BUILD=false
    else
      PUBLISH_BUILD=true
    fi
  else
    PUBLISH_BUILD=false
  fi
}

test_channel_matrix() {
  assert_channel workflow_dispatch false default dev BR2_PACKAGE_MCIO_CHANNEL_DEV &&
  assert_channel workflow_dispatch false stable dev BR2_PACKAGE_MCIO_CHANNEL_STABLE &&
  assert_channel workflow_dispatch false beta dev BR2_PACKAGE_MCIO_CHANNEL_BETA &&
  assert_channel workflow_dispatch false dev dev BR2_PACKAGE_MCIO_CHANNEL_DEV &&
  assert_channel release false "" stable BR2_PACKAGE_MCIO_CHANNEL_STABLE &&
  # prerelease sets version channel=beta; MCIO default on release stays STABLE
  assert_channel release true "" beta BR2_PACKAGE_MCIO_CHANNEL_STABLE &&
  assert_channel release false stable stable BR2_PACKAGE_MCIO_CHANNEL_STABLE
}

test_publish_matrix() {
  resolve_publish_build muthur-command/operating-system false workflow_dispatch
  [[ "${PUBLISH_BUILD}" == "false" ]] &&
  resolve_publish_build muthur-command/operating-system true workflow_dispatch &&
  [[ "${PUBLISH_BUILD}" == "true" ]] &&
  resolve_publish_build muthur-command/operating-system false release &&
  [[ "${PUBLISH_BUILD}" == "true" ]] &&
  resolve_publish_build fork/operating-system true workflow_dispatch &&
  [[ "${PUBLISH_BUILD}" == "false" ]]
}

test_version_meta() {
  # shellcheck disable=SC1091
  . "${ROOT}/buildroot-external/meta"
  [[ -n "${VERSION_MAJOR}" && -n "${VERSION_MINOR}" ]]
}

test_matrix_json() {
  node -e "
const fs = require('fs');
const boards = require('./.github/workflows/matrix.json');
if (!Array.isArray(boards) || boards.length === 0) process.exit(1);
const ids = new Set();
for (const b of boards) {
  if (!b.id || !b.defconfig) process.exit(2);
  if (ids.has(b.id)) process.exit(3);
  ids.add(b.id);
}
const partial = boards.filter(b => ['ova','rpi4-64'].includes(b.id));
if (partial.length !== 2) process.exit(4);
console.log('boards:', boards.length);
"
}

test_matrix_adds_ova_for_tests() {
  node -e "
const boards = require('./.github/workflows/matrix.json');
const boardFilter = 'rpi4-64';
const runTests = true;
const boardSet = new Set(boardFilter.split(','));
if (runTests && !boardSet.has('ova')) boardSet.add('ova');
const buildBoards = boards.filter(b => boardSet.has(b.id));
if (buildBoards.length !== 2) process.exit(1);
if (!buildBoards.some(b => b.id === 'ova')) process.exit(2);
"
}

test_build_summary_fixture() {
  local tmp="${ROOT}/.ci-test-tmp-build-summary"
  rm -rf "${tmp}"
  mkdir -p "${tmp}/output/build/mcio-1.0.0" "${tmp}/output/images"
  cp scripts/ci-fixtures/mcio-version.json "${tmp}/output/build/mcio-1.0.0/version.json"
  touch "${tmp}/output/images/mcos_ova-test.img.xz"

  (
    cd "${tmp}"
    export GITHUB_STEP_SUMMARY="${tmp}/summary.md"
    : > "${GITHUB_STEP_SUMMARY}"

    version_json=(output/build/mcio-*/version.json)
    [[ -f "${version_json[0]}" ]] || exit 1
    VERSION_JSON="${version_json[0]}"

    supervisor_version=$(jq -r ".supervisor" "${VERSION_JSON}")
    mc_fd_version=$(jq -r '.mc_fd // empty' "${VERSION_JSON}")
    mc_bd_version=$(jq -r ".mc_bd // empty" "${VERSION_JSON}")

    [[ "${supervisor_version}" == "2026.05.1" ]] || exit 2
    [[ "${mc_fd_version}" == "1.2.3" ]] || exit 3
    [[ "${mc_bd_version}" == "0.1.0" ]] || exit 4

    for plugin in dns audio cli multicast observer; do
      jq -e ".${plugin}" "${VERSION_JSON}" >/dev/null || exit 5
    done

    for f in output/images/mcos_*; do
      test -f "${f}" || exit 6
    done
  )
  rm -rf "${tmp}"
}

test_defconfig_board_ids() {
  node -e "
const fs = require('fs');
const path = require('path');
const boards = require('./.github/workflows/matrix.json');
for (const b of boards) {
  const def = path.join('buildroot-external/configs', b.defconfig + '_defconfig');
  if (!fs.existsSync(def)) {
    console.error('missing defconfig for board', b.id, def);
    process.exit(1);
  }
}
"
}

test_actionlint() {
  command -v actionlint >/dev/null
  # Composite actions under .github/actions/ are not workflows; lint them via workflow refs only.
  actionlint .github/workflows/*.yaml .github/workflows/*.yml
}

echo "=== MCOS workflow local tests ==="

if [[ "${SKIP_ACTIONLINT}" == "false" ]]; then
  echo "--- Layer 1: actionlint ---"
  run_case "actionlint" test_actionlint
else
  echo "--- Layer 1: actionlint (skipped) ---"
fi

echo "--- Layer 2: prepare logic ---"
run_case "channel matrix" test_channel_matrix
run_case "publish_build matrix" test_publish_matrix
run_case "version meta loads" test_version_meta
run_case "matrix.json structure" test_matrix_json
run_case "matrix adds ova when run_tests" test_matrix_adds_ova_for_tests
run_case "defconfig exists for each board" test_defconfig_board_ids

echo "--- Layer 3: build job helpers ---"
run_case "build summary + version.json fixture" test_build_summary_fixture

echo ""
echo "Results: ${pass} passed, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
echo "All local workflow tests passed."
