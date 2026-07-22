#!/usr/bin/env bash
set -euo pipefail

# State management for core-linux
# Tracks installed modules and tools in ~/.local/state/core-linux/installed.json

CORE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/core-linux"
CORE_STATE_FILE="${CORE_STATE_FILE:-$CORE_STATE_DIR/installed.json}"
CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"

source "$CORE_HOME/lib/utils/fs.sh"

state_init() {
	ensure_dir "$CORE_STATE_DIR"
	if [[ ! -f "$CORE_STATE_FILE" ]]; then
		echo '{"modules":{}}' > "$CORE_STATE_FILE"
	fi
}

state_get() {
	local query="${1:?Usage: state_get <jq_query>}"
	state_init
	jq -r "$query" "$CORE_STATE_FILE" 2>/dev/null || echo ""
}

state_set() {
	local mutation="${1:?Usage: state_set <jq_mutation>}"
	state_init
	local tmp
	tmp=$(mktemp "$CORE_STATE_DIR/state.XXXXXX")
	if jq "$mutation" "$CORE_STATE_FILE" > "$tmp" 2>/dev/null; then
		mv "$tmp" "$CORE_STATE_FILE"
	else
		rm -f "$tmp"
		return 1
	fi
}

module_is_installed() {
	local mod="${1:?Usage: module_is_installed <module>}"
	local val
	val=$(state_get ".modules[\"$mod\"]")
	[[ -n "$val" && "$val" != "null" ]]
}

tool_is_installed() {
	local mod="${1:?Usage: tool_is_installed <module> <tool>}"
	local tool="${2:?Usage: tool_is_installed <module> <tool>}"
	local val
	val=$(state_get ".modules[\"$mod\"].tools[\"$tool\"]")
	[[ -n "$val" && "$val" != "null" ]]
}

mark_module_tool_installed() {
	local mod="${1:?Usage: mark_module_tool_installed <module> <tool> <version>}"
	local tool="${2:?Usage: mark_module_tool_installed <module> <tool> <version>}"
	local version="${3:-unknown}"
	local now
	now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	state_set ".modules[\"$mod\"].version = \"1.0.0\""
	state_set ".modules[\"$mod\"].installed_at = \"$now\""
	state_set ".modules[\"$mod\"].tools[\"$tool\"] = {\"version\": \"$version\", \"installed_at\": \"$now\"}"
}

mark_module_tool_removed() {
	local mod="${1:?Usage: mark_module_tool_removed <module> <tool>}"
	local tool="${2:?Usage: mark_module_tool_removed <module> <tool>}"
	state_set "del(.modules[\"$mod\"].tools[\"$tool\"])"
	local remaining
	remaining=$(state_get ".modules[\"$mod\"].tools | length")
	if [[ "$remaining" == "0" || -z "$remaining" || "$remaining" == "null" ]]; then
		state_set "del(.modules[\"$mod\"])"
	fi
}

get_installed_modules() {
	state_get '.modules | keys[]' 2>/dev/null || true
}

get_installed_tools() {
	local mod="${1:?Usage: get_installed_tools <module>}"
	state_get ".modules[\"$mod\"].tools | keys[]" 2>/dev/null || true
}

get_tool_version() {
	local mod="${1:?Usage: get_tool_version <module> <tool>}"
	local tool="${2:?Usage: get_tool_version <module> <tool>}"
	state_get ".modules[\"$mod\"].tools[\"$tool\"].version // \"\""
}
