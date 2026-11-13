#!/bin/bash
# Builds IconScape.app for macOS 11 or later (one universal binary for Apple silicon and Intel) from mac/Sources and the shared pages in prototype/.
# Needs the Xcode command line tools (xcode-select --install). Run from anywhere:
#   bash mac/build.sh          → mac/build/IconScape.app
#   bash mac/build.sh --dmg    → also dist/IconScape-<version>-mac.dmg and its SHA256
# The app is signed ad hoc (no Apple developer certificate): on another Mac, open it the first time with right click → Open.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' tools/version.json)
[ -n "$VERSION" ] || { echo "No version in tools/version.json" >&2; exit 1; }
OUT="$ROOT/mac/build"
APP="$OUT/IconScape.app"
echo "IconScape $VERSION for macOS"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Program: one slice per architecture, joined into a universal binary
BINS=()
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$ARCH-apple-macos11.0" -module-name IconScape \
    -framework AppKit -framework WebKit \
    "$ROOT"/mac/Sources/*.swift -o "$OUT/IconScape-$ARCH"
  BINS+=("$OUT/IconScape-$ARCH")
done
lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/IconScape"
rm -f "${BINS[@]}"

sed "s/@VERSION@/$VERSION/g" mac/Info.plist.in > "$APP/Contents/Info.plist"

# Shared pages: the same files the Windows host shows (the Node development server is left out)
ditto prototype "$APP/Contents/Resources/prototype"
rm -f "$APP/Contents/Resources/prototype/serve.mjs"
cp LICENSE NOTICE TRADEMARKS.md THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"

# Icon: mac/AppIcon-1024.png (drawn by tools/make-icon.ps1 -MacPng) → AppIcon.icns
ICONSET="$OUT/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for S in 16 32 128 256 512; do
  sips -z $S $S mac/AppIcon-1024.png --out "$ICONSET/icon_${S}x${S}.png" >/dev/null
  sips -z $((S * 2)) $((S * 2)) mac/AppIcon-1024.png --out "$ICONSET/icon_${S}x${S}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# The question macOS asks before IconScape may read the icon positions from Finder, in the interface languages
plist_strings() { mkdir -p "$APP/Contents/Resources/$1.lproj"; printf '"NSAppleEventsUsageDescription" = "%s";\n' "$2" > "$APP/Contents/Resources/$1.lproj/InfoPlist.strings"; }
plist_strings en "IconScape reads where the desktop icons are, so the landscape can take shape around them."
plist_strings it "IconScape legge dove si trovano le icone della scrivania, così il paesaggio può prendere forma intorno a loro."
plist_strings es "IconScape lee dónde están los iconos del escritorio para que el paisaje tome forma a su alrededor."
plist_strings fr "IconScape lit l'emplacement des icônes du bureau pour que le paysage prenne forme autour d'elles."
plist_strings de "IconScape liest, wo die Schreibtischsymbole liegen, damit die Landschaft um sie herum entsteht."
plist_strings zh-Hans "IconScape 会读取桌面图标的位置，让风景围绕它们展开。"

codesign --force --deep --sign - "$APP"
echo "Built: $APP"

if [ "${1:-}" = "--dmg" ]; then
  mkdir -p "$ROOT/dist"
  STAGE="$OUT/dmg"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  ditto "$APP" "$STAGE/IconScape.app"
  ln -s /Applications "$STAGE/Applications"
  DMG="$ROOT/dist/IconScape-$VERSION-mac.dmg"
  rm -f "$DMG"
  hdiutil create -volname "IconScape $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  (cd "$ROOT/dist" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
  echo "Disk image: $DMG"
fi
