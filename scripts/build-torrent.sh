#!/bin/sh
# Builds the torrent engine in Torrent/ into Frameworks/ZettaTorrent.xcframework.
# It needs Go and gomobile. Install gomobile with:
#   go install golang.org/x/mobile/cmd/gomobile@latest && gomobile init
set -eu

cd "$(dirname "$0")/.."
PATH="$PATH:$(go env GOPATH)/bin"
export PATH

mkdir -p Frameworks
rm -rf Frameworks/ZettaTorrent.xcframework
# gomobile reads the package from the folder of the Go module.
cd Torrent
gomobile bind \
  -target ios,iossimulator \
  -iosversion 16.0 \
  -trimpath \
  -ldflags "-s -w" \
  -o ../Frameworks/ZettaTorrent.xcframework \
  .
echo "Frameworks/ZettaTorrent.xcframework"
