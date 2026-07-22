#!/usr/bin/env bash
set -euo pipefail

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"
CORE_BIN="${CORE_BIN:-$HOME/.local/bin}"
CORE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/core-linux"
CORE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/core-linux"

PURGE=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--purge) PURGE=1; shift ;;
		*) echo "Unknown option: $1"; exit 1 ;;
	esac
done

echo "This will remove core-linux and all installed modules."
if [[ $PURGE -eq 0 ]]; then
	read -r -p "Continue? [y/N] " response
	[[ "$response" =~ ^[yY] ]] || exit 1
fi

echo "Removing binaries..."
rm -f "$CORE_BIN/core" "$CORE_BIN/core-tui"

echo "Removing installation..."
rm -rf "$CORE_HOME"

echo "Removing state..."
rm -rf "$CORE_STATE_DIR"

if [[ $PURGE -eq 1 ]]; then
	echo "Removing configuration..."
	rm -rf "$CORE_CONFIG_DIR"
fi

echo ""
echo "core-linux uninstalled."
if [[ $PURGE -eq 0 ]]; then
	echo "Configuration kept at $CORE_CONFIG_DIR — use --purge to remove"
fi
