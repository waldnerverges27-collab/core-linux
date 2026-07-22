#!/usr/bin/env bats

setup() {
	export CORE_HOME="$BATS_TMPDIR/core-linux-home"
	export CORE_STATE_DIR="$BATS_TMPDIR/core-linux-state"
	export CORE_STATE_FILE="$CORE_STATE_DIR/installed.json"
	mkdir -p "$CORE_HOME/lib/core" "$CORE_STATE_DIR"

	# Copy state.sh into temp
	cp "$BATS_TEST_DIRNAME/../lib/core/state.sh" "$CORE_HOME/lib/core/state.sh"
	# Create mock installed.json
	echo '{"modules":{}}' > "$CORE_STATE_FILE"
}

@test "state_init creates state file" {
	source "$CORE_HOME/lib/core/state.sh"
	rm -f "$CORE_STATE_FILE"
	state_init
	[ -f "$CORE_STATE_FILE" ]
}

@test "module_is_installed returns false for missing module" {
	source "$CORE_HOME/lib/core/state.sh"
	run module_is_installed "nonexistent"
	[ "$status" -ne 0 ]
}

@test "mark_module_tool_installed and tool_is_installed" {
	source "$CORE_HOME/lib/core/state.sh"
	mark_module_tool_installed "testmod" "testtool" "1.0.0"
	run tool_is_installed "testmod" "testtool"
	[ "$status" -eq 0 ]
}

@test "mark_module_tool_removed" {
	source "$CORE_HOME/lib/core/state.sh"
	mark_module_tool_installed "testmod" "testtool" "1.0.0"
	mark_module_tool_removed "testmod" "testtool"
	run tool_is_installed "testmod" "testtool"
	[ "$status" -ne 0 ]
}

@test "get_installed_modules returns empty initially" {
	source "$CORE_HOME/lib/core/state.sh"
	result=$(get_installed_modules)
	[ -z "$result" ]
}

@test "get_installed_modules returns after install" {
	source "$CORE_HOME/lib/core/state.sh"
	mark_module_tool_installed "testmod" "testtool" "1.0.0"
	result=$(get_installed_modules)
	echo "$result" | grep -q "testmod"
}
