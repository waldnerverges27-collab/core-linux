#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	postgresql) sudo apt-get remove -y postgresql postgresql-contrib 2>/dev/null || true ;;
	mysql) sudo apt-get remove -y mysql-server 2>/dev/null || true ;;
	sqlite) sudo apt-get remove -y sqlite3 libsqlite3-dev 2>/dev/null || true ;;
	redis) sudo apt-get remove -y redis-server 2>/dev/null || true ;;
	mongodb) sudo apt-get remove -y mongodb-org 2>/dev/null || true ;;
	duckdb) rm -f /usr/local/bin/duckdb 2>/dev/null || true ;;
	*) echo "Unknown tool: $tool"; exit 1 ;;
esac

echo "Removed: $tool"
