#!/usr/bin/env bash
set -euo pipefail

errors=0
for cmd in psql mysql sqlite3 redis-cli mongod duckdb; do
	if command -v "$cmd" &>/dev/null; then
		echo "✔ $cmd found"
	else
		echo "✗ $cmd not found"
		errors=$((errors+1))
	fi
done
exit $errors
