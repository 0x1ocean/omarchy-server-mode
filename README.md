# Server Mode for Omarchy

Server Mode keeps an Omarchy computer available for remote work and shows the
connection information you need to reach it. It works on laptops and desktops,
does not require root for its core power protection, and never opens a port or
changes SSH configuration on its own.

> This is an early development release. Remote-screen provider control and a
> tested Hyprland headless-display workflow are planned for a later milestone.

## Features

- Full-server or lid-only sleep inhibition.
- Session-long or timed protection.
- Heartbeat lease that releases the inhibitor after the plugin is disabled,
  removed, or stops running.
- Optional start-on-login and start-on-AC policies.
- Optional stop-on-battery and low-battery protection.
- LAN, hostname, Tailscale, and SSH readiness in a native Omarchy panel.
- Detection for Sunshine, RustDesk, and WayVNC.
- Copyable preferred address and SSH command.
- Native Omarchy settings and theme-aware UI.

## Install

Once the repository is published:

```bash
omarchy plugin add https://github.com/0x1ocean/omarchy-server-mode.git --enable
```

Server Mode appears in the right side of the Omarchy bar.

- Left click toggles the configured default mode.
- Right click opens the control panel.
- `R` refreshes connection diagnostics while the panel is focused.
- `S` copies the generated SSH command.

## Power protection

`Full server` blocks both regular sleep requests and lid-close handling.
`Lid only` blocks only the low-level lid switch, so manual suspend continues to
work.

The plugin renews a short runtime lease while it is loaded. If the shell exits,
the plugin is disabled, or its files are removed, the inhibitor expires after
at most about one minute. This avoids leaving a hidden stay-awake process behind.

The lock screen remains independent. Server Mode does not disable authentication
or unlock the session.

## CLI

The helper can be run directly from the installed plugin directory:

```bash
./server-mode on --scope full --duration-minutes 120
./server-mode on --scope lid --duration-minutes 0
./server-mode renew
./server-mode status --json
./server-mode diagnostics --json
./server-mode off
```

The normal bar service renews the lease. Running `on` while the plugin is not
loaded is intentionally temporary and expires when no heartbeat arrives.

## Remote access

Server Mode only reports existing services in this release:

- Tailscale address and MagicDNS name, when connected.
- OpenSSH server installation, service state, port, and a connection command.
- Sunshine, RustDesk, and WayVNC installation and process state.

It does **not** install packages, enable `sshd`, edit `sshd_config`, change the
firewall, create users, or enable password authentication. Configure remote
access yourself and prefer SSH keys plus a trusted private network such as
Tailscale.

## Dependencies

Core dependencies already present on Omarchy:

- Bash
- systemd (`systemctl`, `systemd-run`, and `systemd-inhibit`)
- `jq`
- `iproute2`
- `coreutils`
- `procps-ng`
- `wl-clipboard`

Optional integrations are detected only when installed: Tailscale, OpenSSH,
Sunshine, RustDesk, and WayVNC.

## Validate

```bash
omarchy plugin validate .
bash -n server-mode
shellcheck server-mode
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml
node tests/model.test.js
bash tests/helper.test.sh
```

## Remove

```bash
omarchy plugin remove io.github.0x1ocean.server-mode
```

The heartbeat lease stops being renewed before Omarchy removes the checkout.
Any active inhibitor then exits automatically within its lease window. You can
also turn Server Mode off first for immediate cleanup.

## Safety

A laptop may rely on an open lid for cooling. Check the manufacturer's thermal
guidance before running sustained workloads with the lid closed. The optional
low-battery cutoff is not a substitute for hardware thermal protection.

See [SECURITY.md](SECURITY.md) for privilege and trust boundaries.

## License

MIT
