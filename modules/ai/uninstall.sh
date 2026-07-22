#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	ollama)
		sudo systemctl stop ollama 2>/dev/null || true
		sudo rm -rf /usr/local/lib/ollama /usr/local/bin/ollama 2>/dev/null || true
		;;
	qwen-code)
		ollama rm qwen2.5-coder:7b 2>/dev/null || true
		;;
	deepseek-coder)
		ollama rm deepseek-coder:6.7b 2>/dev/null || true
		;;
	chatgpt)
		npm uninstall -g @chatgpt/cli 2>/dev/null || true
		;;
	copilot)
		npm uninstall -g @githubnext/github-copilot-cli 2>/dev/null || true
		;;
	aider)
		pip3 uninstall -y aider-chat 2>/dev/null || true
		;;
	tabby)
		rm -f /usr/local/bin/tabby 2>/dev/null || true
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Removed: $tool"
