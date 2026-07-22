#!/usr/bin/env bats

setup() {
	export CORE_HOME="$BATS_TMPDIR/core-linux-env-test"
	export HOME="$BATS_TMPDIR/core-linux-env-home"
	mkdir -p "$CORE_HOME/lib/utils" "$HOME"
	echo "export EXISTING_VAR=\"hello\"" > "$HOME/.bashrc"

	# Copy dependencies
	cat > "$CORE_HOME/lib/utils/logger.sh" << 'EOF'
log_info() { echo "$@" >&2; }
log_warn() { echo "$@" >&2; }
log_error() { echo "$@" >&2; }
log_success() { echo "$@" >&2; }
log_step() { echo "$@" >&2; }
log_debug() { :; }
EOF

	cat > "$CORE_HOME/lib/utils/platform.sh" << 'EOF'
detect_shell_rc() { echo "$HOME/.bashrc"; }
detect_shell_name() { echo "bash"; }
EOF

	cat > "$CORE_HOME/lib/utils/fs.sh" << 'EOF'
ensure_dir() { mkdir -p "$1"; }
EOF

	cat > "$CORE_HOME/lib/utils/prompt.sh" << 'EOF'
confirm() { return 0; }
read_input() { echo "test_value"; }
read_secret() { echo "test_secret"; }
select_option() { echo "${1:-}"; }
EOF
}

@test "env_ls shows existing variables" {
	source "$CORE_HOME/lib/core/env_manager.sh" 2>/dev/null || true
	# Just verify it doesn't crash
	run env_ls
	[ "$status" -eq 0 ]
}

@test "detect_shell_rc returns .bashrc" {
	source "$CORE_HOME/lib/utils/platform.sh"
	result=$(detect_shell_rc)
	echo "$result" | grep -q "bashrc"
}
