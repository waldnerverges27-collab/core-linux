#!/usr/bin/env bats

setup() {
	export CORE_HOME="$BATS_TMPDIR/core-linux-brain-test"
	export BRAIN_DIR="$BATS_TMPDIR/core-linux-brain-data"
	export HOME="$BATS_TMPDIR"
	mkdir -p "$CORE_HOME/lib/utils" "$CORE_HOME/lib/core"

	# Minimal logger
	cat > "$CORE_HOME/lib/utils/logger.sh" << 'EOF'
log_info() { echo "$@" >&2; }
log_warn() { echo "$@" >&2; }
log_error() { echo "$@" >&2; }
log_success() { echo "$@" >&2; }
log_step() { echo "$@" >&2; }
EOF

	cat > "$CORE_HOME/lib/utils/fs.sh" << 'EOF'
ensure_dir() { mkdir -p "$1"; }
EOF

	cat > "$CORE_HOME/lib/utils/prompt.sh" << 'EOF'
confirm() { return 0; }
read_input() { echo "test_value"; }
read_secret() { echo "test_secret"; }
EOF
}

@test "brain_init creates directories" {
	source "$CORE_HOME/lib/core/brain.sh"
	brain_init
	[ -d "$BRAIN_DIR" ]
	[ -d "$BRAIN_DIR/general" ]
}

@test "brain_slug generates valid slugs" {
	source "$CORE_HOME/lib/core/brain.sh"
	result=$(brain_slug "Hello World Test!")
	[ "$result" = "hello-world-test" ]
}

@test "brain_save and brain_ls" {
	source "$CORE_HOME/lib/core/brain.sh"
	brain_init
	brain_save "Test Memory" "This is content" "test,memory" "general"
	[ -f "$BRAIN_DIR/general/test-memory.md" ]
}

@test "brain_search finds saved memory" {
	source "$CORE_HOME/lib/core/brain.sh"
	brain_init
	brain_save "UniqueMemory" "Searchable Content" "test" "general"
	result=$(brain_search "UniqueMemory")
	echo "$result" | grep -q "UniqueMemory"
}
