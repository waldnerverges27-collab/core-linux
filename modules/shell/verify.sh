#!/usr/bin/env bash
set -euo pipefail

errors=0
for cmd in zsh fish starship zoxide fzf; do
	if command -v "$cmd" &>/dev/null; then
		echo "✔ $cmd found: $($cmd --version 2>/dev/null | head -1)"
	else
		echo "✗ $cmd not found"
		errors=$((errors+1))
	fi
done
for dir in "$HOME/.oh-my-zsh"; do
	if [[ -d "$dir" ]]; then
		echo "✔ $(basename "$dir") installed"
	else
		echo "✗ $(basename "$dir") not found"
	fi
done
exit $errors
