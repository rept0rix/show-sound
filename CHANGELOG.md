# Changelog

All notable changes to **Show Sound** will be documented in this file.

## [1.0.0] - 2026-09-29

### Added
- **GainGuard Audio DSP Engine:**
  - True-peak lookahead limiter clamping output to -0.3 dBFS to eliminate digital clipping.
  - Sub-bass 55Hz High-Pass Filter protecting MacBook and portable speakers against voice coil burnout.
  - Dynamic Range Compression (DRC) boosting whisper and dialogue clarity without distortion.
  - Automatic Ear Safety Clamp for loud transients and ads.
- **Per-App Audio Mixer:**
  - Independent volume faders for running macOS applications (Spotify, Safari, WhatsApp, Zoom, etc.).
  - Individual mute and gain controls.
- **Stereo Spatial Panning:**
  - Left / Right channel positioning per stream (e.g. Call on the Left, Music on the Right).
- **Call Music Streamer (Loopback Injection):**
  - Seamlessly inject background music directly into call microphone streams.
  - Intelligent Voice Activity Ducking (automatically lowers music by -18dB while speaking).
- **Acoustic Presets & 10-Band EQ:**
  - Vocal Clarity, Night Mode (Dialogue Boost), Safe Bass, and Cinema profiles.
- **Modern Menu Bar UI:**
  - Glassmorphic macOS menu bar popover with real-time VU peak metering.
