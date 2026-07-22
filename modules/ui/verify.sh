#!/usr/bin/env bash
set -euo pipefail

errors=0
for pkg in tailwindcss shadcn @radix-ui/react-primitives framer-motion @nextui-org/react daisyui; do
	if npm list -g "$pkg" &>/dev/null; then
		echo "✔ $pkg installed"
	else
		echo "✗ $pkg not installed"
	fi
done
exit $errors
