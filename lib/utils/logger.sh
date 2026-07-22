#!/usr/bin/env bash
set -euo pipefail

# Structured logger for core-linux
# Color-free safe fallbacks if colors.sh is not yet loaded.
#
# This file should be sourced AFTER colors.sh for full color output,
# but it degrades gracefully if colors.sh is unavailable.

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"

# Only source colors.sh if not already loaded (no-op if already present)
# Uses CORE_HOME instead of $0 to work when sourced from any context.
if ! declare -p COLORS &>/dev/null 2>&1; then
	if [[ -f "$CORE_HOME/lib/utils/colors.sh" ]]; then
		source "$CORE_HOME/lib/utils/colors.sh"
	fi
fi

# Safe color wrappers — use ANSI escapes only when colors are loaded
_log_color() {
	local key="$1"
	if declare -p COLORS &>/dev/null 2>&1 && type -t color_fg &>/dev/null; then
		color_fg "${COLORS[$key]:-}"
	fi
}

_log_reset() {
	if type -t color_reset &>/dev/null; then
		color_reset
	fi
}

_log_icon() {
	# Always show icons; color only if available
	local icon="$1"
	echo -n "$icon"
}

log_info()   { echo -e "$(_log_color secondary)$(_log_icon 'ℹ️') $*$(_log_reset)" >&2; }
log_warn()   { echo -e "$(_log_color warning)$(_log_icon '⚠️') $*$(_log_reset)" >&2; }
log_error()  { echo -e "$(_log_color error)$(_log_icon '❌') $*$(_log_reset)" >&2; }
log_success() { echo -e "$(_log_color success)$(_log_icon '✔️') $*$(_log_reset)" >&2; }
log_step()   { echo -e "$(_log_color primary)$(_log_icon '▶️') $*$(_log_reset)" >&2; }
log_debug()  { [[ "${CORE_DEBUG:-0}" == "1" ]] && echo -e "$(_log_color muted)$(_log_icon '🔍') $*$(_log_reset)" >&2; }
