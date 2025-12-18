#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_URL="${REMOTE_FORWARD_BIN_URL:-https://nightly.link/codegod100/for/workflows/ci.yml/main/remote-forward.zip}"

cleanup() {
  if [[ -n "${WORKDIR:-}" && -d "${WORKDIR}" ]]; then
    rm -rf "${WORKDIR}"
  fi
}

WORKDIR="$(mktemp -d)"
trap cleanup EXIT

command -v curl >/dev/null 2>&1 || {
  echo "curl must be installed to download ${ARTIFACT_URL}" >&2
  exit 1
}

command -v unzip >/dev/null 2>&1 || {
  echo "unzip must be available to extract the prebuilt binary archive" >&2
  exit 1
}

ZIP_PATH="${WORKDIR}/remote-forward.zip"
curl -fsSL "${ARTIFACT_URL}" -o "${ZIP_PATH}"
unzip -q "${ZIP_PATH}" -d "${WORKDIR}"

BIN_PATH="$(find "${WORKDIR}" -type f -name 'remote-forward' -print -quit)"
if [[ -z "${BIN_PATH}" ]]; then
  echo "Failed to locate remote-forward binary in downloaded artifact" >&2
  exit 1
fi

chmod +x "${BIN_PATH}"
exec "${BIN_PATH}" "$@"
