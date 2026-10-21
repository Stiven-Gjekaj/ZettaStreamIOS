<div align="center">

<img src="assets/brand/icon-full.svg" alt="ZettaStream" width="160">

### Anime, movies, series, and live TV in one app for your iPhone and iPad

_Plays your Stremio addons and IPTV playlists_

<p align="center">
  <img src="https://img.shields.io/badge/iOS-16%2B-000000?style=for-the-badge&logo=apple&logoColor=white" alt="iOS 16 or newer"/>
  <img src="https://img.shields.io/badge/Swift-SwiftUI-000000?style=for-the-badge&logo=swift&logoColor=white" alt="Swift and SwiftUI"/>
</p>

<p align="center">
  <a href="https://github.com/Stiven-Gjekaj/ZettaStreamIOS/releases/latest"><img src="https://img.shields.io/github/v/release/Stiven-Gjekaj/ZettaStreamIOS?style=for-the-badge&color=ffffff&labelColor=000000&label=Download" alt="Download the newest release"/></a>
  <a href="https://ko-fi.com/stivengjekaj"><img src="https://img.shields.io/badge/Ko--fi-Support_this_project-000000?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Support this project on Ko-fi"/></a>
</p>

<p align="center">
  <a href="https://github.com/Stiven-Gjekaj/ZettaStreamIOS/actions/workflows/ci.yml"><img src="https://github.com/Stiven-Gjekaj/ZettaStreamIOS/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
  <img src="https://img.shields.io/badge/license-MIT-black?style=flat-square" alt="MIT License"/>
</p>

</div>

---

## Overview

**ZettaStream for iOS** is the iPhone and iPad version of
[ZettaStream](https://github.com/Stiven-Gjekaj/ZettaStream), a stream
aggregator for Android TV and Android phones. It has the same functions. It
shows the catalogs of your Stremio addons as rows of posters, finds the
streams for a title in all your addons at the same time, and plays them. It
also plays IPTV playlists as live TV, with a guide.

The app comes with no sources. You add your own list.

This port is new. The first release is not out yet. See [TODO.md](TODO.md)
for the work that comes next.

## Install

ZettaStream is not in the App Store. Each release has an unsigned
`ZettaStream.ipa`. Sign and install it with one of these tools:

- [AltStore](https://altstore.io) or [SideStore](https://sidestore.io)
- [Sideloadly](https://sideloadly.io)
- [TrollStore](https://github.com/opa334/TrollStore), on a version of iOS
  that it supports

The newest IPA is always at this URL:

```
https://github.com/Stiven-Gjekaj/ZettaStreamIOS/releases/latest/download/ZettaStream.ipa
```

## Add your sources

ZettaStream reads three kinds of line. Put one URL on each line:

| Line | Example | Gives |
| ---- | ------- | ----- |
| A Stremio addon | `https://.../manifest.json` | Catalogs, titles, streams, subtitles |
| An IPTV playlist | `https://.../playlist.m3u` | Live channels |
| A TV guide | `https://.../guide.xml.gz` | What is on now and next |

The order of the lines sets the order of the rows on the home screen.

## Project structure

```
App/            the iOS app: the screens and the player
ZettaCore/      the parts that do not need a screen, with their tests
  Sources/ZettaCore/
    Addon/      the Stremio addon protocol
    Net/        JSON and HTTP helpers
    Source/     the source list
assets/brand/   the icon and the banner, from ZettaStream
docs/           the reason behind each choice
scripts/        the build of the IPA
project.yml     the XcodeGen project
```

## Building

You need Xcode 16 or newer and XcodeGen.

```
brew install xcodegen
git clone https://github.com/Stiven-Gjekaj/ZettaStreamIOS
cd ZettaStreamIOS
./scripts/build-ipa.sh
```

The IPA is in `build/`. To work in Xcode, run `xcodegen` and open
`ZettaStream.xcodeproj`.

A tag such as `v0.1.0` makes the workflow build the IPA and attach it to a
release.

## Testing

```
swift test --package-path ZettaCore
```

The unit tests cover the source list, the addon manifest, the addon URLs, the
addon answers, and the addon client. The tests of the addon client use a
local stub, not a real addon. The workflow runs the tests and builds the IPA
on each push.

## Documentation

- [docs/decisions.md](docs/decisions.md): each choice and its reason
- [CHANGELOG.md](CHANGELOG.md): what changed, and when
- [AGENTS.md](AGENTS.md): the rules for an agent that works here

## A note on rights

ZettaStream is a player. It contains no media and no sources, and the project
does not recommend any. You choose your sources, and you are responsible for
them and for what you watch.

## License

MIT. See [LICENSE](LICENSE).
