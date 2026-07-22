#!/usr/bin/env bash
set -euo pipefail

# Self-update mechanism for core-linux
# Works with git repos AND piped (curl | bash) installs.
# Detects updates by comparing commit SHA, not just version string.

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"
CORE_BIN="${CORE_BIN:-$HOME/.local/bin}"
CORE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/core-linux"
CORE_STATE_FILE="${CORE_STATE_FILE:-$CORE_STATE_DIR/installed.json}"
REPO_API="https://api.github.com/repos/waldnerverges27-collab/core-linux"
RAW_BASE="https://raw.githubusercontent.com/waldnerverges27-collab/core-linux/main"
REPO_TARBALL="https://github.com/waldnerverges27-collab/core-linux/archive/refs/heads/main.tar.gz"

source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/utils/prompt.sh"
source "$CORE_HOME/lib/utils/fs.sh"

# ------------------------------------------------------------------
# Git-like helpers
# ------------------------------------------------------------------
_get_local_version() {
	local ver="1.0.0"
	if [[ -f "$CORE_HOME/core.conf.example" ]]; then
		ver=$(grep -E '^version' "$CORE_HOME/core.conf.example" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "1.0.0")
	fi
	echo "$ver"
}

# Returns the SHA of the last commit we synced to (stored in state)
_get_last_commit_sha() {
	jq -r '._meta.last_update_sha // ""' "$CORE_STATE_FILE" 2>/dev/null || echo ""
}

# Stores the commit SHA after a successful update
_set_last_commit_sha() {
	local sha="${1:?Usage: _set_last_commit_sha <sha>}"
	local tmp
	tmp=$(mktemp)
	if jq ". + {\"_meta\": {\"last_update_sha\": \"$sha\"}}" "$CORE_STATE_FILE" > "$tmp" 2>/dev/null; then
		mv "$tmp" "$CORE_STATE_FILE"
	else
		rm -f "$tmp"
	fi
}

# Fetches the latest commit SHA from GitHub default branch
_get_remote_sha() {
	curl -fsSL "$REPO_API/commits/main" 2>/dev/null | jq -r '.sha // ""' 2>/dev/null || echo ""
}

# Fetches the remote version string
_get_remote_version() {
	curl -fsSL "$RAW_BASE/core.conf.example" 2>/dev/null | grep -E '^version' | head -1 | cut -d'"' -f2 || echo ""
}

# ------------------------------------------------------------------
# Changelog
# ------------------------------------------------------------------
_show_changelog() {
	log_info "Recent changes:"
	if [[ -d "$CORE_HOME/.git" ]]; then
		cd "$CORE_HOME"
		git log --oneline HEAD..origin/main 2>/dev/null | head -20 || true
	else
		# Get commits since our last known SHA, or last 10
		local since_sha
		since_sha=$(_get_last_commit_sha)
		if [[ -n "$since_sha" ]]; then
			curl -fsSL "$REPO_API/commits?per_page=20&sha=main" 2>/dev/null \
				| jq -r --arg sha "$since_sha" '
					[.[] | select(.sha != $sha)] as $commits
					| if ($commits | length) > 0
					  then $commits[:10][] | "  \(.sha[:7]) \(.commit.message | split("\n")[0])"
					  else "  (no new commits detected)"
					  end
				' 2>/dev/null | head -10 || echo "  (could not fetch changelog)"
		else
			curl -fsSL "$REPO_API/commits?per_page=10&sha=main" 2>/dev/null \
				| jq -r '.[] | "  \(.sha[:7]) \(.commit.message | split("\n")[0])"' 2>/dev/null | head -10 || echo "  (could not fetch changelog)"
		fi
	fi
}

# ------------------------------------------------------------------
# Update via git pull (fast path)
# ------------------------------------------------------------------
_git_update() {
	cd "$CORE_HOME"
	git fetch origin 2>/dev/null || { log_error "Git fetch failed"; return 1; }

	local behind
	behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
	if [[ "$behind" -eq 0 ]]; then
		return 0
	fi

	log_info "Updates available ($behind commits behind)"
	_show_changelog
	echo ""
	if ! confirm "Apply updates?"; then
		log_info "Update cancelled."
		return 0
	fi

	git pull origin main 2>/dev/null || { log_error "Git pull failed (merge conflict?)"; return 1; }

	# Record SHA
	local new_sha
	new_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
	[[ -n "$new_sha" ]] && _set_last_commit_sha "$new_sha"
	return 0
}

