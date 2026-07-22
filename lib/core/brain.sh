#!/usr/bin/env bash
set -euo pipefail

# Second Brain for core-linux
# Markdown-based memory system with YAML frontmatter

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"
BRAIN_DIR="${BRAIN_DIR:-$HOME/.local/share/core-linux/brain}"
CORE_CONFIG="${CORE_CONFIG:-$HOME/.config/core-linux/config.toml}"

source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/utils/prompt.sh"
source "$CORE_HOME/lib/utils/fs.sh"

brain_init() {
	ensure_dir "$BRAIN_DIR"
	ensure_dir "$BRAIN_DIR/general"
	ensure_dir "$BRAIN_DIR/projects"
	ensure_dir "$BRAIN_DIR/notes"
	if [[ ! -f "$BRAIN_DIR/.gitignore" ]]; then
		echo ".DS_Store" > "$BRAIN_DIR/.gitignore"
	fi
	log_success "Brain initialized at $BRAIN_DIR"
}

brain_slug() {
	local title="$1"
	echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

brain_save() {
	local title="${1:-}"
	local content="${2:-}"
	local tags="${3:-}"
	local category="${4:-general}"

	[[ -z "$title" ]] && title=$(read_input "Memory title")
	[[ -z "$content" ]] && content=$(read_input "Memory content (body)")
	[[ -z "$tags" ]] && tags=$(read_input "Tags (comma-separated)")
	[[ -z "$category" ]] && category="general"

	ensure_dir "$BRAIN_DIR/$category"
	local slug
	slug=$(brain_slug "$title")
	local file="$BRAIN_DIR/$category/$slug.md"
	local now
	now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	cat > "$file" <<- EOFMEM
---
title: "$title"
tags: [$(echo "$tags" | sed 's/, */", "/g' | sed 's/^/"/;s/$/"/')]
category: "$category"
created: $now
updated: $now
relations: []
---

$content
EOFMEM
	log_success "Saved memory: $file"
}

brain_ls() {
	local category="${1:-}"
	if [[ -n "$category" ]]; then
		[[ -d "$BRAIN_DIR/$category" ]] || { log_info "No memories in category $category"; return 0; }
		for f in "$BRAIN_DIR/$category"/*.md; do
			[[ -f "$f" ]] || continue
			local title slug
			slug=$(basename "$f" .md)
			title=$(grep "^title:" "$f" | head -1 | cut -d'"' -f2)
			local tags
			tags=$(grep "^tags:" "$f" | head -1 | cut -d'[' -f2 | cut -d']' -f1)
			echo "  $slug — $title [$tags]"
		done
	else
		local cat_dir
		for cat_dir in "$BRAIN_DIR"/*/; do
			[[ -d "$cat_dir" ]] || continue
			local cat_name
			cat_name=$(basename "$cat_dir")
			local count
			count=$(find "$cat_dir" -name "*.md" 2>/dev/null | wc -l)
			echo "Category: $cat_name ($count memories)"
			for f in "$cat_dir"/*.md; do
				[[ -f "$f" ]] || continue
				local title slug
				slug=$(basename "$f" .md)
				title=$(grep "^title:" "$f" | head -1 | cut -d'"' -f2)
				echo "  $slug — $title"
			done
		done
	fi
}

brain_show() {
	local file="${1:?Usage: brain_show <slug> [category]}"
	local category="${2:-general}"
	if [[ "$file" != *".md" ]]; then
		file="$BRAIN_DIR/$category/$file.md"
	fi
	if [[ "$file" != /* ]]; then
		file="$BRAIN_DIR/$category/$file"
	fi
	[[ -f "$file" ]] || { log_error "Memory not found: $file"; return 1; }
	cat "$file"
}

brain_search() {
	local query="${1:?Usage: brain_search <query>}"
	[[ -d "$BRAIN_DIR" ]] || { log_info "Brain not initialized"; return 0; }
	local results
	results=$(grep -ril "$query" "$BRAIN_DIR" --include="*.md" 2>/dev/null || true)
	[[ -z "$results" ]] && { log_info "No matches for '$query'"; return 0; }
	local count=0
	while IFS= read -r f; do
		local title rel_path
		title=$(grep "^title:" "$f" | head -1 | cut -d'"' -f2)
		rel_path="${f#$BRAIN_DIR/}"
		echo "  $rel_path — $title"
		count=$((count+1))
	done <<< "$results"
	echo "Found $count result(s)"
}

brain_edit() {
	local file="${1:?Usage: brain_edit <slug> [category]}"
	local category="${2:-general}"
	if [[ "$file" != *".md" ]]; then
		file="$BRAIN_DIR/$category/$file.md"
	fi
	if [[ "$file" != /* ]]; then
		file="$BRAIN_DIR/$category/$file"
	fi
	[[ -f "$file" ]] || { log_error "Memory not found: $file"; return 1; }
	local editor="${EDITOR:-vim}"
	"$editor" "$file"
	local now
	now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local tmp
	tmp=$(mktemp)
	sed "s/^updated:.*/updated: $now/" "$file" > "$tmp" && mv "$tmp" "$file"
	log_success "Updated memory"
}

brain_delete() {
	local file="${1:?Usage: brain_delete <slug> [category]}"
	local category="${2:-general}"
	if [[ "$file" != *".md" ]]; then
		file="$BRAIN_DIR/$category/$file.md"
	fi
	if [[ "$file" != /* ]]; then
		file="$BRAIN_DIR/$category/$file"
	fi
	[[ -f "$file" ]] || { log_error "Memory not found: $file"; return 1; }
	if confirm "Delete $file?"; then
		rm "$file"
		log_success "Deleted memory"
	fi
}

brain_reset() {
	if confirm "Delete ALL brain data?" "y"; then
		rm -rf "$BRAIN_DIR"
		brain_init
		log_success "Brain reset to empty"
	fi
}

brain_graph() {
	local category="${1:-}"
	local search_dir="$BRAIN_DIR"
	[[ -n "$category" ]] && search_dir="$BRAIN_DIR/$category"
	[[ -d "$search_dir" ]] || { log_info "No data"; return 0; }

	echo "Core Memory Graph"
	echo "================="
	local all_relations=()
	local f
	for f in "$search_dir"/*.md; do
		[[ -f "$f" ]] || continue
		local title slug relations
		slug=$(basename "$f" .md)
		title=$(grep "^title:" "$f" | head -1 | cut -d'"' -f2)
		relations=$(grep "^relations:" "$f" | cut -d'[' -f2 | cut -d']' -f1)
		echo ""
		echo "  ┌─ $title"
		echo "  │  ($slug)"
		if [[ -n "$relations" && "$relations" != " " && "$relations" != "\"\"" ]]; then
			local rel
			for rel in $(echo "$relations" | tr ',' ' '); do
				rel="${rel//\"/}"; rel="${rel// /}"
				[[ -n "$rel" ]] && echo "  ├──→ $rel"
			done
		fi
		echo "  └──"
	done
}

brain_sync() {
	if ! command -v git &>/dev/null; then
		log_error "git is required for sync"
		return 1
	fi

	local remote=""
	if [[ -f "$CORE_CONFIG" ]]; then
		remote=$(grep -E '^\s*sync_remote\s*=' "$CORE_CONFIG" 2>/dev/null | head -1 | cut -d'"' -f2)
	fi
	if [[ -z "$remote" ]]; then
		log_error "No sync remote configured. Set brain.sync_remote in $CORE_CONFIG"
		return 1
	fi

	ensure_dir "$BRAIN_DIR"

	if [[ ! -d "$BRAIN_DIR/.git" ]]; then
		log_step "Initializing git repo for brain..."
		cd "$BRAIN_DIR"
		git init
		git remote add origin "$remote"
		echo ".DS_Store" > .gitignore
		git add -A
		git commit -m "brain init $(date -u +%Y-%m-%d)" 2>/dev/null || true
	fi

	cd "$BRAIN_DIR"
	log_step "Syncing brain with $remote..."
	git add -A
	git commit -m "brain update $(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null || true
	git pull --rebase origin main 2>/dev/null || log_warn "Pull failed (first push?)"
	git push origin main 2>/dev/null || log_warn "Push failed — check remote config"
	log_success "Brain synced"
}
