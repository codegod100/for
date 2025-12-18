#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REMOTE_FORWARD_REPO:-https://github.com/codegod100/for.git}"
REF="${REMOTE_FORWARD_REF:-main}"

cleanup() {
  if [[ -n "${WORKDIR:-}" && -d "${WORKDIR}" ]]; then
    rm -rf "${WORKDIR}"
  fi
}

WORKDIR="$(mktemp -d)"
trap cleanup EXIT

command -v git >/dev/null 2>&1 || {
  echo "git must be installed to clone ${REPO_URL}" >&2
  exit 1
}

command -v zig >/dev/null 2>&1 || {
  echo "zig must be installed and on PATH" >&2
  exit 1
}

git clone --depth 1 --branch "${REF}" "${REPO_URL}" "${WORKDIR}" >/dev/null
cd "${WORKDIR}"

# Ensure dependencies are downloaded and binary is built locally before running
zig build run -- "$@"
