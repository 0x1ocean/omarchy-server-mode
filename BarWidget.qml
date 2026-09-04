pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.0x1ocean.server-mode"

  property var serverService: null

  readonly property bool active: serverService ? serverService.active : false
  readonly property bool busy: serverService ? serverService.busy : false
  readonly property string errorText: serverService ? serverService.lastError : ""
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function resolveService() {
    if (!root.bar || !root.bar.shell) return null
    var service = root.bar.shell.serviceFor(root.moduleName)
    if (!service && typeof root.bar.shell.ensureService === "function")
      service = root.bar.shell.ensureService(root.moduleName)
    return service
  }

  function syncService() {
    var service = root.resolveService()
    if (service) {
      root.serverService = service
      if (typeof service.configure === "function") service.configure(root.settings)
    }
    root.injectPanel()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("serverService" in target) target.serverService = root.serverService
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function toggleMode() {
    var service = root.serverService || root.resolveService()
    if (service) service.toggle()
  }

  function tooltip() {
    if (!root.serverService) return "Remote Server Mode is loading"
    if (root.errorText !== "") return root.errorText
    if (!root.active) return "Remote Server Mode: OFF · click for controls · right-click to turn on"
    var duration = root.serverService.deadline > 0
      ? Model.remainingLabel(root.serverService.remainingSeconds)
      : "Until logout"
    return "Remote Server Mode: ON · " + Model.scopeLabel(root.serverService.scope) + " · " + duration
      + " · click for controls · right-click to turn off"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: syncService()
  onSettingsChanged: syncService()
  Component.onCompleted: Qt.callLater(root.syncService)

  Timer {
    interval: 500
    running: root.serverService === null
    repeat: true
    onTriggered: root.syncService()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf233"
    active: root.active || root.errorText !== ""
    activeColor: root.errorText !== "" ? Color.urgent : Color.accent
    dimmed: root.busy || !root.active
    interactive: root.serverService !== null
    tooltipText: root.tooltip()

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleMode()
      else if (mouseButton === Qt.LeftButton) root.togglePanel()
    }
  }
}
