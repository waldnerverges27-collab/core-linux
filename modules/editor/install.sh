#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	neovim)
		sudo apt-get install -y neovim
		;;
	vscode)
		wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null
		echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' | sudo tee /etc/apt/sources.list.d/vscode.list
		sudo apt-get update && sudo apt-get install -y code
		;;
	helix)
		sudo apt-get install -y helix 2>/dev/null || {
			wget -qO- https://github.com/helix-editor/helix/releases/download/24.03/helix-24.03-x86_64-linux.tar.xz | sudo tar -xJ -C /usr/local --strip=1
		}
		;;
	zed)
		curl -fsSL https://zed.dev/install.sh | sh
		;;
	emacs)
		sudo apt-get install -y emacs
		;;
	micro)
		curl -fsSL https://getmic.ro | bash && sudo mv micro /usr/local/bin/ 2>/dev/null || true
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Done: $tool"
