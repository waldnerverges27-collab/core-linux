#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	tailwind) npm uninstall -g tailwindcss 2>/dev/null || true ;;
	shadcn-ui) npm uninstall -g shadcn 2>/dev/null || true ;;
	radix) npm uninstall -g @radix-ui/react-primitives 2>/dev/null || true ;;
	framer-motion) npm uninstall -g framer-motion 2>/dev/null || true ;;
	nextui) npm uninstall -g @nextui-org/react 2>/dev/null || true ;;
	daisyui) npm uninstall -g daisyui 2>/dev/null || true ;;
	*) echo "Unknown tool: $tool"; exit 1 ;;
esac

echo "Removed: $tool"
