<div align="center">
  <a href="README.md"><img src="assets/brand/icon-full.svg" alt="ZettaStream" height="44"></a>
</div>

# Changelog

Every release is written here, newest first. A version is `MAJOR.MINOR.PATCH`.
From 1.0.0, a fix raises the patch number, a new function raises the minor
number, and a change that breaks the backup or the source list raises the
major number. See "Version numbers" in the decisions.

A tag such as `v0.1.0` builds the unsigned IPA and attaches it to a release on
GitHub as `ZettaStream.ipa`.

## 1.0.0 (2026-10-21)

- Starts faster. The addons and the rows of Home come from the disk at once,
  and then the addons refresh them.
- Works with no network: an addon that does not answer uses its manifest from
  the disk, and Home shows its last rows.
- Tries the failed addons and playlists again when the network comes back.
- An HLS stream gets more tries, and a lower quality for one minute after
  faults, as on Android.
- A torrent that shows no picture in 120 seconds gives its place to the next
  stream.
- A torrent stops when the device is almost full, and its data goes.
- The anime pictures of a profile come in about 6 seconds, not 33.
- The text follows Dynamic Type, and VoiceOver says the name of a profile one
  time.
- The keys of a keyboard work in the player also after a tap on the video.
- The text for torrent peers does not cover the buttons of the player.
- The IPA is 1.6 MB smaller, and the installed app 9.7 MB smaller.
- The backup works in both directions with the Android app 1.5.1.

## 0.1.3 (2026-10-21)

- Adds voice search. The microphone button in the search field listens for a
  title.
- A keyboard or a game controller controls the player, with the keys of the
  remote control of the Android app. Command and 1 to 5 open the tabs.
- Keeps a playlist for one hour and a guide for six hours, so that Live TV
  opens faster.
- Reads a large TV guide with much less memory.

## 0.1.2 (2026-10-21)

- Finds the streams of a new anime that has only a MyAnimeList ID, such as
  the new titles in the AnimeStream catalogs. The app gets the Kitsu ID of the
  anime and asks the addons that read Kitsu IDs.
- Shows the anime profile pictures again. AniList has disabled its API, so the
  pictures come from Shikimori when AniList gives none.

## 0.1.1 (2026-10-21)

- Fixes the install of a long source list. Only one addon worked, and the
  other addons seemed to hang. A fault of the optimizer put the answer of
  each addon in the same place. The search, the subtitles, and the live TV
  playlists had the same fault.
- Save and Paste stay near the editor of a long source list.

## 0.1.0 (2026-10-21)

- The first version of ZettaStream for iPhone and iPad, with the functions of
  ZettaStream for Android 1.5.1.
- "Who is watching?" profiles, each with a picture, a library, and settings.
- Home with a banner, filters for each kind, Continue watching, the
  watchlist, New episodes, and the rows of each addon. Each row can be off,
  and the order can change.
- A title page with seasons, episodes, the cast, the trailer, an About table,
  and "More like this". "Explore more" opens all the titles of a row.
- Streams from all addons at the same time, with badges. Play starts the best
  stream, and the next one starts when a stream fails or shows no picture in
  45 seconds.
- Torrent streams through anacrolix/torrent, with no seeding and an upload of
  4 KB/s.
- The VLC player: subtitle and audio tracks, delays, the subtitle look, side
  bars, video filters, skip times from AniSkip, the next episode countdown,
  and Picture in Picture.
- Search in all addons, the library, and live TV with a guide.
- Sources with the system paste button, back up and restore in the form of
  the Android backup, and a check for a newer version.
