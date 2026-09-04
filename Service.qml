import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool configured: false
  property bool statusKnown: false
  property bool initialPolicyApplied: false
  property bool active: false
  property bool busy: false
  property string scope: "full"
  property int started: 0
  property int deadline: 0
  property int remainingSeconds: 0
  property int leaseSeconds: 45
  property string lastReason: "never-started"
  property string lastError: ""
  property var diagnostics: ({})
  property bool previousOnBattery: UPower.onBattery

  readonly property string pluginId: "io.github.0x1ocean.server-mode"
  readonly property string helperPath: Qt.resolvedUrl("server-mode").toString().replace("file://", "")
  readonly property bool batteryPresent: !!(UPower.displayDevice && UPower.displayDevice.isPresent)
  readonly property int batteryPercent: batteryPresent
    ? Math.round(Math.max(0, Math.min(1, UPower.displayDevice.percentage)) * 100)
    : 0
  readonly property bool onBattery: batteryPresent && UPower.onBattery
  readonly property string defaultScope: Model.normalizedScope(setting("defaultScope", "Full server"))
  readonly property int defaultDurationMinutes: Model.durationMinutes(setting("defaultDurationMinutes", 0))
  readonly property bool notificationsEnabled: setting("notifications", true) === true
  readonly property int refreshIntervalMs: Model.refreshSeconds(setting("refreshIntervalSec", 10)) * 1000
  readonly property int lowBatteryCutoff: Model.batteryCutoff(setting("minimumBatteryPercent", 15))
  readonly property string preferredAddress: Model.preferredAddress(diagnostics, setting("preferredAddress", "Automatic"))
  readonly property string sshCommand: Model.sshCommand(diagnostics, setting("preferredAddress", "Automatic"))

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function configure(nextSettings) {
    root.settings = nextSettings || {}
    root.configured = true
    root.applyInitialPolicy()
  }

  function applyInitialPolicy() {
    if (!root.configured || !root.statusKnown || root.initialPolicyApplied) return
    root.initialPolicyApplied = true
    if (root.active) return
    if (setting("autoStart", false) === true) {
      root.enableFor(root.defaultDurationMinutes)
      return
    }
    if (setting("autoStartOnAc", false) === true && root.batteryPresent && !root.onBattery)
      root.enableFor(root.defaultDurationMinutes)
  }

  function applyStatus(raw) {
    var value = Model.parseObject(raw, {})
    if (value.active === undefined) return
    root.active = value.active === true
    root.scope = Model.normalizedScope(value.scope)
    root.started = Number(value.started || 0)
    root.deadline = Number(value.deadline || 0)
    root.remainingSeconds = Number(value.remainingSeconds || 0)
    root.leaseSeconds = Number(value.leaseSeconds || 45)
    root.lastReason = String(value.lastReason || "unknown")
    root.statusKnown = true
    root.lastError = ""
    root.applyInitialPolicy()
  }

  function applyDiagnostics(raw) {
    var value = Model.parseObject(raw, {})
    if (value.hostname !== undefined) root.diagnostics = value
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function refreshDiagnostics() {
    if (!diagnosticsProcess.running) diagnosticsProcess.running = true
  }

  function refreshAll() {
    refresh()
    refreshDiagnostics()
  }

  function enableFor(minutes) {
    enableWith(root.defaultScope, minutes)
  }

  function enableWith(nextScope, minutes) {
    if (actionProcess.running) return
    root.busy = true
    root.lastError = ""
    var command = [
      root.helperPath,
      "on",
      "--scope", Model.normalizedScope(nextScope),
      "--duration-minutes", String(Model.durationMinutes(minutes)),
      "--lease-seconds", "45"
    ]
    if (root.notificationsEnabled) command.push("--notify")
    actionProcess.command = command
    actionProcess.running = true
  }

  function disable(reason) {
    if (actionProcess.running) return
    root.busy = true
    root.lastError = ""
    var command = [root.helperPath, "off", "--reason", String(reason || "manual")]
    if (root.notificationsEnabled) command.push("--notify")
    actionProcess.command = command
    actionProcess.running = true
  }

  function toggle() {
    if (root.active) root.disable("manual")
    else root.enableFor(root.defaultDurationMinutes)
  }

  function checkPowerPolicy() {
    if (root.previousOnBattery !== root.onBattery) {
      var switchedToBattery = root.onBattery
      root.previousOnBattery = root.onBattery
      if (switchedToBattery && root.active && setting("stopOnBattery", false) === true) {
        root.disable("switched-to-battery")
        return
      }
      if (!switchedToBattery && !root.active && setting("autoStartOnAc", false) === true) {
        root.enableFor(root.defaultDurationMinutes)
        return
      }
    }

    if (root.active && root.onBattery && root.lowBatteryCutoff > 0
        && root.batteryPercent <= root.lowBatteryCutoff)
      root.disable("low-battery")
  }

  Component.onCompleted: {
    root.previousOnBattery = root.onBattery
    root.refreshAll()
  }

  Process {
    id: statusProcess
    command: [root.helperPath, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.lastError = "Could not read Server Mode status"
    }
  }

  Process {
    id: diagnosticsProcess
    command: [root.helperPath, "diagnostics", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyDiagnostics(text)
    }
  }

  Process {
    id: actionProcess
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.lastError = "Server Mode action failed"
      root.refreshAll()
    }
  }

  Process {
    id: renewProcess
    command: [root.helperPath, "renew"]
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.active) root.refresh()
    }
  }

  Timer {
    interval: root.refreshIntervalMs
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.refreshAll()
  }

  Timer {
    interval: 10000
    running: root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!renewProcess.running) renewProcess.running = true
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.checkPowerPolicy()
  }

  IpcHandler {
    target: root.pluginId

    function status(): string {
      return JSON.stringify({
        active: root.active,
        scope: root.scope,
        remainingSeconds: root.remainingSeconds,
        reason: root.lastReason,
        error: root.lastError
      })
    }

    function enable(): string {
      root.enableFor(root.defaultDurationMinutes)
      return "starting"
    }

    function disable(): string {
      root.disable("manual")
      return "stopping"
    }

    function toggle(): string {
      root.toggle()
      return root.active ? "stopping" : "starting"
    }

    function refresh(): string {
      root.refreshAll()
      return "ok"
    }
  }
}
