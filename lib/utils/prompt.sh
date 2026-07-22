#!/usr/bin/env bash
set -euo pipefail

# Interactive prompts for core-linux

confirm() {
	local prompt="${1:-Continue?}"
	local default="${2:-n}"
	local yn
	if [[ "$default" == "y" ]]; then
		read -r -p "$prompt [Y/n] " yn
		[[ -z "$yn" || "$yn" =~ ^[yY] ]] && return 0 || return 1
	else
		read -r -p "$prompt [y/N] " yn
		[[ "$yn" =~ ^[yY] ]] && return 0 || return 1
	fi
}

select_option() {
	local prompt="$1"
	shift
	local options=("$@")
	local i=0
	for opt in "${options[@]}"; do
		echo "$((i+1))) $opt"
		i=$((i+1))
	done
	local choice
	read -r -p "$prompt [1-$i]: " choice
	if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= i )); then
		echo "${options[$((choice-1))]}"
		return 0
	fi
	return 1
}

read_input() {
	local prompt="${1:?Usage: read_input <prompt> [default]}"
	local default="${2:-}"
	local value
	if [[ -n "$default" ]]; then
		read -r -p "$prompt [$default]: " value
		echo "${value:-$default}"
	else
		read -r -p "$prompt: " value
		echo "$value"
	fi
}

read_secret() {
	local prompt="${1:?Usage: read_secret <prompt>}"
	local value
	read -r -s -p "$prompt: " value
	echo
	echo "$value"
}

press_any_key() {
	read -r -n 1 -s -p "Press any key to continue..."
	echo
}
