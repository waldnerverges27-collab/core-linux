#!/usr/bin/env bash
set -euo pipefail

# Color system for core-linux
# Reads theme from config.toml, never emits raw ANSI codes.
#
# Idempotent: safe to source multiple times. Already-loaded
# check prevents redeclaring the associative array.

CORE_CONFIG="${CORE_CONFIG:-$HOME/.config/core-linux/config.toml}"
CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"

# Guard: avoid re-declaring COLORS if already sourced
if ! declare -p COLORS &>/dev/null 2>&1; then
	declare -A COLORS
else
	# Already loaded — just re-run load_theme to apply any config change
	:
fi

load_theme() {
	local theme="${1:-catppuccin-mocha}"
	local theme_file="$CORE_HOME/lib/tui/themes/$theme.toml"

	COLORS=(
		[primary]="#cba6f7"
		[secondary]="#89b4fa"
		[accent]="#f38ba8"
		[success]="#a6e3a1"
		[warning]="#f9e2af"
		[error]="#f38ba8"
		[bg]="#1e1e2e"
		[surface]="#313244"
		[text]="#cdd6f4"
		[muted]="#6c7086"
		[border]="#45475a"
	)

	if [[ -f "$theme_file" ]]; then
		while IFS='= ' read -r key value; do
			key="${key// /}"
			[[ -z "$key" || "$key" == "["* || "$key" == "#"* ]] && continue
			value="${value#\"}"; value="${value%\"}"
			value="${value#\'}"; value="${value%\'}"
			value="${value// /}"
			[[ -n "$value" ]] && COLORS["$key"]="$value"
		done < <(grep -E '^[a-z_]+\s*=' "$theme_file" 2>/dev/null || true)
	fi
}

hex_to_ansi() {
	local hex="${1#\#}"
	if [[ ${#hex} -ne 6 ]]; then echo "0"; return; fi
	local r g b ri gi bi
	r=$((16#${hex:0:2}))
	g=$((16#${hex:2:2}))
	b=$((16#${hex:4:2}))
	ri=$(( r * 5 / 255 * 36 ))
	gi=$(( g * 5 / 255 * 6 ))
	bi=$(( b * 5 / 255 ))
	echo $(( 16 + ri + gi + bi ))
}

color_fg() {
	local c; c=$(hex_to_ansi "$1")
	echo -e "\\033[38;5;${c}m"
}

color_bg() {
	local c; c=$(hex_to_ansi "$1")
	echo -e "\\033[48;5;${c}m"
}

color_reset() {
	echo -e "\\033[0m"
}

color_bold() {
	echo -e "\\033[1m"
}

color_dim() {
	echo -e "\\033[2m"
}

# Load theme from config if available
CORE_THEME="${CORE_THEME:-}"
if [[ -z "$CORE_THEME" && -f "$CORE_CONFIG" ]]; then
	CORE_THEME=$(grep -E '^\s*theme\s*=' "$CORE_CONFIG" | head -1 | cut -d'"' -f2)
fi
load_theme "${CORE_THEME:-catppuccin-mocha}"
