#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	zsh)
		sudo apt-get install -y zsh
		;;
	fish)
		sudo apt-add-repository -y ppa:fish-shell/release-3 2>/dev/null || true
		sudo apt-get update && sudo apt-get install -y fish
		;;
	starship)
		curl -fsSL https://starship.rs/install.sh | sh -s -- -y
		;;
	oh-my-zsh)
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended
		;;
	powerlevel10k)
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" 2>/dev/null || true
		;;
	zoxide)
		curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
		;;
	fzf)
		sudo apt-get install -y fzf
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Done: $tool"
