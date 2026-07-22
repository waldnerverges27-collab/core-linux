#!/usr/bin/env bash
set -euo pipefail

errors=0

for cmd in node python3 go rustc zig deno bun; do
	if command -v "$cmd" &>/dev/null; then
		echo "✔ $cmd found: $($cmd --version 2>/dev/null | head -1)"
	else
		echo "✗ $cmd not found"
		errors=$((errors+1))
	fi
done

exit $errors
