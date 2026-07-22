#!/usr/bin/env bash
set -euo pipefail

# Self-update mechanism for core-linux

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"

source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/utils/prompt.sh"

self_update() {
	log_step "Updating core-linux framework..."

	if [[ ! -d "$CORE_HOME/.git" ]]; then
		log_error "Not a git repository — cannot update via git"
		log_info "Reinstall using: curl -fsSL https://raw.githubusercontent.com/waldnerverges27-collab/core-linux/main/install.sh | bash"
		return 1
	fi

	cd "$CORE_HOME"

	if ! git fetch origin 2>/dev/null; then
		log_error "Git fetch failed (network error?)"
		return 1
	fi

	local behind
	behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
	if [[ "$behind" -eq 0 ]]; then
		log_success "Already up to date"
		return 0
	fi

	log_info "Updates available ($behind commits behind)"
	echo ""
	echo "Changelog:"
	git log --oneline HEAD..origin/main 2>/dev/null | head -20
	echo ""

	if confirm "Apply updates?"; then
		if ! git pull origin main 2>/dev/null; then
			log_error "Update failed — merge conflict?"
			return 1
		fi

		if command -v go &>/dev/null && [[ -f "$CORE_HOME/cmd/core-tui/main.go" ]]; then
			log_step "Rebuilding TUI..."
			cd "$CORE_HOME/cmd/core-tui"
			if go build -ldflags="-s -w" -o core-tui . 2>/dev/null; then
				cp core-tui "$CORE_HOME/core-tui"
				log_success "TUI rebuilt"
			else
				log_warn "TUI rebuild failed"
			fi
		fi

		log_success "Updated to latest version"
	fi
}

version_check() {
	local current_version="${1:-1.0.0}"
	local remote_version
	remote_version=$(curl -fsSL "https://raw.githubusercontent.com/waldnerverges27-collab/core-linux/main/core.conf.example" 2>/dev/null | grep "^version" | cut -d'"' -f2 || echo "")
	if [[ -n "$remote_version" && "$remote_version" != "$current_version" ]]; then
		log_info "Update available: $current_version → $remote_version"
		log_info "Run 'core update' to upgrade"
	fi
}
