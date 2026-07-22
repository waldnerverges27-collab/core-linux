#!/usr/bin/env bash
set -euo pipefail

# Self-update mechanism for core-linux
# Works with git repos AND piped (curl | bash) installs.
# All GitHub calls use short timeouts to avoid hanging.

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"
CORE_BIN="${CORE_BIN:-$HOME/.local/bin}"
CORE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/core-linux"
CORE_STATE_FILE="${CORE_STATE_FILE:-$CORE_STATE_DIR/installed.json}"

REPO="waldnerverges27-collab/core-linux"
RAW_BASE="https://raw.githubusercontent.com/$REPO/main"
REPO_API="https://api.github.com/repos/$REPO"
REPO_TARBALL="https://github.com/$REPO/archive/refs/heads/main.tar.gz"

# All curl calls timeout after 5s connect + 10s total
CURL="curl -fsSL --connect-timeout 5 --max-time 10"

source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/utils/prompt.sh"
source "$CORE_HOME/lib/utils/fs.sh"

# ------------------------------------------------------------------
# Version helpers (single network call each — called sparingly)
# ------------------------------------------------------------------
_get_local_version() {
	local ver="1.0.0"
	if [[ -f "$CORE_HOME/core.conf.example" ]]; then
		ver=$(grep -E '^version' "$CORE_HOME/core.conf.example" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "1.0.0")
	fi
	echo "$ver"
}

_get_remote_version() {
	$CURL "$RAW_BASE/core.conf.example" 2>/dev/null | grep -E '^version' | head -1 | cut -d'"' -f2 || echo ""
}

_get_remote_sha() {
	$CURL "$REPO_API/commits/main" 2>/dev/null | jq -r '.sha // ""' 2>/dev/null || echo ""
}

_get_last_commit_sha() {
	jq -r '._meta.last_update_sha // ""' "$CORE_STATE_FILE" 2>/dev/null || echo ""
}

_set_last_commit_sha() {
	local sha="${1:?Usage: _set_last_commit_sha <sha>}"
	local tmp; tmp=$(mktemp)
	if jq ". + {\"_meta\": {\"last_update_sha\": \"$sha\"}}" "$CORE_STATE_FILE" > "$tmp" 2>/dev/null; then
		mv "$tmp" "$CORE_STATE_FILE"
	else
		rm -f "$tmp"
	fi
}

# ------------------------------------------------------------------
# Changelog (single API call)
# ------------------------------------------------------------------
_show_changelog() {
	log_info "Recent changes:"
	if [[ -d "$CORE_HOME/.git" ]]; then
		cd "$CORE_HOME"
		git log --oneline HEAD..origin/main 2>/dev/null | head -20 || true
	else
		# Show latest commits via GitHub API
		local since_sha
		since_sha=$(_get_last_commit_sha)
		if [[ -n "$since_sha" ]]; then
			$CURL "$REPO_API/commits?per_page=20&sha=main" 2>/dev/null \
				| jq -r --arg sha "$since_sha" '
					[.[] | select(.sha != $sha)] as $commits
					| if ($commits | length) > 0
					  then $commits[:10][] | "  \(.sha[:7]) \(.commit.message | split("\n")[0])"
					  else "  (no new commits detected)"
					  end
				' 2>/dev/null | head -10 || echo "  (could not fetch changelog)"
		else
			$CURL "$REPO_API/commits?per_page=10&sha=main" 2>/dev/null \
				| jq -r '.[] | "  \(.sha[:7]) \(.commit.message | split("\n")[0])"' 2>/dev/null | head -10 || echo "  (could not fetch changelog)"
		fi
	fi
}

# ------------------------------------------------------------------
# Update via git pull
# ------------------------------------------------------------------
_git_update() {
	cd "$CORE_HOME"
	git fetch origin 2>/dev/null || { log_error "Git fetch failed"; return 1; }

	local behind
	behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
	[[ "$behind" -eq 0 ]] && return 0

	log_info "Downloading $behind new commits..."
	git pull origin main 2>/dev/null || { log_error "Git pull failed"; return 1; }

	local new_sha
	new_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
	[[ -n "$new_sha" ]] && _set_last_commit_sha "$new_sha"
	return 0
}

# ------------------------------------------------------------------
# Update via tarball (fallback universal)
# ------------------------------------------------------------------
_tarball_update() {
	log_step "Downloading latest version..."
	local tmpdir; tmpdir=$(mktemp -d)

	if ! $CURL "$REPO_TARBALL" | tar -xz -C "$tmpdir" --strip=1 2>/dev/null; then
		rm -rf "$tmpdir"
		log_error "Download failed. Check your connection."
		return 1
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

	local new_sha; new_sha=$(_get_remote_sha)
	[[ -n "$new_sha" ]] && _set_last_commit_sha "$new_sha"
	rm -rf "$tmpdir"
	return 0
}

