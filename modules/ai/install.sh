#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	ollama)
		curl -fsSL https://ollama.com/install.sh | sh
		systemctl --user enable ollama 2>/dev/null || true
		;;
	qwen-code)
		ollama pull qwen2.5-coder:7b 2>/dev/null || {
			curl -fsSL https://ollama.com/install.sh | sh
			ollama pull qwen2.5-coder:7b
		}
		;;
	deepseek-coder)
		ollama pull deepseek-coder:6.7b 2>/dev/null || {
			curl -fsSL https://ollama.com/install.sh | sh
			ollama pull deepseek-coder:6.7b
		}
		;;
	chatgpt)
		npm install -g @chatgpt/cli
		;;
	copilot)
		npm install -g @githubnext/github-copilot-cli
		;;
	aider)
		pip3 install aider-chat
		;;
	tabby)
		curl -fsSL https://raw.githubusercontent.com/TabbyML/tabby/main/scripts/install.sh | sh
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Done: $tool"
