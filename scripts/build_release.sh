#!/usr/bin/env bash
# Build the Android release bundle with Dart code obfuscation enabled.
#
# Obfuscation strips identifiable Dart symbol names from the compiled app,
# which is what the Play Console "Obfuscation score" checks for (separate
# from the Java/Kotlin obfuscation R8 already does via minifyEnabled).
#
# --split-debug-info writes the symbol map needed to de-obfuscate stack
# traces later. KEEP THIS DIRECTORY — without it, obfuscated crash reports
# (including ones reported to Sentry) can't be symbolicated. It is not
# committed to git (covered by /build/ in .gitignore); archive it
# separately per release, e.g. by version code.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION_CODE=$(grep '^version:' pubspec.yaml | sed -E 's/.*\+([0-9]+)/\1/')
SYMBOLS_DIR="build/symbols/${VERSION_CODE}"

mkdir -p "$SYMBOLS_DIR"

# API_BASE_URL is optional here: ApiConstants.baseUrl already defaults to
# production in release builds (see lib/core/constants/api_constants.dart).
# Set it explicitly only to point a release build at a non-default backend
# (e.g. staging), e.g. API_BASE_URL=https://staging.example.com ./scripts/build_release.sh
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  ${API_BASE_URL:+--dart-define=API_BASE_URL="$API_BASE_URL"}

echo ""
echo "Build complete. Debug symbols written to: $SYMBOLS_DIR"
echo "Archive this directory somewhere durable (not git) before you discard the build machine."
