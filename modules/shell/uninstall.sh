#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	zsh) sudo apt-get remove -y zsh 2>/dev/null || true ;;
	fish) sudo apt-get remove -y fish 2>/dev/null || true ;;
	starship) rm -f /usr/local/bin/starship 2>/dev/null || true ;;
	oh-my-zsh) rm -rf "$HOME/.oh-my-zsh" 2>/dev/null || true ;;
	powerlevel10k) rm -rf "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" 2>/dev/null || true ;;
	zoxide) rm -f /usr/local/bin/zoxide 2>/dev/null || true ;;
	fzf) sudo apt-get remove -y fzf 2>/dev/null || true ;;
	*) echo "Unknown tool: $tool"; exit 1 ;;
esac

echo "Removed: $tool"
