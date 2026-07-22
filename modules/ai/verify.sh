#!/usr/bin/env bash
set -euo pipefail

errors=0

for cmd in qwen gemini claude vibe openclaude openclaw ollama codex opencode qoder kilo kimchi mimo engram codegraph pi antigravity gentle minimax gga hermes kimi command-code freebuff ctx7 openspec cline; do
	if command -v "$cmd" &>/dev/null; then
		echo "✔ $cmd found"
	else
		echo "✗ $cmd not found"
		errors=$((errors+1))
	fi
done

exit $errors
