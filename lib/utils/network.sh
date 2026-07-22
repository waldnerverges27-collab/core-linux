#!/usr/bin/env bash
set -euo pipefail

# Network utilities for core-linux
# curl/wget wrapper with retry logic

http_get() {
	local url="${1:?Usage: http_get <url> [output_file]}"
	local output="${2:-}"
	local max_retries="${CORE_NET_RETRIES:-3}"
	local retry_delay="${CORE_NET_DELAY:-2}"

	if command -v curl &>/dev/null; then
		_cmd="curl -fsSL"
	elif command -v wget &>/dev/null; then
		_cmd="wget -qO-"
	else
		echo "ERROR: Neither curl nor wget found" >&2
		return 1
	fi

	local attempt=0 rc=0
	while [[ $attempt -lt $max_retries ]]; do
		if [[ -n "$output" ]]; then
			if echo "$_cmd" | grep -q curl; then
				curl -fsSL -o "$output" "$url" && return 0
				rc=$?
			else
				wget -q -O "$output" "$url" && return 0
				rc=$?
			fi
		else
			if echo "$_cmd" | grep -q curl; then
				curl -fsSL "$url" && return 0
				rc=$?
			else
				wget -qO- "$url" && return 0
				rc=$?
			fi
		fi
		attempt=$((attempt + 1))
		if [[ $attempt -lt $max_retries ]]; then
			sleep "$retry_delay"
		fi
	done
	return $rc
}

http_check() {
	local url="${1:?Usage: http_check <url>}"
	if command -v curl &>/dev/null; then
		curl -sI -o /dev/null -w "%{http_code}" "$url"
	elif command -v wget &>/dev/null; then
		wget --spider -q "$url" 2>&1 && echo "200" || echo "000"
	else
		echo "000"
	fi
}

download_file() {
	local url="${1:?Usage: download_file <url> <output_path>}"
	local output="${2:?Usage: download_file <url> <output_path>}"
	http_get "$url" "$output"
}
