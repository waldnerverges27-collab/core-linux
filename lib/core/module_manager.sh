#!/usr/bin/env bash
set -euo pipefail

# Module manager for core-linux
# Install, uninstall, update, reinstall, list, show, verify modules

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"

source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/utils/platform.sh"
source "$CORE_HOME/lib/utils/prompt.sh"
source "$CORE_HOME/lib/core/state.sh"
source "$CORE_HOME/lib/core/resolver.sh"

module_exists() {
	[[ -d "$CORE_HOME/modules/$1" && -f "$CORE_HOME/modules/$1/manifest.json" ]]
}

module_manifest() {
	local module="${1:?Usage: module_manifest <module>}"
	echo "$CORE_HOME/modules/$module/manifest.json"
}

tool_exists_in_manifest() {
	local module="$1" tool="$2"
	local manifest
	manifest=$(module_manifest "$module")
	jq -e ".tools[] | select(.name == \"$tool\")" "$manifest" &>/dev/null
}

module_list() {
	local module="${1:-}"
	if [[ -n "$module" ]]; then
		local manifest
		manifest=$(module_manifest "$module")
		if [[ ! -f "$manifest" ]]; then
			log_error "Module $module not found"
			return 1
		fi

		local name version description deps icon
		name=$(jq -r '.name // empty' "$manifest")
		version=$(jq -r '.version // "1.0.0"' "$manifest")
		description=$(jq -r '.description // empty' "$manifest")
		icon=$(jq -r '.icon // ""' "$manifest")
		deps=$(jq -r '.dependencies | join(", ")' "$manifest" 2>/dev/null || echo "none")

		echo "$icon $name v$version"
		echo "  $description"
		echo "  Dependencies: $deps"
		echo ""
		echo "Tools:"

		local tool_count
		tool_count=$(jq -r '.tools | length' "$manifest" 2>/dev/null || echo 0)
		if [[ "$tool_count" -eq 0 ]]; then
			echo "  (none)"
		else
			local i=0
			while jq -e ".tools[$i]" "$manifest" &>/dev/null; do
				local tool_name tool_desc tool_flag tool_ver
				tool_name=$(jq -r ".tools[$i].name // empty" "$manifest")
				tool_desc=$(jq -r ".tools[$i].description // empty" "$manifest")
				tool_flag=$(jq -r ".tools[$i].flag // empty" "$manifest")
				local status="✗"
				local ver_info=""
				if tool_is_installed "$module" "$tool_name"; then
					status="✔"
					tool_ver=$(get_tool_version "$module" "$tool_name")
					ver_info=" ($tool_ver)"
				fi
				echo "  $status $tool_flag $tool_name — $tool_desc$ver_info"
				i=$((i+1))
			done
		fi
	else
		local mod
		for mod in "$CORE_HOME/modules"/*/; do
			[[ -d "$mod" ]] || continue
			mod=$(basename "$mod")
			local manifest="$CORE_HOME/modules/$mod/manifest.json"
			if [[ -f "$manifest" ]]; then
				local desc icon
				desc=$(jq -r '.description // ""' "$manifest")
				icon=$(jq -r '.icon // " "' "$manifest")
				local status="✗"
				module_is_installed "$mod" && status="✔"
				echo "$status $icon $mod — $desc"
			fi
		done
	fi
}

module_show() {
	local target="${1:?Usage: module_show <module|tool>}"
	if module_exists "$target"; then
		module_list "$target"
		return
	fi

	local mod manifest
	for mod in "$CORE_HOME/modules"/*/; do
		mod=$(basename "$mod")
		manifest="$CORE_HOME/modules/$mod/manifest.json"
		[[ -f "$manifest" ]] || continue

		local tool_data
		tool_data=$(jq -r ".tools[] | select(.name == \"$target\") // empty" "$manifest" 2>/dev/null || true)
		if [[ -n "$tool_data" ]]; then
			echo "Name: $(jq -r '.name' <<<"$tool_data")"
			echo "Module: $mod"
			echo "Description: $(jq -r '.description // "N/A"' <<<"$tool_data")"
			echo "Flag: $(jq -r '.flag // "N/A"' <<<"$tool_data")"
			echo "Size: $(jq -r '.size_mb // "?"' <<<"$tool_data") MB"
			local tags
			tags=$(jq -r '.tags | join(", ")' <<<"$tool_data" 2>/dev/null || echo "N/A")
			echo "Tags: $tags"

			if tool_is_installed "$mod" "$target"; then
				local ver
				ver=$(get_tool_version "$mod" "$target")
				echo "Status: ✔ Installed ($ver)"
			else
				echo "Status: ✗ Not installed"
			fi
			return
		fi
	done
	log_error "Module or tool not found: $target"
	return 1
}

