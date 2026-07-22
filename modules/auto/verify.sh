#!/usr/bin/env bash
set -euo pipefail

errors=0
for cmd in jenkins.war gitlab-runner drone argo dagger; do
	if command -v "$cmd" &>/dev/null; then
		echo "✔ $cmd found"
	else
		echo "✗ $cmd not found"
		errors=$((errors+1))
	fi
done
for dir in /opt/actions-runner; do
	if [[ -d "$dir" ]]; then
		echo "✔ actions-runner installed"
	else
		echo "✗ actions-runner not found"
	fi
done
exit $errors
