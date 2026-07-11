#!/usr/bin/env bash
# Vercel "Ignored Build Step": exit 0 = skip, exit 1 = build.
# Runs from the repository root (not docs/).

set -euo pipefail

PATHS=(docs/)

if [ -n "${VERCEL_GIT_PREVIOUS_SHA:-}" ] && [ -n "${VERCEL_GIT_COMMIT_SHA:-}" ]; then
	if git diff --quiet "${VERCEL_GIT_PREVIOUS_SHA}" "${VERCEL_GIT_COMMIT_SHA}" -- "${PATHS[@]}"; then
		echo "No changes under docs/ since last deploy — skipping."
		exit 0
	fi
	echo "docs/ changed since last deploy — building."
	exit 1
fi

# Pull requests and first deploys: compare against parent commit.
if git diff --quiet HEAD^ HEAD -- "${PATHS[@]}"; then
	echo "No changes under docs/ in this commit — skipping."
	exit 0
fi

echo "docs/ changed — building."
exit 1
