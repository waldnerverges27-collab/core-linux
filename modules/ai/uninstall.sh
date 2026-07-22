#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	qwen-code)       npm uninstall -g @qwen/qwen-code-cli 2>/dev/null || true ;;
	gemini-cli)      npm uninstall -g @google/gemini-cli 2>/dev/null || true ;;
	claude-code)     sudo rm -f /usr/local/bin/claude 2>/dev/null || true ;;
	mistral-vibe)    npm uninstall -g mistral-vibe-cli 2>/dev/null || true ;;
	openclaude)      sudo rm -f /usr/local/bin/openclaude 2>/dev/null || true ;;
	openclaw)        sudo rm -f /usr/local/bin/openclaw 2>/dev/null || true ;;
	ollama)          sudo rm -rf /usr/local/lib/ollama /usr/local/bin/ollama 2>/dev/null || true ;;
	codex)           npm uninstall -g @openai/codex 2>/dev/null || true ;;
	opencode)        sudo rm -f /usr/local/bin/opencode 2>/dev/null || true ;;
	qoder)           sudo rm -f /usr/local/bin/qoder 2>/dev/null || true ;;
	kilocode-cli)    sudo rm -f /usr/local/bin/kilo 2>/dev/null || true ;;
	kimchi)          npm uninstall -g kimchi-cli 2>/dev/null || true ;;
	mimocode)        sudo rm -f /usr/local/bin/mimocode 2>/dev/null || true ;;
	engram)          sudo rm -f /usr/local/bin/engram 2>/dev/null || true ;;
	codegraph)       sudo rm -f /usr/local/bin/codegraph 2>/dev/null || true ;;
	pi)              sudo rm -f /usr/local/bin/pi 2>/dev/null || true ;;
	antigravity-cli) sudo rm -f /usr/local/bin/antigravity 2>/dev/null || true ;;
	gentle-ai)       npm uninstall -g gentle-ai 2>/dev/null || true ;;
	minimax-cli)     npm uninstall -g minimax-cli 2>/dev/null || true ;;
	gga)             npm uninstall -g gentleman-guardian-angel 2>/dev/null || true ;;
	hermes-agent)    sudo rm -f /usr/local/bin/hermes 2>/dev/null || true ;;
	kimi-code)       npm uninstall -g kimi-code-cli 2>/dev/null || true ;;
	command-code)    npm uninstall -g @command-code/cli 2>/dev/null || true ;;
	freebuff)        sudo rm -f /usr/local/bin/freebuff 2>/dev/null || true ;;
	ctx7)            npm uninstall -g context7 2>/dev/null || true ;;
	openspec)        npm uninstall -g openspec 2>/dev/null || true ;;
	cline)           npm uninstall -g @cline/cli 2>/dev/null || true ;;
	*)               echo "Unknown tool: $tool"; exit 1 ;;
esac

echo "Removed: $tool"
