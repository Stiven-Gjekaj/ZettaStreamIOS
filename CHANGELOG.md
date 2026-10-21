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
