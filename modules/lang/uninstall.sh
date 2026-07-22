#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	node)
		sudo apt-get remove -y nodejs npm 2>/dev/null || true
		;;
	python)
		sudo apt-get remove -y python3 python3-pip 2>/dev/null || true
		;;
	go)
		sudo rm -rf /usr/local/go /etc/profile.d/go.sh 2>/dev/null || true
		;;
	rust)
		rustup self uninstall -y 2>/dev/null || rm -rf "$HOME/.rustup" "$HOME/.cargo" 2>/dev/null || true
		;;
	zig)
		sudo rm -f /usr/local/bin/zig 2>/dev/null || true
		;;
	deno)
		rm -f "$HOME/.deno/bin/deno" 2>/dev/null || true
		;;
	bun)
		rm -rf "$HOME/.bun" 2>/dev/null || true
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Removed: $tool"