# ------------------------------------------------------------------
# Update via tarball download (universal fallback)
# ------------------------------------------------------------------
_tarball_update() {
	log_step "Downloading latest core-linux from GitHub..."
	local tmpdir
	tmpdir=$(mktemp -d)

	if ! curl -fsSL "$REPO_TARBALL" 2>/dev/null \
		| tar -xz -C "$tmpdir" --strip=1 2>/dev/null; then
		rm -rf "$tmpdir"
		log_error "Failed to download latest version."
		return 1
	fi

	local cur_ver new_ver
	cur_ver=$(_get_local_version)
	new_ver=$(grep -E '^version' "$tmpdir/core.conf.example" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "?")
	log_info "Version: $cur_ver → $new_ver"

	_show_changelog
	echo ""
	if ! confirm "Apply updates?"; then
		rm -rf "$tmpdir"
		log_info "Update cancelled."
		return 0
	fi

	log_step "Updating framework files..."
	cp -r "$tmpdir/modules"  "$CORE_HOME/"
	cp -r "$tmpdir/lib"      "$CORE_HOME/"
	cp    "$tmpdir/core"     "$CORE_HOME/core"
	cp    "$tmpdir/install.sh"   "$CORE_HOME/install.sh" 2>/dev/null || true
	cp    "$tmpdir/uninstall.sh" "$CORE_HOME/uninstall.sh" 2>/dev/null || true
	cp    "$tmpdir/Makefile" "$CORE_HOME/Makefile" 2>/dev/null || true
	cp    "$tmpdir/core.conf.example" "$CORE_HOME/core.conf.example" 2>/dev/null || true
	chmod +x "$CORE_HOME/core"

	# Record update SHA
	local new_sha
	new_sha=$(_get_remote_sha)
	[[ -n "$new_sha" ]] && _set_last_commit_sha "$new_sha"

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
# Check if there are pending updates
# Returns 0 if up to date, 1 if update available, 2 if error
# ------------------------------------------------------------------
_check_update_available() {
	local cur_ver remote_ver local_sha remote_sha

	cur_ver=$(_get_local_version)
	remote_ver=$(_get_remote_version)
	if [[ -z "$remote_ver" ]]; then
		log_warn "Could not reach GitHub. Check your internet connection."
		return 2
	fi

	# If version strings differ, update is definitely available
	if [[ "$remote_ver" != "$cur_ver" ]]; then
		return 1
	fi

	# Same version — compare commit SHAs
	if [[ -d "$CORE_HOME/.git" ]]; then
		cd "$CORE_HOME"
		git fetch origin 2>/dev/null || true
		local behind
		behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
		if [[ "$behind" -gt 0 ]]; then
			return 1
		fi
		return 0
	fi

	# Tarball path: compare remote SHA with last known SHA
	remote_sha=$(_get_remote_sha)
	[[ -z "$remote_sha" ]] && return 2

	local_sha=$(_get_last_commit_sha)
	if [[ -n "$local_sha" && "$local_sha" != "$remote_sha" ]]; then
		return 1
	fi

	# No known last SHA? Compare version string-based freshness
	if [[ -z "$local_sha" ]]; then
		# We have no record of updating before — assume current is newest
		# Store it so next time we can compare
		_set_last_commit_sha "$remote_sha"
	fi

	return 0
}

# ------------------------------------------------------------------
# Public entry point
# ------------------------------------------------------------------
self_update() {
	local check_only=0
	local no_tui=0
	local force=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--check|-c) check_only=1; shift ;;
			--no-tui)   no_tui=1; shift ;;
			--force|-f) force=1;  shift ;;
			*) break ;;
		esac
	done

	log_step "Checking for updates..."

	local cur_ver remote_ver
	cur_ver=$(_get_local_version)
	remote_ver=$(_get_remote_version)

	_check_update_available; local rc=$?

	if [[ $rc -eq 2 ]]; then
		return 1   # network error — already reported
	fi

	if [[ $rc -eq 0 ]] && [[ $force -eq 0 ]]; then
		log_success "Already up to date (v$cur_ver)."
		return 0
	fi

	if [[ $rc -eq 0 ]] && [[ $force -eq 1 ]]; then
		log_info "Forcing update (v$cur_ver)..."
	fi

	if [[ $rc -eq 1 ]]; then
		log_info "Update available: v$cur_ver → v${remote_ver:-latest}"
	fi

	_show_changelog

	if [[ $check_only -eq 1 ]]; then
		log_info "Run 'core update' to upgrade."
		return 0
	fi

	echo ""
	if ! confirm "Apply updates?"; then
		log_info "Update cancelled."
		return 0
	fi

	# --- Apply ---
	log_step "Updating core-linux..."

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

	# Rebuild TUI
	if [[ $no_tui -eq 0 ]]; then
		_rebuild_tui
	fi

	log_success "Updated to v$(_get_local_version)."
	return 0
}

# ------------------------------------------------------------------
# Startup version check (non-blocking, one-liner)
# ------------------------------------------------------------------
version_check() {
	local cur_ver="${1:-$(_get_local_version)}"
	_check_update_available 2>/dev/null; local rc=$?
	if [[ $rc -eq 1 ]]; then
		local remote_ver
		remote_ver=$(_get_remote_version 2>/dev/null || echo "latest")
		log_info "Update available: v$cur_ver → v$remote_ver"
		log_info "Run 'core update' to upgrade."
	fi
}
