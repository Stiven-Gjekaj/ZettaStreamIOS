# ZettaStream brand assets

This folder holds the app icon, the banner, and the wordmark. They come from ZettaStream for Android.

## Design

The mark is a bold geometric Z. The mark carries a gradient from white to grey. The gradient shows the flow of a stream. The background is the dark app colour with a soft grey glow.

## Colours

| Name | Hex | Use |
| --- | --- | --- |
| Background | `#000000` | Icon and banner background. Same as the app background. |
| Glow | `#2a2a2a` | Centre of the radial glow behind the mark. |
| White | `#ffffff` | Start of the mark gradient. |
| Grey | `#e0e0e0` | Middle of the mark gradient. Monochrome icon colour. |
| Dark grey | `#9a9a9a` | End of the mark gradient. |

## SVG sources

| File | Use |
| --- | --- |
| `icon-foreground.svg` | Adaptive icon foreground layer. 108x108 viewBox. The mark stays inside the central 66x66 safe zone. |
| `icon-background.svg` | Adaptive icon background layer. 108x108 viewBox. |
| `icon-monochrome.svg` | Monochrome layer for Android 13 themed icons. Same geometry as the foreground. |
| `icon-ios.svg` | The iOS app icon. It is square, with no clip, because iOS rounds the corners itself. `App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png` is its render at 1024x1024. |
| `icon-full.svg` | The complete square icon with rounded corners. Use it for previews and the README. |
| `banner.svg` | Android TV launcher banner. 16:9, 320x180 viewBox. The Z is in the center, on a grey glow. |
| `wordmark.svg` | The mark and the name side by side on a transparent background. It is light, so use it on a dark background only. |

## PNG renders

| File | Size | Use |
| --- | --- | --- |
| `banner-xhdpi.png` | 320x180 | The Android TV banner. Here, a header image for the AltStore source. |
| `banner-xxhdpi.png` | 480x270 | The same banner at a larger size. |
| `icon-512.png` | 512x512 | Previews and the release page. |

## How to render again

Use `rsvg-convert` from the SVG sources. Example:

    rsvg-convert -w 320 -h 180 banner.svg -o banner-xhdpi.png
    rsvg-convert -w 1024 -h 1024 -b '#000000' icon-ios.svg -o ../../App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png

## Font

The wordmark uses Inter Bold, converted to paths. Inter has the SIL Open Font License. No font file is needed at build time or at run time.
