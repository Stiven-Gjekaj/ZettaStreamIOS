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

## Features

- Rows of posters from the catalogs of each addon, with a banner of featured
  titles and filters for each kind
- Streams from all addons at the same time, with badges for quality, HDR,
  and dual audio, and torrents sorted by seeders
- Torrent streams, played while they download, with no seeding after
- Play starts the best 1080p stream at once, and shows which source plays.
  When a stream fails, the next best one starts
- Seasons and episodes, with the next episode to watch, and a countdown to
  the next episode from the same source and quality
- Continue watching, a watchlist, and watched marks, on the device only
- Subtitles from the stream, from subtitle addons, and from OpenSubtitles
- Subtitle and audio tracks, a subtitle delay, and an audio delay
- Skip the intro of an anime episode at the exact second, from AniSkip
- Side bars of a 4:3 video filled with an ambient blur, black, or a stretch
- Video filters: CRT, VHS, vintage film, and black and white
- Profiles, each with a picture, a history, a watchlist, and settings
- A "New episodes" row, a trailer, the cast, and "More like this"
- "Explore more" at the end of each row opens all of its titles in a grid
- Live TV from M3U playlists, with now and next from an XMLTV guide,
  favourite channels, and a guide grid
- Picture in Picture and playback in the background
- Back up and restore the library, the settings, and the sources. The file
  has the same form as the backup of the Android app
- The app tells you when a newer version is available

## Install

ZettaStream is not in the App Store.

**With SideStore or AltStore:** add this source one time. The app then gets
each update from it.

```
https://stiven-gjekaj.github.io/sidestore-source/apps.json
```

**By hand:** each release has an unsigned `ZettaStream.ipa`. Sign and install
it with one of these tools:

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
App/Sources/
  Model/        the app model and the objects that live as long as the app
  Navigation/   the tabs and the routes
  Screens/      the screens
  Player/       the VLCKit player, its controls, and its options
  Torrent/      the Swift side of the torrent engine
ZettaCore/      the parts that do not need a screen, with their tests
  Sources/ZettaCore/
    Addon/      the Stremio addon protocol, the home rows, and search
    Streams/    the facts, the order, and the health of the streams
    IPTV/       M3U playlists and XMLTV guides
    Library/    the watchlist, the history, and the backup
    Profile/    the profiles and their pictures
    Settings/   the viewer settings
    Player/     the rules of the player and the video filters
    Skip/       the skip times of anime episodes
    Source/     the source list
Torrent/        the Go torrent engine, on anacrolix/torrent
assets/brand/   the icon and the banner, from ZettaStream
docs/           the reason behind each choice
scripts/        the builds of the torrent engine and of the IPA
project.yml     the XcodeGen project
```

## Building

You need Xcode 16 or newer, XcodeGen, Go, and gomobile.

```
brew install xcodegen go
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
git clone https://github.com/Stiven-Gjekaj/ZettaStreamIOS
cd ZettaStreamIOS
./scripts/build-ipa.sh
```

The script builds the torrent engine into `Frameworks/` when it is missing or
older than the Go code. The first build also downloads VLCKit, which is about
900 MB. The IPA is in `build/`. To work in Xcode, run `xcodegen` and open
`ZettaStream.xcodeproj`.

A tag such as `v0.1.0` makes the workflow build the IPA and attach it to a
release.

## Testing

```
swift test --package-path ZettaCore
(cd Torrent && go test ./...)
```

The unit tests of the core package cover the addon protocol, the home rows,
search, the streams, the playlists and the guides, the library, the backup,
the profiles, the settings, the skip times, and the rules of the player. The
tests of the HTTP clients use a local stub, not a real addon. The tests of
the torrent engine seed a torrent from a second client on `127.0.0.1`, with
no network. The workflow runs both and builds the IPA on each push.

## Documentation

- [docs/decisions.md](docs/decisions.md): each choice and its reason
- [CHANGELOG.md](CHANGELOG.md): what changed, and when
- [AGENTS.md](AGENTS.md): the rules for an agent that works here

## A note on rights

ZettaStream is a player. It contains no media and no sources, and the project
does not recommend any. You choose your sources, and you are responsible for
them and for what you watch.

## Profile pictures

The pictures of anime characters come from [AniList](https://anilist.co).
The pictures of TV characters and actors come from
[TVmaze](https://www.tvmaze.com), under CC BY-SA. The app asks these services
only when you choose a picture. The rights to each picture stay with their
owners.

## License

MIT. See [LICENSE](LICENSE). Karla is under the SIL Open Font License, in
[licenses/](licenses/Karla-OFL.txt). VLCKit is under the LGPL 2.1, and
anacrolix/torrent is under the MPL 2.0.