module_install() {
	local module="${1:?Usage: module_install <module> [--tool1...]}"
	shift

	module_exists "$module" || { log_error "Module $module not found"; return 1; }

	check_conflicts "$module" || return 1

	local manifest
	manifest=$(module_manifest "$module")

	local -a order
	mapfile -t order < <(resolve_install_order "$module" 2>/dev/null || true)

	local dep
	for dep in "${order[@]}"; do
		[[ "$dep" == "$module" ]] && continue
		if ! module_is_installed "$dep"; then
			log_step "Installing dependency: $dep"
			module_install "$dep" || { log_error "Failed dependency: $dep"; return 1; }
		fi
	done

	local specific_tools=("$@")
	local -a tools=()

	if [[ ${#specific_tools[@]} -gt 0 ]]; then
		local flag tool_name
		for flag in "${specific_tools[@]}"; do
			flag="${flag#--}"
			tool_name=$(jq -r ".tools[] | select(.flag == \"--$flag\") | .name" "$manifest" 2>/dev/null || true)
			[[ -n "$tool_name" && "$tool_name" != "null" ]] && tools+=("$tool_name")
		done
		[[ ${#tools[@]} -eq 0 ]] && { log_warn "No matching tools found for flags: $*"; return 1; }
	else
		mapfile -t tools < <(jq -r '.tools[].name // empty' "$manifest" 2>/dev/null || true)
	fi

	[[ ${#tools[@]} -eq 0 ]] && { log_warn "No tools defined for $module"; return 0; }

	local tool
	for tool in "${tools[@]}"; do
		log_step "Installing $module/$tool..."
		log_info "Installing $tool..."
		if command -v "$tool" &>/dev/null; then
			local existing_ver
			existing_ver=$("$tool" --version 2>/dev/null || "$tool" version 2>/dev/null || echo "unknown")
			log_info "$tool already available ($existing_ver)"
			mark_module_tool_installed "$module" "$tool" "$existing_ver"
			log_success "$tool ready"
			continue
		fi

		local install_script="$CORE_HOME/modules/$module/install.sh"
		if [[ -f "$install_script" ]]; then
			if bash "$install_script" "$tool"; then
				local version=""
				local ver_cmd
				ver_cmd=$(jq -r ".tools[] | select(.name == \"$tool\") | .version_cmd // \"\"" "$manifest")
				[[ -n "$ver_cmd" && "$ver_cmd" != "null" ]] && version=$(eval "$ver_cmd" 2>/dev/null || echo "unknown")
				mark_module_tool_installed "$module" "$tool" "$version"
				log_success "Installed $tool ($version)"
			else
				log_error "Failed to install $tool"
				return 1
			fi
		else
			log_warn "No install script for $module/$tool"
		fi
	done

	module_verify "$module"
}

module_uninstall() {
	local module="${1:?Usage: module_uninstall <module> [--tool1...]}"
	shift

	module_exists "$module" || { log_error "Module $module not found"; return 1; }

	local manifest
	manifest=$(module_manifest "$module")

	local specific_tools=("$@")
	local -a tools=()

	if [[ ${#specific_tools[@]} -gt 0 ]]; then
		local flag tool_name
		for flag in "${specific_tools[@]}"; do
			flag="${flag#--}"
			tool_name=$(jq -r ".tools[] | select(.flag == \"--$flag\") | .name" "$manifest" 2>/dev/null || true)
			[[ -n "$tool_name" && "$tool_name" != "null" ]] && tools+=("$tool_name")
		done
	else
		mapfile -t tools < <(jq -r '.tools[].name // empty' "$manifest" 2>/dev/null || true)
	fi

	local tool
	for tool in "${tools[@]}"; do
		if ! tool_is_installed "$module" "$tool"; then
			log_info "$tool not installed, skipping"
			continue
		fi

		if ! confirm "Remove $tool?"; then
			log_info "Skipping $tool"
			continue
		fi

		log_step "Uninstalling $tool..."
		local uninstall_script="$CORE_HOME/modules/$module/uninstall.sh"
		if [[ -f "$uninstall_script" ]]; then
			bash "$uninstall_script" "$tool" 2>/dev/null || log_warn "Uninstall had warnings"
		fi
		mark_module_tool_removed "$module" "$tool"
		log_success "Uninstalled $tool"
	done
}

module_update() {
	local module="${1:?Usage: module_update <module>}"
	log_step "Updating $module..."
	module_install "$module"
}

module_reinstall() {
	local module="${1:?Usage: module_reinstall <module> [--tool1...]}"
	shift
	local tools=("$@")
	module_uninstall "$module" "${tools[@]}"
	shift
	module_install "$module" "${tools[@]}"
}

module_verify() {
	local module="${1:?Usage: module_verify <module>}"
	local verify_script="$CORE_HOME/modules/$module/verify.sh"
	if [[ -f "$verify_script" ]]; then
		log_step "Verifying $module..."
		bash "$verify_script" 2>/dev/null || log_warn "Verification reported issues"
	else
		log_info "No verify script for $module"
	fi
}
