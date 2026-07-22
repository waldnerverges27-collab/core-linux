#!/usr/bin/env bash
set -euo pipefail

# Structured logger for core-linux
# All output to stderr (stdout reserved for data/pipe)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[[ -f "$SCRIPT_DIR/colors.sh" ]] && source "$SCRIPT_DIR/colors.sh"

log_info()   { echo -e "$(color_fg "${COLORS[secondary]}")ℹ️  $*$(color_reset)" >&2; }
log_warn()   { echo -e "$(color_fg "${COLORS[warning]}")⚠️  $*$(color_reset)" >&2; }
log_error()  { echo -e "$(color_fg "${COLORS[error]}")❌ $*$(color_reset)" >&2; }
log_success() { echo -e "$(color_fg "${COLORS[success]}")✔️ $*$(color_reset)" >&2; }
log_step()   { echo -e "$(color_fg "${COLORS[primary]}")▶️  $*$(color_reset)" >&2; }
log_debug()  { [[ "${CORE_DEBUG:-0}" == "1" ]] && echo -e "$(color_fg "${COLORS[muted]}")🔍 $*$(color_reset)" >&2; }
