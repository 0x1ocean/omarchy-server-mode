# Changelog

## 0.1.0 - Unreleased

- Rebuilt the original local Server Mode toggle as a namespaced Omarchy plugin.
- Added a service-backed heartbeat lease and timed inhibitor watchdog.
- Added full-server and lid-only protection modes.
- Added native settings for startup, power, battery, notifications, and address preference.
- Added a native control panel with quick durations and connection diagnostics.
- Polished the panel for fractional scaling with a bounded height, visible scrolling, and consistent controls.
- Split the panel into focused Power and Access views with a quieter, more compact visual hierarchy.
- Made left click open the panel and right click toggle Server Mode.
- Restored the server glyph with explicit panel bounds and disabled state-change notifications by default.
- Added LAN, Tailscale, SSH, Sunshine, RustDesk, and WayVNC detection.
- Added CLI JSON output, tests, documentation, and CI.
