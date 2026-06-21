#!/usr/bin/env bash
# Install personal skills from this repo into ~/.cursor/skills/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${REPO_DIR}/.cursor/skills"
DEST="${HOME}/.cursor/skills"

if [[ ! -d "${SRC}" ]]; then
  echo "error: ${SRC} not found" >&2
  exit 1
fi

mkdir -p "${DEST}"

for skill in "${SRC}"/*/; do
  name="$(basename "${skill}")"
  if [[ -e "${DEST}/${name}" ]]; then
    echo "skip: ${DEST}/${name} already exists"
  else
    cp -R "${skill}" "${DEST}/${name}"
    echo "installed: ${name}"
  fi
done

echo "done. Skills available at ${DEST}"
