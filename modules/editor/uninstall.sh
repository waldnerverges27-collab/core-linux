#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	neovim) sudo apt-get remove -y neovim 2>/dev/null || true ;;
	vscode) sudo apt-get remove -y code 2>/dev/null || true ;;
	helix) sudo apt-get remove -y helix 2>/dev/null || true; sudo rm -f /usr/local/bin/hx 2>/dev/null || true ;;
	zed) rm -f ~/.local/bin/zed 2>/dev/null || true ;;
	emacs) sudo apt-get remove -y emacs 2>/dev/null || true ;;
	micro) sudo rm -f /usr/local/bin/micro 2>/dev/null || true ;;
	*) echo "Unknown tool: $tool"; exit 1 ;;
esac

echo "Removed: $tool"
