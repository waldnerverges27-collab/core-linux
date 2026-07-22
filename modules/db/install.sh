#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	postgresql)
		sudo apt-get install -y postgresql postgresql-contrib
		sudo systemctl enable postgresql 2>/dev/null || true
		;;
	mysql)
		sudo apt-get install -y mysql-server
		;;
	sqlite)
		sudo apt-get install -y sqlite3 libsqlite3-dev
		;;
	redis)
		sudo apt-get install -y redis-server
		;;
	mongodb)
		sudo apt-get install -y gnupg curl
		curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
		echo 'deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main' | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
		sudo apt-get update && sudo apt-get install -y mongodb-org
		;;
	duckdb)
		curl -fsSL https://install.duckdb.org | sh
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Done: $tool"
