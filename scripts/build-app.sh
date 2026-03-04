#!/bin/bash
set -euo pipefail

APP_NAME="Sauro"
CONFIG="${1:-debug}"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME} (${CONFIG})..."

if [ "$CONFIG" = "release" ]; then
    swift build -c release
    BINARY=".build/release/${APP_NAME}"
else
    swift build
    BINARY=".build/arm64-apple-macosx/debug/${APP_NAME}"
fi

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Sauro/Info.plist" "${APP_BUNDLE}/Contents/"

echo "Done: ${APP_BUNDLE}"
echo "Run with: open ${APP_BUNDLE}"
