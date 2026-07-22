#!/usr/bin/env bash
set -euo pipefail

errors=0
for cmd in ollama aider; do
	if command -v "$cmd" &>/dev/null; then
		echo "✔ $cmd found"
	else
		echo "✗ $cmd not found"
		errors=$((errors+1))
	fi
done
# Check for npm packages
for pkg in @chatgpt/cli @githubnext/github-copilot-cli; do
	if npm list -g "$pkg" &>/dev/null; then
		echo "✔ $pkg installed"
	else
		echo "✗ $pkg not installed"
	fi
done
exit $errors
