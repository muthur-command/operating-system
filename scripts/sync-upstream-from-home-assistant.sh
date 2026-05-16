#!/usr/bin/env bash
# 将 https://github.com/home-assistant/operating-system 默认分支（dev）
# 同步到本仓库的 upstream 分支，并推送到 origin。
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/home-assistant/operating-system.git}"
TRACK_BRANCH="${TRACK_BRANCH:-dev}"
LOCAL_BRANCH="${LOCAL_BRANCH:-upstream}"

if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
	git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

# Do not recurse into submodules while fetching HA: our default remote may still
# point at muthur-command/buildroot, but HA dev pins commits on home-assistant/buildroot.
git -c fetch.recurseSubmodules=false fetch "$UPSTREAM_REMOTE" "$TRACK_BRANCH"
git checkout -B "$LOCAL_BRANCH" "${UPSTREAM_REMOTE}/${TRACK_BRANCH}"
git submodule sync --recursive
git submodule update --init --recursive

git push --force-with-lease origin "$LOCAL_BRANCH"
