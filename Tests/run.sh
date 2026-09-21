#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/windowstabnote-checks.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
# Keep checks in the same source file so the app's private types stay private.
cat "$PROJECT_DIR/Sources/main.swift" "$PROJECT_DIR/Tests/BehaviorChecks.swift" > "$CHECK_DIR/main.swift"
swiftc -swift-version 5 -D BEHAVIOR_CHECKS -framework AppKit -framework UniformTypeIdentifiers \
    "$CHECK_DIR/main.swift" -o "$CHECK_DIR/checks"
"$CHECK_DIR/checks"
