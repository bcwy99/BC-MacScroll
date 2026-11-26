#!/usr/bin/env bash
# Builds "build/BC MacScroll.app" from source.
#
#   scripts/build-app.sh                 # native architecture, ad-hoc signed
#   UNIVERSAL=1 scripts/build-app.sh     # arm64 + x86_64 (needs full Xcode)
#   SIGN_IDENTITY="Developer ID Application: ..." scripts/build-app.sh
#
# Works with just the Xcode Command Line Tools; no Xcode project needed.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="BC MacScroll"
EXECUTABLE="BCMacScroll"
VERSION="${VERSION:-$(cat VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="build/${APP_NAME}.app"

if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
else
  ARCH_FLAGS=()
fi

echo "==> Compiling ${EXECUTABLE} ${VERSION} (${BUILD_NUMBER})"
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/${VERSION}/" -e "s/__BUILD__/${BUILD_NUMBER}/" Resources/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (${SIGN_IDENTITY})"
codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"

echo "==> Done: $APP"
lipo -info "$APP/Contents/MacOS/$EXECUTABLE"
