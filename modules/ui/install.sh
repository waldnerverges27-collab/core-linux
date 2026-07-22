#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	tailwind)
		npm install -g tailwindcss
		;;
	shadcn-ui)
		npm install -g shadcn
		;;
	radix)
		npm install -g @radix-ui/react-primitives
		;;
	framer-motion)
		npm install -g framer-motion
		;;
	nextui)
		npm install -g @nextui-org/react
		;;
	daisyui)
		npm install -g daisyui
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Done: $tool"
