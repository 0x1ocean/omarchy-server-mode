# Changelog

## 1.0.1 - 2026-09-05

- Capped Tailscale status at the producer boundary and reject truncated JSON.
- Reduced Tailscale parsing to one bounded `jq` projection of the required `Self` fields.
- Bounded diagnostic strings and the final response before QML collection.
- Simplified remote-screen provider detection and expanded hostile-input tests.

## 1.0.0 - 2026-09-04

- Released the original local toggle as the public Server Mode plugin.
- Added a service-backed heartbeat lease and timed inhibitor watchdog.
- Added full-server and lid-only protection modes.
- Added native settings for startup, power, battery, notifications, and address preference.
- Added a native control panel with quick durations and connection diagnostics.
- Polished the panel for fractional scaling with a bounded height, visible scrolling, and consistent controls.
- Split the panel into focused Power and Access views with a quieter, more compact visual hierarchy.
- Made left click open the panel and right click toggle Server Mode.
- Restored the original server glyph with explicit panel bounds and disabled state-change notifications by default.
- Fixed stale Tailscale detection and added state coverage for Tailscale, SSH, and remote-screen providers.
- Added LAN, Tailscale, SSH, Sunshine, RustDesk, and WayVNC detection.
- Added CLI JSON output, tests, documentation, and CI.
