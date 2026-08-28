#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
DESKTOP_ROOT=${SCRIPT_DIR:h}
REPO_ROOT=${DESKTOP_ROOT:h}
BUILD_ROOT="$REPO_ROOT/build"
APP="$BUILD_ROOT/Xbox Micro.app"
DMG="$BUILD_ROOT/Xbox-Micro.dmg"
RUNTIME_CACHE="$DESKTOP_ROOT/.build/runtime-cache"
NODE_CHANNEL="${XBOX_MICRO_NODE_CHANNEL:-latest-v22.x}"

command -v swift >/dev/null || { print -u2 "error: Swift toolchain is required"; exit 1; }
command -v curl >/dev/null || { print -u2 "error: curl is required"; exit 1; }

print "[1/8] Building OpenMicro engine"
(cd "$REPO_ROOT" && npm run build)

print "[2/8] Building native Xbox Micro app"
(cd "$DESKTOP_ROOT" && swift build -c release --arch arm64)

print "[3/8] Resolving official Node.js runtime ($NODE_CHANNEL)"
mkdir -p "$RUNTIME_CACHE"
SHASUMS="$RUNTIME_CACHE/SHASUMS256-$NODE_CHANNEL.txt"
curl -fsSL "https://nodejs.org/dist/$NODE_CHANNEL/SHASUMS256.txt" -o "$SHASUMS"
ARCHIVE=$(awk '/node-v.*-darwin-arm64\.tar\.xz$/ { print $2; exit }' "$SHASUMS")
[[ -n "$ARCHIVE" ]] || { print -u2 "error: no darwin-arm64 Node.js archive found"; exit 1; }
EXPECTED=$(awk -v archive="$ARCHIVE" '$2 == archive { print $1 }' "$SHASUMS")
ARCHIVE_PATH="$RUNTIME_CACHE/$ARCHIVE"
if [[ ! -f "$ARCHIVE_PATH" ]]; then
  curl -fL "https://nodejs.org/dist/$NODE_CHANNEL/$ARCHIVE" -o "$ARCHIVE_PATH"
fi
ACTUAL=$(shasum -a 256 "$ARCHIVE_PATH" | awk '{ print $1 }')
[[ "$ACTUAL" == "$EXPECTED" ]] || { print -u2 "error: Node.js checksum mismatch"; exit 1; }
NODE_FOLDER=${ARCHIVE%.tar.xz}
if [[ ! -x "$RUNTIME_CACHE/$NODE_FOLDER/bin/node" ]]; then
  tar -xJf "$ARCHIVE_PATH" -C "$RUNTIME_CACHE"
fi
NODE_ROOT="$RUNTIME_CACHE/$NODE_FOLDER"

print "[4/8] Installing production engine dependencies"
ENGINE_STAGE="$DESKTOP_ROOT/.build/engine-stage"
rm -rf "$ENGINE_STAGE"
mkdir -p "$ENGINE_STAGE"
ditto "$REPO_ROOT/dist" "$ENGINE_STAGE/dist"
cp "$REPO_ROOT/package.json" "$REPO_ROOT/package-lock.json" "$ENGINE_STAGE/"
(cd "$ENGINE_STAGE" && "$NODE_ROOT/bin/node" "$NODE_ROOT/lib/node_modules/npm/bin/npm-cli.js" ci --omit=dev)

print "[5/8] Assembling app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Runtime" "$APP/Contents/Resources/Engine"
cp "$DESKTOP_ROOT/.build/arm64-apple-macosx/release/XboxMicro" "$APP/Contents/MacOS/XboxMicro"
cp "$DESKTOP_ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$NODE_ROOT/bin/node" "$APP/Contents/Resources/Runtime/node"
ditto "$ENGINE_STAGE" "$APP/Contents/Resources/Engine"
chmod +x "$APP/Contents/MacOS/XboxMicro" "$APP/Contents/Resources/Runtime/node"
find "$APP/Contents/Resources/Engine/node_modules" -name spawn-helper -type f -exec chmod +x {} \;

print "[6/8] Creating app icon"
ICON_WORK="$DESKTOP_ROOT/.build/XboxMicro.iconset"
ICON_BASE="$DESKTOP_ROOT/.build/XboxMicro-icon-base.png"
rm -rf "$ICON_WORK"
mkdir -p "$ICON_WORK"
sips -c 720 720 --cropOffset 72 55 "$REPO_ROOT/assets/open-micro-logo.png" --out "$ICON_BASE" >/dev/null
for size in 16 32 128 256 512; do
  sips -z $size $size "$ICON_BASE" --out "$ICON_WORK/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$ICON_BASE" --out "$ICON_WORK/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICON_WORK" -o "$APP/Contents/Resources/XboxMicro.icns"

print "[7/8] Signing app bundle (local ad-hoc signature)"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

print "[8/8] Creating DMG"
DMG_STAGE="$DESKTOP_ROOT/.build/dmg-stage"
rm -rf "$DMG_STAGE" "$DMG"
mkdir -p "$DMG_STAGE"
ditto "$APP" "$DMG_STAGE/Xbox Micro.app"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "Xbox Micro" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG" >/dev/null

print "Built: $APP"
print "Built: $DMG"
