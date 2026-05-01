#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="NovaLauncher"
BUNDLE_ID="dev.suho.NovaLauncher"
MIN_SYSTEM_VERSION="26.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
APP_ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

usage() {
  echo "usage: $0 [run|--bundle|--debug|--logs|--telemetry|--verify]" >&2
}

sign_bundle() {
  if [[ -n "${NOVA_CODESIGN_IDENTITY:-}" ]]; then
    codesign_args=(
      --force
      --timestamp
      --options runtime
      --sign "$NOVA_CODESIGN_IDENTITY"
    )

    if [[ -n "${NOVA_CODESIGN_KEYCHAIN:-}" ]]; then
      codesign_args+=(--keychain "$NOVA_CODESIGN_KEYCHAIN")
    fi
  else
    codesign_args=(
      --force
      --sign -
    )
  fi

  codesign "${codesign_args[@]}" "$APP_BUNDLE"
  codesign --verify --strict --verbose=2 "$APP_BUNDLE"
}

build_bundle() {
  swift build
  BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS"
  mkdir -p "$APP_RESOURCES"
  cp "$BUILD_BINARY" "$APP_BINARY"
  cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
  chmod +x "$APP_BINARY"

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Nova Launcher</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  sign_bundle
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    ;;
  --bundle|bundle)
    build_bundle
    ;;
  *)
    usage
    exit 2
    ;;
esac

case "$MODE" in
  run)
    open_app
    ;;
  --bundle|bundle)
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
esac
