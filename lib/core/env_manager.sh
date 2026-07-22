#!/usr/bin/env bash
set -euo pipefail

# Environment variable manager for core-linux
# Manages user-defined env vars in shell rc files

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"

source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/utils/prompt.sh"
source "$CORE_HOME/lib/utils/platform.sh"

env_set() {
	local name="${1:-}"
	local value="${2:-}"

	if [[ -z "$name" ]]; then
		name=$(read_input "Variable name")
	fi
	if [[ -z "$value" ]]; then
		value=$(read_secret "Variable value")
	fi

	if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
		log_error "Invalid variable name: $name (must match [a-zA-Z_][a-zA-Z0-9_]*)"
		return 1
	fi

	local rc_file
	rc_file=$(detect_shell_rc)
	ensure_dir "$(dirname "$rc_file")"

	if grep -qE "^export $name=" "$rc_file" 2>/dev/null; then
		if ! confirm "Variable $name already exists in $rc_file. Overwrite?"; then
			log_info "Skipped"
			return 0
		fi
		local tmp
		tmp=$(mktemp)
		grep -vE "^export $name=" "$rc_file" > "$tmp" 2>/dev/null || true
		mv "$tmp" "$rc_file"
	fi

	echo "export $name=\"$value\"" >> "$rc_file"
	log_success "Set $name in $rc_file"
	log_info "Run 'source $rc_file' or restart shell to apply"
}

env_unset() {
	local rc_file
	rc_file=$(detect_shell_rc)

	if [[ ! -f "$rc_file" ]]; then
		log_info "No shell rc file at $rc_file"
		return 0
	fi

	local -a vars=()
	while IFS='=' read -r line; do
		local var_name="${line#export }"
		var_name="${var_name%%=*}"
		[[ -n "$var_name" ]] && vars+=("$var_name")
	done < <(grep -E "^export [a-zA-Z_][a-zA-Z0-9_]*=" "$rc_file" 2>/dev/null || true)

	[[ ${#vars[@]} -eq 0 ]] && { log_info "No environment variables set"; return 0; }

	local choice
	choice=$(select_option "Select variable to remove" "${vars[@]}") || { log_info "Cancelled"; return 0; }

	local tmp
	tmp=$(mktemp)
	grep -vE "^export $choice=" "$rc_file" > "$tmp" 2>/dev/null || true
	mv "$tmp" "$rc_file"
	log_success "Removed $choice from $rc_file"
}

env_ls() {
	local rc_file
	rc_file=$(detect_shell_rc)

	if [[ ! -f "$rc_file" ]]; then
		log_info "No shell rc file at $rc_file"
		return 0
	fi

	local count=0
	while IFS='=' read -r name value; do
		name="${name#export }"
		name="${name%% }"
		value="${value#\"}"; value="${value%\"}"
		local masked
		if [[ ${#value} -gt 10 ]]; then
			masked="${value:0:3}...${value: -3}"
		elif [[ ${#value} -gt 0 ]]; then
			masked="****"
		else
			masked="(empty)"
		fi
		printf "%-30s %s\n" "$name" "$masked"
		count=$((count+1))
	done < <(grep -E "^export [a-zA-Z_][a-zA-Z0-9_]*=" "$rc_file" 2>/dev/null || true)

	[[ $count -eq 0 ]] && log_info "No environment variables set"
}

env_init() {
	# Interactive mode: set/unset/ls menu
	echo "Environment Variable Manager"
	echo "1) Set variable"
	echo "2) Unset variable"
	echo "3) List variables"
	local choice
	read -r -p "Choice [1-3]: " choice
	case "$choice" in
		1) env_set ;;
		2) env_unset ;;
		3) env_ls ;;
		*) log_error "Invalid choice" ;;
	esac
}
