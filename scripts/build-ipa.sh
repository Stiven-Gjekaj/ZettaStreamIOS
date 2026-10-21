#!/bin/sh
# Builds an unsigned ZettaStream.ipa in the folder build/.
# A sideload tool, such as AltStore, Sideloadly, or TrollStore, signs it.
set -eu

cd "$(dirname "$0")/.."
# Build the torrent engine when it is missing or older than its Go sources.
engine=Frameworks/ZettaTorrent.xcframework/Info.plist
if [ ! -f "$engine" ] || [ -n "$(find Torrent \( -name '*.go' -o -name go.mod -o -name go.sum \) -newer "$engine")" ]; then
  ./scripts/build-torrent.sh
fi
xcodegen --quiet
xcodebuild \
  -project ZettaStream.xcodeproj \
  -scheme ZettaStream \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/derived \
  -quiet \
  build

rm -rf build/ipa
mkdir -p build/ipa/Payload
cp -R build/derived/Build/Products/Release-iphoneos/ZettaStream.app build/ipa/Payload/
# VLCKit comes with its local symbols. The app does not need them.
for binary in build/ipa/Payload/ZettaStream.app/Frameworks/*.framework/*; do
  if [ -f "$binary" ] && file "$binary" | grep -q "Mach-O"; then
    strip -x "$binary"
  fi
done
(cd build/ipa && zip -qry ../ZettaStream.ipa Payload)
echo "build/ZettaStream.ipa"
