#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_URL="${REMOTE_FORWARD_BIN_URL:-https://nightly.link/codegod100/for/workflows/ci.yml/main/remote-forward.zip}"

log() {
  printf '[remote-forward] %s\n' "$*" >&2
}

cleanup() {
  if [[ -n "${WORKDIR:-}" && -d "${WORKDIR}" ]]; then
    rm -rf "${WORKDIR}"
  fi
}

WORKDIR="$(mktemp -d)"
trap cleanup EXIT

command -v curl >/dev/null 2>&1 || {
  log "curl must be installed to download ${ARTIFACT_URL}"
  exit 1
}

command -v unzip >/dev/null 2>&1 || {
  log "unzip must be available to extract the prebuilt binary archive"
  exit 1
}

ZIP_PATH="${WORKDIR}/remote-forward.zip"
log "downloading artifact: ${ARTIFACT_URL}"
curl -fsSL "${ARTIFACT_URL}" -o "${ZIP_PATH}"
log "download complete; extracting"
unzip -q "${ZIP_PATH}" -d "${WORKDIR}"

BIN_PATH="$(find "${WORKDIR}" -type f -name 'remote-forward' -print -quit)"
if [[ -z "${BIN_PATH}" ]]; then
  log "failed to locate remote-forward binary in downloaded artifact"
  exit 1
fi

log "executing prebuilt binary: ${BIN_PATH}"
chmod +x "${BIN_PATH}"
exec "${BIN_PATH}" "$@"
