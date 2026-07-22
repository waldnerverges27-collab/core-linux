#!/usr/bin/env bash
set -euo pipefail

# Self-update mechanism for core-linux
# Works with git repos AND piped (curl | bash) installs.

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"
CORE_BIN="${CORE_BIN:-$HOME/.local/bin}"
REPO_BASE="https://github.com/waldnerverges27-collab/core-linux"
RAW_BASE="https://raw.githubusercontent.com/waldnerverges27-collab/core-linux/main"

source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/utils/prompt.sh"

# ------------------------------------------------------------------
# Version helpers
# ------------------------------------------------------------------
_get_local_version() {
	local ver="1.0.0"
	if [[ -f "$CORE_HOME/core.conf.example" ]]; then
		ver=$(grep -E '^version' "$CORE_HOME/core.conf.example" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "1.0.0")
	fi
	echo "$ver"
}

_get_remote_version() {
	curl -fsSL "$RAW_BASE/core.conf.example" 2>/dev/null | grep -E '^version' | head -1 | cut -d'"' -f2 || echo ""
}

# ------------------------------------------------------------------
# Changelog between current and remote HEAD
# ------------------------------------------------------------------
_show_changelog() {
	log_info "Recent changes:"
	if [[ -d "$CORE_HOME/.git" ]]; then
		cd "$CORE_HOME"
		git log --oneline HEAD..origin/main 2>/dev/null | head -20 || true
	else
		# Show latest commit messages via GitHub API
		curl -fsSL "https://api.github.com/repos/waldnerverges27-collab/core-linux/commits?per_page=10" 2>/dev/null \
			| jq -r '.[] | "  \(.sha[:7]) \(.commit.message | split("\n")[0])"' 2>/dev/null | head -10 || true
	fi
}

# ------------------------------------------------------------------
# Update via git pull (fast path — only when CORE_HOME is a git repo)
# ------------------------------------------------------------------
_git_update() {
	cd "$CORE_HOME"
	git fetch origin 2>/dev/null || { log_error "Git fetch failed"; return 1; }

	local behind
	behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
	if [[ "$behind" -eq 0 ]]; then
		return 0   # already up to date
	fi

	log_info "Updates available ($behind commits behind)"
	_show_changelog
	echo ""
	if ! confirm "Apply updates?"; then
		log_info "Update cancelled."
		return 0
	fi

	git pull origin main 2>/dev/null || { log_error "Git pull failed (merge conflict?)"; return 1; }
	return 0
}

# ------------------------------------------------------------------
# Update via tarball download (fallback — works for piped installs)
# ------------------------------------------------------------------
_tarball_update() {
	log_step "Downloading latest core-linux from GitHub..."
	local tmpdir
	tmpdir=$(mktemp -d)

	if ! curl -fsSL "$REPO_BASE/archive/refs/heads/main.tar.gz" \
		| tar -xz -C "$tmpdir" --strip=1 2>/dev/null; then
		rm -rf "$tmpdir"
		log_error "Failed to download latest version."
		return 1
	fi

	# Show changelog from the downloaded version
	local new_ver
	new_ver=$(grep -E '^version' "$tmpdir/core.conf.example" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "?")
	local cur_ver
	cur_ver=$(_get_local_version)

	log_info "Version: $cur_ver → $new_ver"
	_show_changelog
	echo ""
	if ! confirm "Apply updates?"; then
		rm -rf "$tmpdir"
		log_info "Update cancelled."
		return 0
	fi

	log_step "Updating framework files..."
	# Preserve installed state and config
	cp -r "$tmpdir/modules"  "$CORE_HOME/"
	cp -r "$tmpdir/lib"      "$CORE_HOME/"
	cp    "$tmpdir/core"     "$CORE_HOME/core"
	cp    "$tmpdir/install.sh"   "$CORE_HOME/install.sh" 2>/dev/null || true
	cp    "$tmpdir/uninstall.sh" "$CORE_HOME/uninstall.sh" 2>/dev/null || true
	cp    "$tmpdir/Makefile" "$CORE_HOME/Makefile" 2>/dev/null || true
	cp    "$tmpdir/core.conf.example" "$CORE_HOME/core.conf.example" 2>/dev/null || true
	chmod +x "$CORE_HOME/core"

	rm -rf "$tmpdir"
	return 0
}

