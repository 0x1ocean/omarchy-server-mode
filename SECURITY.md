# Security

## Trust boundary

Omarchy plugins run unsandboxed with the current user's permissions. Review the
source before enabling this plugin or any update.

Remote Server Mode's core does not require root. It starts one transient user-systemd
unit whose only purpose is to hold a systemd inhibitor while a bounded heartbeat
lease is valid.

## What Remote Server Mode does not do

- It does not edit files under `/etc`.
- It does not install packages or download executable code.
- It does not open firewall ports.
- It does not enable or reconfigure SSH.
- It does not store credentials, tokens, passwords, or private keys.
- It does not expose a public Internet address.

Diagnostics read the local hostname, global IPv4 addresses, Tailscale status,
systemd's SSH service state, and the presence of supported remote-screen
processes. Results stay in memory inside the Omarchy shell.

## Lifecycle guarantee

The inhibitor requires a heartbeat from the loaded plugin. The default lease is
45 seconds and is renewed every 10 seconds. If the plugin disappears or the
shell cannot renew it, the watchdog releases the inhibitor automatically.

## Reporting

Please open a private security advisory in the GitHub repository for security
issues. Do not put credentials or private network details in a public issue.
