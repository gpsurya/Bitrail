# Bitrail — Design Spec

## Goal

A macOS menu bar app showing live audio quality (codec/quality tier, sample rate, bit
depth), output device (name + wired/Bluetooth), and now-playing app/track — across any
media app, not just Apple Music.

## Architecture

Three independent subsystems feed a shared `PlaybackState` (ObservableObject):

1. **NowPlayingSource** — wraps `mediaremote-adapter` (bridges Apple's private
   `MediaRemote.framework`) for app name, track title/artist, and track-change events.
   Works across Apple Music, Spotify, Safari/Chrome tabs, anything registering with the
   system's Now Playing.
2. **QualityDetector** — Apple-Music-only. Scrapes the unified log (`OSLogStore`) for
   CoreAudio's ALAC decoder lines (`ACAppleLosslessDecoder.cpp ... Input format:`) to
   recover the true source sample rate/bit depth. This is the same private, undocumented
   technique LosslessSwitcher uses — there is no public API for this.
3. **OutputDeviceMonitor** — wraps `SimplyCoreAudio` to track the current output device,
   its transport type (Bluetooth vs. wired, via `kAudioDevicePropertyTransportType`), its
   live nominal sample rate/bit depth, and exposes `forceFormat(sampleRate:bitDepth:)` for
   wired devices only.

## Data flow

```
Track changes (mediaremote-adapter) ──▶ PlaybackState.appName/title/artist
                                             │
Apple Music? ──yes──▶ QualityDetector (log scrape) ──▶ PlaybackState.source*
             ──no───▶ (skip; live device format shown instead)
                                             │
OutputDeviceMonitor (polling) ──▶ PlaybackState.deviceName/transport/live*
                                             │
                  Apple Music + wired + autoSwitchEnabled
                                             │
                                             ▼
                          OutputDeviceMonitor.forceFormat(...)
```

## Quality tier classification

Given `(sampleRate, bitDepth, sourceIsLossless)`:
- not lossless → `.lossy`
- lossless, sampleRate ≤ 48kHz → `.lossless`
- lossless, sampleRate > 48kHz → `.hiRes` ("Hi-Res Lossless")

Pure function, unit tested in `Tests/BitrailTests/QualityTierTests.swift`.

## Status bar & menu

- Status bar text: transport glyph + tier + rate/bit-depth when Apple Music with detected
  source quality; otherwise transport glyph + app name + live device format.
- Dropdown menu: app name, track/artist, device name + transport, and (wired only) an
  "Auto-match sample rate" toggle.

## Auto-switch (wired only)

On Apple Music track change with the toggle enabled, finds the nearest supported physical
format on the wired device and sets it — same approach as LosslessSwitcher's
`switchLatestSampleRate`. Bluetooth devices negotiate a fixed codec/rate at connection
time; the toggle is hidden/disabled for them.

## Error handling

- Log scraping timeout/failure → falls back to live device format display.
- No output device, or device changes mid-detection → state simply reflects whatever
  `SimplyCoreAudio` currently reports; no crash paths.
- No now-playing info → status bar falls back to device name/format only.

## Testing

- Unit: `QualityTier.classify` (pure, portable, no hardware needed).
- Manual (needs real hardware): wired DAC + Apple Music Hi-Res track, wired DAC + Spotify,
  Bluetooth headphones + Apple Music, Bluetooth + Spotify, nothing playing.

## Known limitations

- Log-scraping technique is private/undocumented; may break on future macOS releases.
- Bluetooth codec/rate cannot be forced — display only for Bluetooth.
- Quality tier is only ever known for Apple Music; other apps show device output format,
  which reflects what's currently leaving the Mac, not necessarily the source file quality.
