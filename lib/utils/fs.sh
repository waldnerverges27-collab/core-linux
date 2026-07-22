#!/usr/bin/env bash
set -euo pipefail

# Safe file operations for core-linux

ensure_dir() {
	local dir="${1:?Usage: ensure_dir <directory>}"
	if [[ ! -d "$dir" ]]; then
		mkdir -p "$dir" || {
			echo "ERROR: Cannot create directory: $dir" >&2
			return 1
		}
	fi
}

safe_cp() {
	local src="${1:?Usage: safe_cp <source> <dest>}"
	local dst="${2:?Usage: safe_cp <source> <dest>}"
	if [[ ! -e "$src" ]]; then
		echo "ERROR: Source not found: $src" >&2
		return 1
	fi
	ensure_dir "$(dirname "$dst")"
	cp "$src" "$dst"
}

safe_mv() {
	local src="${1:?Usage: safe_mv <source> <dest>}"
	local dst="${2:?Usage: safe_mv <source> <dest>}"
	if [[ ! -e "$src" ]]; then
		echo "ERROR: Source not found: $src" >&2
		return 1
	fi
	ensure_dir "$(dirname "$dst")"
	mv "$src" "$dst"
}

atomic_write() {
	local content="${1:?Usage: atomic_write <content> <file>}"
	local file="${2:?Usage: atomic_write <content> <file>}"
	ensure_dir "$(dirname "$file")"
	local tmp
	tmp=$(mktemp "${file}.XXXXXX" 2>/dev/null) || tmp=$(mktemp "/tmp/core-linux.XXXXXX")
	printf '%s\n' "$content" > "$tmp"
	mv "$tmp" "$file"
}

backup_file() {
	local file="${1:?Usage: backup_file <file>}"
	[[ -f "$file" ]] || return 0
	local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
	cp "$file" "$backup"
	echo "$backup"
}

read_file() {
	local file="${1:?Usage: read_file <file>}"
	[[ -f "$file" ]] || { echo "ERROR: File not found: $file" >&2; return 1; }
	cat "$file"
}

file_size() {
	local file="${1:?Usage: file_size <file>}"
	[[ -f "$file" ]] || { echo "0"; return 1; }
	wc -c < "$file"
}
