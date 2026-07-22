#!/usr/bin/env bats

setup() {
	export CORE_HOME="$BATS_TMPDIR/core-linux-platform-test"
	mkdir -p "$CORE_HOME/lib/utils"
}

@test "detect_distro returns known distro or unknown" {
	CORE_FORCE_DISTRO=""
	source "$CORE_HOME/lib/utils/platform.sh"
	result=$(detect_distro)
	[[ "$result" =~ ^(ubuntu|fedora|arch|opensuse|void|unknown)$ ]]
}

@test "detect_distro respects CORE_FORCE_DISTRO" {
	export CORE_FORCE_DISTRO="arch"
	source "$CORE_HOME/lib/utils/platform.sh"
	result=$(detect_distro)
	[ "$result" = "arch" ]
}

@test "detect_arch returns known architecture" {
	source "$CORE_HOME/lib/utils/platform.sh"
	result=$(detect_arch)
	[[ -n "$result" ]]
}

@test "detect_pkg_manager returns known manager" {
	source "$CORE_HOME/lib/utils/platform.sh"
	export CORE_FORCE_DISTRO="ubuntu"
	result=$(detect_pkg_manager)
	[ "$result" = "apt" ]
}
