<div align="center">
  <a href="../README.md"><img src="../assets/brand/icon-full.svg" alt="ZettaStream" height="44"></a>
</div>

# Decisions

Each choice of the owner is written here, with its reason. A new choice that
replaces an old one names the old one. The Android app has its own list in
[ZettaStream/docs/decisions.md](https://github.com/Stiven-Gjekaj/ZettaStream/blob/main/docs/decisions.md).
A choice there applies here too, if this list does not replace it.

## 2026-10-21: An iOS port of ZettaStream

- ZettaStream for iOS has the same functions as ZettaStream for Android.
- It operates on iPhone and iPad. Apple TV can come later.
- The lowest version is iOS 16.
- Reason: the owner asked for the app on iOS, with the same functions.

## 2026-10-21: Native Swift, with a core package

- The app is native Swift with SwiftUI.
- XcodeGen makes the Xcode project from `project.yml`. The generated project
  is not in the repository.
- The parts that do not need a screen are in the Swift package `ZettaCore`.
  They build and test on a Mac with `swift test`, with no simulator.
- Reason: the tests run in seconds. A text file is easier to examine in a
  commit than a generated project file.

## 2026-10-21: An unsigned IPA for sideloading

- The app is not in the App Store.
- A tag such as `v0.1.0` builds an unsigned `ZettaStream.ipa` and attaches it
  to a release on GitHub.
- The user signs and installs it with AltStore, SideStore, Sideloadly, or
  TrollStore.
- Reason: Apple does not permit a stream aggregator with torrents in the App
  Store. An unsigned IPA needs no paid developer account.

## 2026-10-21: Version numbers

- The versions start at 0.1.0, as the Android app did.
- From 1.0.0, a fix raises the patch number, a new function raises the minor
  number, and a change that an older version cannot read raises the major
  number.
- Reason: the same rules as the Android app. The iOS versions do not follow
  the Android numbers, because the two apps do not have the same state.

## 2026-10-21: The player

- The player is VLCKit 4, from the package of VideoLAN.
- Reason: most addon streams are MKV files. The player of Apple, AVPlayer,
  does not play MKV, and it does not play many audio codecs.

## 2026-10-21: The torrent engine

- The torrent engine is anacrolix/torrent, a Go library. gomobile builds it
  into a framework for iOS.
- The engine serves the chosen file to the player on `127.0.0.1`, with HTTP
  range requests, so that playback starts before the download is complete.
- The rules of the Android app stay: the upload is limited to 4 KB/s, the app
  does not seed, and the app deletes the torrent when the player closes.
- Reason: the library has a reader for a stream that reads ahead and seeks.
  The Go HTTP server gives range requests with no extra code. Mangayomi, a
  sideloaded iOS app, uses the same library in the same way. libtorrent for
  iOS needs Boost and OpenSSL, and the Swift packages for it are new and have
  few users.

## 2026-10-21: The same backup as Android

- The backup file has the same form as the backup of the Android app.
- Reason: a user can move the library and the settings from an Android phone
  to an iPhone.

## 2026-10-21: Functions of Android that iOS cannot have

- These functions are not in the iOS app:
  - The Downloader code. iOS cannot install an IPA from a code.
  - The Play next row of the Android TV home screen.
  - A switch of the frame rate of the screen.
  - The install of an update from inside the app. The app tells the user that
    a newer version is available, and gives the link.
- Reason: iOS does not permit these functions.

## 2026-10-21: No QR pairing on iOS

- The Sources screen has a text editor and a Paste button.
- There is no QR pairing page and no diagnostics page for a TV.
- Reason: on Android, the QR code lets a phone send the list to a TV. An
  iPhone and an iPad have a keyboard and a clipboard, as the Android phone
  layout does.

## 2026-10-21: The headers of a stream in VLC

- The player sends the User-Agent, the Referer, and the Cookie headers that an
  addon gives for a stream.
- It does not send other headers.
- Reason: VLC has options for these three headers only.

## 2026-10-21: The colours of the video filters

- The scanlines, the dark corners, the grain, and the round tube edge are
  drawn over the video, with the values of the Android app.
- The colour change of VHS, Vintage film, and Black and white uses the
  `adjust` filter of VLC: saturation, contrast, brightness, hue, and gamma.
  The values come nearest to the colour matrices of the Android app.
- The warm tint of VHS and Vintage film is a colour that is multiplied over
  the video.
- Reason: VLC has no colour matrix filter, and the adjust filter cannot tint a
  grey.

## 2026-10-21: A change of the subtitle look restarts the video

- A change of the subtitle size, colour, background, font, or edge starts
  the video again at the same position, 0.8 seconds after the last change.
- Reason: VLC reads the look of the subtitles only when a player starts.

## 2026-10-21: Touch actions in the place of the colour buttons

- A long press on a card gives the watchlist and the watched mark.
- A long press on a channel adds it to the favourites, or removes it.
- Filter chips on Home take the place of the Blue button.
- A tap on a Continue watching card plays the video from the saved position.
  "Details" is in its long press menu.
- Reason: an iPhone and an iPad have no remote control.

## 2026-10-21: The file protection of the data

- The files of the app use the default file protection of iOS.
- Reason: the player can play in the background and in Picture in Picture
  while the device is locked. Complete protection stops the app from reading
  its files then.
