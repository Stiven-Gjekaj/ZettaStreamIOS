#!/bin/sh
# Builds an unsigned ZettaStream.ipa in the folder build/.
# A sideload tool, such as AltStore, Sideloadly, or TrollStore, signs it.
set -eu

cd "$(dirname "$0")/.."
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
(cd build/ipa && zip -qry ../ZettaStream.ipa Payload)
echo "build/ZettaStream.ipa"
