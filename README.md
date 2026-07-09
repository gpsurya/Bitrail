# Bitrail

A macOS menu bar app that shows what's actually leaving your Mac's audio output right now:
quality tier (Lossless / Hi-Res Lossless), sample rate, bit depth, output device name,
wired vs. Bluetooth, and the app/track currently playing — across Apple Music, Spotify,
browsers, or anything else that reports "now playing" info to macOS.

Inspired by [LosslessSwitcher](https://github.com/vincentneo/LosslessSwitcher), which
pioneered the (private, undocumented) technique of reading CoreAudio's decoder logs to
detect Apple Music's true sample rate/bit depth, since Apple provides no public API for this.

## What it does

- **Now playing**: app name, track title/artist for any app using the system's Now Playing
  info (via [mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter)).
- **Quality tier** (Apple Music only): Lossless / Hi-Res Lossless, derived from the source
  sample rate + bit depth recovered via unified-log scraping — the only way to get this data,
  since it isn't exposed by any public API.
- **Device output format**: for non-Apple-Music sources, shows what your output device is
  currently physically outputting (via [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio)),
  since we can't detect per-app source quality for apps that don't log it.
- **Wired vs. Bluetooth**: detected from the device's CoreAudio transport type.
- **Auto-match sample rate (wired only)**: optionally forces the output device's physical
  format to match the detected Apple Music source format. Bluetooth devices negotiate a
  fixed codec/rate at connection time and cannot be forced this way — the toggle is only
  shown for wired devices.

## Requirements

- macOS 13+
- The app cannot be sandboxed (log scraping + CoreAudio device control require this).
- Full Xcode (not just Command Line Tools) to build/run/test, since it's a GUI app using XCTest.

## Building

```
swift build
swift run
```

Or open `Package.swift` in Xcode and run.

## Architecture

See [`docs/design.md`](docs/design.md) for the full design spec.

## Disclaimer

Sample rate/bit depth detection relies on scraping macOS's private, undocumented log output.
This may break on future macOS versions without notice. Auto-switching briefly interrupts
audio while the device format changes, same as LosslessSwitcher.