# ------------------------------------------------------------------
# Rebuild TUI after update
# ------------------------------------------------------------------
_rebuild_tui() {
	command -v go &>/dev/null || { log_info "Go no disponible, saltando reconstrucción TUI."; return 0; }
	[[ -f "$CORE_HOME/cmd/core-tui/main.go" ]] || { log_info "Fuente TUI no encontrada."; return 0; }

	log_step "Reconstruyendo TUI..."
	cd "$CORE_HOME/cmd/core-tui"
	go mod tidy 2>/dev/null || true
	if go build -ldflags="-s -w" -o core-tui . 2>/dev/null; then
		cp core-tui "$CORE_HOME/core-tui"
		ln -sf "$CORE_HOME/core-tui" "$CORE_BIN/core-tui" 2>/dev/null || true
		log_success "TUI reconstruida."
	else
		log_warn "Falló la reconstrucción de la TUI."
	fi
}

# ------------------------------------------------------------------
# self_update — entry point
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

	# ── Obtener versiones (UNA llamada remota) ──
	local cur_ver remote_ver
	cur_ver=$(_get_local_version)
	remote_ver=$(_get_remote_version)

	log_step "Buscando actualizaciones..."
	log_info "Versión local:  $cur_ver"

	# ── Error de red? ──
	if [[ -z "$remote_ver" ]]; then
		log_warn "No se pudo contactar a GitHub (verifica tu conexión)."
		log_info "Si el problema persiste, reinstala con:"
		log_info "  curl -fsSL $RAW_BASE/install.sh | bash"
		return 1
	fi

	log_info "Versión remota: $remote_ver"

	# ── Determinar si hay actualización ──
	local update_needed=0  # 0=no, 1=sí

	# 1. Versión diferente?
	if [[ "$remote_ver" != "$cur_ver" ]]; then
		update_needed=1
	fi

	# 2. Misma versión, mismo SHA? (solo si no es git)
	if [[ $update_needed -eq 0 ]] && [[ ! -d "$CORE_HOME/.git" ]]; then
		local remote_sha local_sha
		remote_sha=$(_get_remote_sha)
		if [[ -n "$remote_sha" ]]; then
			local_sha=$(_get_last_commit_sha)
			if { [[ -z "$local_sha" ]] || [[ "$local_sha" != "$remote_sha" ]]; }; then
				update_needed=1
			fi
			# Si es primera vez, guardar SHA para futuras comparaciones
			[[ -z "$local_sha" ]] && _set_last_commit_sha "$remote_sha"
		fi
	fi

	# 3. Misma versión, mismo SHA? (git)
	if [[ $update_needed -eq 0 ]] && [[ -d "$CORE_HOME/.git" ]]; then
		cd "$CORE_HOME"
		git fetch origin 2>/dev/null || true
		local behind
		behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
		[[ "$behind" -gt 0 ]] && update_needed=1
	fi

	# ── Resultado ──
	if [[ $update_needed -eq 0 ]] && [[ $force -eq 0 ]]; then
		log_success "Ya estás al día (v$cur_ver)."
		return 0
	fi

	if [[ $force -eq 1 ]]; then
		log_info "Forzando actualización (v$cur_ver)..."
	else
		log_info "Actualización disponible: v$cur_ver → v$remote_ver"
	fi

	_show_changelog

	if [[ $check_only -eq 1 ]]; then
		log_info "Ejecuta 'core update' para actualizar."
		return 0
	fi

	echo ""
	if ! confirm "¿Aplicar actualización?"; then
		log_info "Actualización cancelada."
		return 0
	fi

	# ── Aplicar ──
	log_step "Actualizando core-linux..."
	local ok=0
	if [[ -d "$CORE_HOME/.git" ]]; then
		_git_update && ok=1
	else
		_tarball_update && ok=1
	fi

	if [[ $ok -eq 0 ]]; then
		log_error "Actualización fallida."
		return 1
	fi

	[[ $no_tui -eq 0 ]] && _rebuild_tui
	log_success "Actualizado a v$(_get_local_version)."
	version_check
}

# ------------------------------------------------------------------
# Startup version check (una línea, silenciosa en error)
# ------------------------------------------------------------------
version_check() {
	local cur_ver="${1:-$(_get_local_version)}"
	local remote_ver
	remote_ver=$(_get_remote_version 2>/dev/null) || true
	[[ -z "$remote_ver" ]] && return 0
	if [[ "$remote_ver" != "$cur_ver" ]]; then
		log_info "Actualización disponible: v$cur_ver → v$remote_ver"
		log_info "Ejecuta 'core update' para actualizar."
	elif [[ -d "$CORE_HOME/.git" ]]; then
		cd "$CORE_HOME" 2>/dev/null || true
		git fetch origin 2>/dev/null || true
		local behind
		behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
		[[ "$behind" -gt 0 ]] && log_info "Nuevos commits disponibles. Ejecuta 'core update'."
	fi
}
