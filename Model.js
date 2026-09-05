.pragma library

function parseObject(raw, fallback) {
  try {
    var value = JSON.parse(String(raw || ""))
    if (value && typeof value === "object" && !Array.isArray(value)) return value
  } catch (e) {
  }
  return fallback || {}
}

function normalizedScope(value) {
  var text = String(value || "").toLowerCase()
  if (text === "lid" || text.indexOf("lid") !== -1) return "lid"
  return "full"
}

function parseDiagnostics(raw) {
  var text = String(raw || "")
  if (text.length > 4096) return {}
  var value = parseObject(text, {})
  return typeof value.hostname === "string" ? value : {}
}

function scopeLabel(scope) {
  return normalizedScope(scope) === "lid" ? "Lid only" : "Full server"
}

function clampInteger(value, fallback, min, max) {
  var parsed = Math.round(Number(value))
  if (!isFinite(parsed)) parsed = fallback
  return Math.max(min, Math.min(max, parsed))
}

function durationMinutes(value) {
  return clampInteger(value, 0, 0, 10080)
}

function refreshSeconds(value) {
  return clampInteger(value, 10, 5, 60)
}

function batteryCutoff(value) {
  return clampInteger(value, 15, 0, 95)
}

function durationLabel(minutes) {
  var value = durationMinutes(minutes)
  if (value === 0) return "Until logout"
  if (value < 60) return value + " min"
  if (value % 60 === 0) return (value / 60) + " h"
  return Math.floor(value / 60) + " h " + (value % 60) + " min"
}

function remainingLabel(seconds) {
  var value = Math.max(0, Math.floor(Number(seconds) || 0))
  if (value === 0) return "Until logout"
  if (value < 60) return "< 1 min"
  var minutes = Math.ceil(value / 60)
  return durationLabel(minutes) + " left"
}

function reasonLabel(reason) {
  var labels = {
    "active": "Active",
    "manual": "Turned off manually",
    "duration-expired": "Duration expired",
    "lease-expired": "Shell lease expired",
    "start-failed": "Could not start",
    "low-battery": "Stopped at low battery",
    "switched-to-battery": "Stopped after unplugging",
    "never-started": "Not started yet"
  }
  return labels[String(reason || "")] || String(reason || "Unknown")
}

function preferredAddress(diagnostics, preference) {
  var data = diagnostics || {}
  var tailscale = data.tailscale || {}
  var choice = String(preference || "Automatic")
  var tailscaleAddress = tailscale.active === true ? (tailscale.ip || tailscale.name || "") : ""
  if (choice === "Tailscale") return tailscaleAddress
  if (choice === "LAN") return data.lanIp || ""
  if (choice === "Hostname") return data.hostname || ""
  return tailscaleAddress || data.lanIp || data.hostname || ""
}

function sshCommand(diagnostics, preference) {
  var data = diagnostics || {}
  var ssh = data.ssh || {}
  var address = preferredAddress(data, preference)
  if (!address) return ""
  var command = "ssh "
  if (Number(ssh.port || 22) !== 22) command += "-p " + Number(ssh.port) + " "
  return command + String(data.user || "user") + "@" + address
}

function providerLabel(provider) {
  var value = provider || {}
  if (value.active === true) return "Running"
  if (value.installed === true) return "Installed"
  return "Not installed"
}

function hasRemoteDesktop(diagnostics) {
  var providers = (diagnostics || {}).remoteDesktop || {}
  return [providers.sunshine, providers.rustdesk, providers.wayvnc].some(function(provider) {
    return provider && provider.installed === true
  })
}

function remoteDesktopSummary(diagnostics) {
  var providers = (diagnostics || {}).remoteDesktop || {}
  var items = [
    { name: "Sunshine", value: providers.sunshine },
    { name: "RustDesk", value: providers.rustdesk },
    { name: "WayVNC", value: providers.wayvnc }
  ]
  var installed = []
  for (var i = 0; i < items.length; i++) {
    if (items[i].value && items[i].value.active === true)
      return items[i].name + " running"
    if (items[i].value && items[i].value.installed === true)
      installed.push(items[i].name)
  }
  return installed.length > 0 ? installed.join(", ") : "Not configured"
}

function connectionSummary(diagnostics) {
  var data = diagnostics || {}
  var tailscale = data.tailscale || {}
  var ssh = data.ssh || {}
  if (tailscale.active === true && ssh.active === true) return "Tailscale + SSH ready"
  if (ssh.active === true) return "SSH ready on LAN"
  if (tailscale.active === true) return "Tailscale connected"
  return "Remote access needs setup"
}

if (typeof module !== "undefined") {
  module.exports = {
    parseObject: parseObject,
    parseDiagnostics: parseDiagnostics,
    normalizedScope: normalizedScope,
    scopeLabel: scopeLabel,
    durationMinutes: durationMinutes,
    refreshSeconds: refreshSeconds,
    batteryCutoff: batteryCutoff,
    durationLabel: durationLabel,
    remainingLabel: remainingLabel,
    reasonLabel: reasonLabel,
    preferredAddress: preferredAddress,
    sshCommand: sshCommand,
    providerLabel: providerLabel,
    hasRemoteDesktop: hasRemoteDesktop,
    remoteDesktopSummary: remoteDesktopSummary,
    connectionSummary: connectionSummary
  }
}
