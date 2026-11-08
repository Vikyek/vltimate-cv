#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
MAN_DIR="${HOME}/.local/share/man/man1"
INSTALL_SHARE="${HOME}/.local/share/vltimate-cv"

echo "=== Installing Vltimate CV ==="
mkdir -p "${BIN_DIR}" "${MAN_DIR}" "${INSTALL_SHARE}"

cp -rf "${SCRIPT_DIR}/cv_harvester_system_prompt.md" "${SCRIPT_DIR}/cv_template.html" \
       "${SCRIPT_DIR}/harvest_cv.sh" "${SCRIPT_DIR}/scripts" "${SCRIPT_DIR}/config" "${INSTALL_SHARE}/"
chmod +x "${INSTALL_SHARE}/harvest_cv.sh"

ln -sf "${INSTALL_SHARE}/harvest_cv.sh" "${BIN_DIR}/vltimate-cv"

if [[ -f "${SCRIPT_DIR}/man/man1/vltimate-cv.1" ]]; then
    install -Dm644 "${SCRIPT_DIR}/man/man1/vltimate-cv.1" "${MAN_DIR}/vltimate-cv.1"
    echo "Installed man page to ${MAN_DIR}/vltimate-cv.1"
fi

echo "Vltimate CV installed successfully! Run: vltimate-cv --help"