# ------------------------------------------------------------------
# Rebuild TUI after update
# ------------------------------------------------------------------
_rebuild_tui() {
	if ! command -v go &>/dev/null; then
		log_info "Go not available; skipping TUI rebuild."
		return 0
	fi

	local tui_src="$CORE_HOME/cmd/core-tui"
	if [[ ! -f "$tui_src/main.go" ]]; then
		log_info "TUI source not found at $tui_src; skipping rebuild."
		return 0
	fi

	log_step "Rebuilding TUI..."
	cd "$tui_src"
	go mod tidy 2>/dev/null || true
	if go build -ldflags="-s -w" -o core-tui . 2>/dev/null; then
		cp core-tui "$CORE_HOME/core-tui"
		ln -sf "$CORE_HOME/core-tui" "$CORE_BIN/core-tui" 2>/dev/null || true
		log_success "TUI rebuilt."
	else
		log_warn "TUI rebuild failed — try installing Go or run 'core update --no-tui'."
	fi
}

# ------------------------------------------------------------------
# Public entry point: self_update
# ------------------------------------------------------------------
self_update() {
	local check_only=0
	local no_tui=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--check|-c) check_only=1; shift ;;
			--no-tui)   no_tui=1; shift ;;
			*) break ;;
		esac
	done

	log_step "Checking for updates..."

	local cur_ver
	cur_ver=$(_get_local_version)

	# Get remote version (fast check)
	local remote_ver
	remote_ver=$(_get_remote_version)
	if [[ -z "$remote_ver" ]]; then
		log_warn "Could not reach GitHub. Check your internet connection."
		return 1
	fi

	log_info "Local version:  $cur_ver"
	log_info "Remote version: $remote_ver"

	if [[ "$remote_ver" == "$cur_ver" ]]; then
		# Same version string — still check for newer commits
		if [[ -d "$CORE_HOME/.git" ]]; then
			cd "$CORE_HOME"
			git fetch origin 2>/dev/null || true
			local behind
			behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
			if [[ "$behind" -eq 0 ]]; then
				log_success "Already up to date (v$cur_ver)."
				return 0
			fi
			log_info "New commits available ($behind behind origin)."
		else
			log_success "Already up to date (v$cur_ver)."
			return 0
		fi
	fi

	if [[ $check_only -eq 1 ]]; then
		log_info "Update available: v$cur_ver → v$remote_ver"
		log_info "Run 'core update' to upgrade."
		return 0
	fi

	# --- Apply update ---
	log_step "Updating core-linux (v$cur_ver → v$remote_ver)..."

	local ok=0
	if [[ -d "$CORE_HOME/.git" ]]; then
		_git_update && ok=1
	else
		_tarball_update && ok=1
	fi

	if [[ $ok -eq 0 ]]; then
		log_error "Update failed."
		return 1
	fi

	# Rebuild TUI unless --no-tui
	if [[ $no_tui -eq 0 ]]; then
		_rebuild_tui
	fi

	log_success "Updated to v$(_get_local_version)."
	return 0
}

# ------------------------------------------------------------------
# Check-only helper — shows a one-line message at startup
# ------------------------------------------------------------------
version_check() {
	local cur_ver="${1:-$(_get_local_version)}"
	local remote_ver
	remote_ver=$(_get_remote_version)
	if [[ -n "$remote_ver" && "$remote_ver" != "$cur_ver" ]]; then
		log_info "Update available: v$cur_ver → v$remote_ver"
		log_info "Run 'core update' to upgrade."
	fi
}
