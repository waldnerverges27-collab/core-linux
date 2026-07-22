#!/usr/bin/env bash
set -euo pipefail

# Dependency resolution for core-linux modules
# Topological sort to ensure dependencies install before dependents

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"

source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/core/state.sh"

resolve_deps() {
	local module="${1:?Usage: resolve_deps <module>}"
	local manifest="$CORE_HOME/modules/$module/manifest.json"
	if [[ ! -f "$manifest" ]]; then
		log_error "Module $module has no manifest at $manifest"
		return 1
	fi
	jq -r '.dependencies[] // empty' "$manifest" 2>/dev/null || true
}

resolve_install_order() {
	local target="${1:?Usage: resolve_install_order <module>}"
	local -a ordered=()
	local -a visited=()

	_visit() {
		local mod="$1"
		for v in "${visited[@]}"; do
			[[ "$v" == "$mod" ]] && return
		done
		visited+=("$mod")

		local deps
		deps=$(resolve_deps "$mod" 2>/dev/null || true)
		local dep
		for dep in $deps; do
			_visit "$dep"
		done
		ordered+=("$mod")
	}

	_visit "$target"

	local i
	for (( i=0; i<${#ordered[@]}; i++ )); do
		echo "${ordered[$i]}"
	done
}

check_conflicts() {
	local module="${1:?Usage: check_conflicts <module>}"
	local manifest="$CORE_HOME/modules/$module/manifest.json"
	[[ -f "$manifest" ]] || return 0

	local conflicts
	conflicts=$(jq -r '.conflicts[] // empty' "$manifest" 2>/dev/null || true)
	[[ -z "$conflicts" ]] && return 0

	local conflict
	for conflict in $conflicts; do
		if module_is_installed "$conflict"; then
			log_error "Conflict: $module conflicts with installed module $conflict"
			return 1
		fi
	done
}

validate_deps() {
	local module="${1:?Usage: validate_deps <module>}"
	local -a order
	mapfile -t order < <(resolve_install_order "$module" 2>/dev/null || true)
	local dep_present=yes
	local mod
	for mod in "${order[@]}"; do
		if [[ "$mod" != "$module" ]] && [[ ! -d "$CORE_HOME/modules/$mod" ]]; then
			log_error "Required dependency $mod for $module not found"
			dep_present=no
		fi
	done
	[[ "$dep_present" == "yes" ]]
}
