#!/usr/bin/env bash
# Generate Xcode project for the OpenWebUI iOS application.
# Requires Xcode with Swift Package Manager support.

set -euo pipefail

# Determine repository root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_ROOT/OpenWebUIiOS"

cd "$APP_DIR"

# Use Swift Package Manager to generate the project
swift package generate-xcodeproj

echo "Generated OpenWebUIiOS.xcodeproj inside $APP_DIR"
