#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	qwen-code)
		echo "Installing Qwen Code..."
		npm install -g @qwen/qwen-code-cli
		;;
	gemini-cli)
		echo "Installing Gemini CLI..."
		npm install -g @google/gemini-cli
		;;
	claude-code)
		echo "Installing Claude Code..."
		curl -fsSL https://github.com/anthropics/claude-code/releases/latest/download/claude-linux-amd64.tar.gz \
			| sudo tar -xz -C /usr/local/bin claude
		chmod +x /usr/local/bin/claude 2>/dev/null || true
		;;
	mistral-vibe)
		echo "Installing Mistral Vibe..."
		npm install -g mistral-vibe-cli
		;;
	openclaude)
		echo "Installing OpenClaude..."
		curl -fsSL https://github.com/sst/OpenClaude/releases/latest/download/openclaude-linux-amd64 \
			-o /usr/local/bin/openclaude && chmod +x /usr/local/bin/openclaude
		;;
	openclaw)
		echo "Installing OpenClaw..."
		curl -fsSL https://github.com/OpenClaw/OpenClaw/releases/latest/download/openclaw-linux-amd64 \
			-o /usr/local/bin/openclaw && chmod +x /usr/local/bin/openclaw
		;;
	ollama)
		echo "Installing Ollama..."
		curl -fsSL https://ollama.com/install.sh | sh
		;;
	codex)
		echo "Installing Codex CLI..."
		npm install -g @openai/codex
		;;
	opencode)
		echo "Installing OpenCode..."
		curl -fsSL https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-amd64.tar.gz \
			| sudo tar -xz -C /usr/local/bin opencode
		chmod +x /usr/local/bin/opencode 2>/dev/null || true
		;;
	qoder)
		echo "Installing Qoder..."
		curl -fsSL https://github.com/qoder/qoder/releases/latest/download/qoder-linux-amd64 \
			-o /usr/local/bin/qoder && chmod +x /usr/local/bin/qoder
		;;
	kilocode-cli)
		echo "Installing Kilo Code CLI..."
		curl -fsSL https://github.com/kilocode/kilocode-cli/releases/latest/download/kilocode-linux-amd64 \
			-o /usr/local/bin/kilo && chmod +x /usr/local/bin/kilo
		;;
	kimchi)
		echo "Installing Kimchi..."
		npm install -g kimchi-cli
		;;
	mimocode)
		echo "Installing MiMoCode..."
		curl -fsSL https://github.com/XiaomiMiMo/MiMo-Code/releases/latest/download/mimocode-linux-amd64.tar.gz \
			| sudo tar -xz -C /usr/local/bin mimo 2>/dev/null || \
			curl -fsSL https://github.com/XiaomiMiMo/MiMo-Code/releases/latest/download/mimo-linux-amd64.tar.gz \
			| sudo tar -xz -C /usr/local/bin
		# Rename if needed
		[ -f /usr/local/bin/mimo ] && mv /usr/local/bin/mimo /usr/local/bin/mimocode 2>/dev/null || true
		[ -f /usr/local/bin/mimocode ] && chmod +x /usr/local/bin/mimocode
		;;
	engram)
		echo "Installing Engram..."
		curl -fsSL https://github.com/engram/engram-cli/releases/latest/download/engram-linux-amd64 \
			-o /usr/local/bin/engram && chmod +x /usr/local/bin/engram
		;;
	codegraph)
		echo "Installing CodeGraph..."
		curl -fsSL https://github.com/sourcegraph/codegraph/releases/latest/download/codegraph-linux-amd64 \
			-o /usr/local/bin/codegraph && chmod +x /usr/local/bin/codegraph
		;;
	pi)
		echo "Installing Pi Coding Agent..."
		curl -fsSL https://github.com/pi-coding/pi-agent/releases/latest/download/pi-linux-amd64 \
			-o /usr/local/bin/pi && chmod +x /usr/local/bin/pi
		;;
	antigravity-cli)
		echo "Installing Antigravity CLI..."
		curl -fsSL https://github.com/antigravity/antigravity-cli/releases/latest/download/antigravity-linux-amd64 \
			-o /usr/local/bin/antigravity && chmod +x /usr/local/bin/antigravity
		;;
	gentle-ai)
		echo "Installing Gentle AI..."
		npm install -g gentle-ai
		;;
	minimax-cli)
		echo "Installing MiniMax CLI..."
		npm install -g minimax-cli
		;;
	gga)
		echo "Installing Gentleman Guardian Angel..."
		npm install -g gentleman-guardian-angel
		;;
	hermes-agent)
		echo "Installing Hermes Agent..."
		curl -fsSL https://github.com/NousResearch/hermes-agent/releases/latest/download/hermes-linux-amd64 \
			-o /usr/local/bin/hermes && chmod +x /usr/local/bin/hermes
		;;
	kimi-code)
		echo "Installing Kimi Code..."
		npm install -g kimi-code-cli
		;;
	command-code)
		echo "Installing Command Code..."
		npm install -g @command-code/cli
		;;
	freebuff)
		echo "Installing Freebuff..."
		curl -fsSL https://github.com/freebuff/freebuff-cli/releases/latest/download/freebuff-linux-amd64 \
			-o /usr/local/bin/freebuff && chmod +x /usr/local/bin/freebuff
		;;
	ctx7)
		echo "Installing Context7..."
		npm install -g context7
		;;
	openspec)
		echo "Installing OpenSpec..."
		npm install -g openspec
		;;
	cline)
		echo "Installing Cline CLI..."
		npm install -g @cline/cli
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Done: $tool"
