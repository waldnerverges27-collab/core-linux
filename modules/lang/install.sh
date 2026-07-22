#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"
shift

case "$tool" in
	node)
		echo "Installing Node.js..."
		curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - 2>/dev/null
		sudo apt-get install -y nodejs
		;;
	python)
		echo "Installing Python..."
		sudo apt-get install -y python3 python3-pip python3-venv
		;;
	go)
		echo "Installing Go..."
		wget -qO- https://go.dev/dl/go1.23.0.linux-amd64.tar.gz | sudo tar -C /usr/local -xz
		echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
		;;
	rust)
		echo "Installing Rust..."
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
		;;
	zig)
		echo "Installing Zig..."
		wget -qO- https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | sudo tar -xJ -C /usr/local --strip=1
		;;
	deno)
		echo "Installing Deno..."
		curl -fsSL https://deno.land/install.sh | sh -s -- -y
		;;
	bun)
		echo "Installing Bun..."
		curl -fsSL https://bun.sh/install | bash
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Done: $tool"
