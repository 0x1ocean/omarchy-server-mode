pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.0x1ocean.server-mode"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var serverService: null
  property string page: "power"

  readonly property var info: serverService ? serverService.diagnostics : ({})
  readonly property var tailscale: info.tailscale || ({})
  readonly property var ssh: info.ssh || ({})
  readonly property var remoteDesktop: info.remoteDesktop || ({})
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string preferredAddress: serverService ? serverService.preferredAddress : ""
  readonly property string sshCommand: serverService ? serverService.sshCommand : ""

  function open() {
    if (serverService) serverService.refreshAll()
    root.controller.show()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(hostWidget || root, direction)
    return false
  }

  function setPage(nextPage) {
    root.page = nextPage
    panelFlick.contentY = 0
  }

  function copyText(value) {
    var text = String(value || "")
    if (text === "") return
    Quickshell.execDetached(["wl-copy", "--", text])
  }

  function turnOn(minutes) {
    if (serverService) serverService.enableFor(minutes)
  }

  function durationSelected(minutes) {
    if (!serverService) return false
    if (!serverService.active)
      return serverService.defaultDurationMinutes === minutes
    if (minutes === 0) return serverService.deadline === 0
    if (serverService.deadline === 0 || serverService.remainingSeconds <= 0) return false
    if (minutes === 30) return serverService.remainingSeconds <= 30 * 60
    if (minutes === 60)
      return serverService.remainingSeconds > 30 * 60 && serverService.remainingSeconds <= 60 * 60
    return serverService.remainingSeconds > 60 * 60 && serverService.remainingSeconds <= 240 * 60
  }

  function heroMeta() {
    if (!serverService) return "Loading service"
    if (!serverService.active) return Model.connectionSummary(info)
    var duration = serverService.deadline > 0
      ? Model.remainingLabel(serverService.remainingSeconds)
      : "Until logout"
    return Model.scopeLabel(serverService.scope) + " · " + duration
  }

  function remoteScreenSummary() {
    var providers = []
    var items = [
      { name: "Sunshine", value: remoteDesktop.sunshine },
      { name: "RustDesk", value: remoteDesktop.rustdesk },
      { name: "WayVNC", value: remoteDesktop.wayvnc }
    ]
    for (var i = 0; i < items.length; i++) {
      if (items[i].value && items[i].value.active === true)
        return items[i].name + " running"
      if (items[i].value && items[i].value.installed === true)
        providers.push(items[i].name)
    }
    return providers.length > 0 ? providers.join(", ") : "Not configured"
  }

  onOpenedChanged: if (opened && serverService) serverService.refreshAll()

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "p" || text === "P") root.setPage("power")
        else if (text === "a" || text === "A") root.setPage("access")
        else if (text === "r" || text === "R") {
          if (root.serverService) root.serverService.refreshAll()
        } else if (text === "s" || text === "S") {
          root.copyText(root.sshCommand)
        }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Server Mode"
            meta: root.heroMeta()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              OpticalGlyph {
                text: "󰍹"
                fontFamily: root.fontFamily
                fontSize: Style.font.display
                color: root.serverService && root.serverService.active ? Color.accent : root.dim
              }
            }
            trailingControl: Component {
              ToggleSwitch {
                checked: root.serverService ? root.serverService.active : false
                busy: root.serverService ? root.serverService.busy : false
                foreground: root.foreground
                accent: Color.accent
                onToggled: if (root.serverService) root.serverService.toggle()
              }
            }
          }

          Text {
            visible: root.serverService && root.serverService.lastError !== ""
            width: parent.width
            text: root.serverService ? root.serverService.lastError : ""
            textFormat: Text.PlainText
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Row {
            width: parent.width
            spacing: Style.space(4)

            ChoiceButton {
              width: (parent.width - parent.spacing) / 2
              text: "Power"
              selected: root.page === "power"
              onClicked: root.setPage("power")
            }
            ChoiceButton {
              width: (parent.width - parent.spacing) / 2
              text: "Access"
              selected: root.page === "access"
              onClicked: root.setPage("access")
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            visible: root.page === "power"
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader { text: "STATUS"; foreground: root.foreground; fontFamily: root.fontFamily }
            StatusRow {
              label: "Sleep"
              value: root.serverService && root.serverService.active ? "Protected" : "Normal"
              valueColor: root.serverService && root.serverService.active ? Color.accent : root.dim
            }
            StatusRow {
              visible: root.serverService && root.serverService.batteryPresent
              label: "Power"
              value: root.serverService
                ? ((root.serverService.onBattery ? "Battery · " : "AC · ") + root.serverService.batteryPercent + "%")
                : "—"
              valueColor: root.serverService && root.serverService.onBattery
                && root.serverService.batteryPercent <= root.serverService.lowBatteryCutoff
                ? root.urgent : root.foreground
            }

            PanelSectionHeader { text: "PROTECTION"; foreground: root.foreground; fontFamily: root.fontFamily }
            Row {
              width: parent.width
              spacing: Style.space(4)

              ChoiceButton {
                width: (parent.width - parent.spacing) / 2
                text: "Full server"
                selected: root.serverService && (root.serverService.active
                  ? root.serverService.scope === "full"
                  : root.serverService.defaultScope === "full")
                onClicked: if (root.serverService)
                  root.serverService.enableWith("full", root.serverService.defaultDurationMinutes)
              }
              ChoiceButton {
                width: (parent.width - parent.spacing) / 2
                text: "Lid only"
                selected: root.serverService && (root.serverService.active
                  ? root.serverService.scope === "lid"
                  : root.serverService.defaultScope === "lid")
                onClicked: if (root.serverService)
                  root.serverService.enableWith("lid", root.serverService.defaultDurationMinutes)
              }
            }

            PanelSectionHeader { text: "DURATION"; foreground: root.foreground; fontFamily: root.fontFamily }
            Row {
              width: parent.width
              spacing: Style.space(4)

              ChoiceButton {
                width: (parent.width - parent.spacing * 3) / 4
                text: "30m"
                selected: root.durationSelected(30)
                onClicked: root.turnOn(30)
              }
              ChoiceButton {
                width: (parent.width - parent.spacing * 3) / 4
                text: "1h"
                selected: root.durationSelected(60)
                onClicked: root.turnOn(60)
              }
              ChoiceButton {
                width: (parent.width - parent.spacing * 3) / 4
                text: "4h"
                selected: root.durationSelected(240)
                onClicked: root.turnOn(240)
              }
              ChoiceButton {
                width: (parent.width - parent.spacing * 3) / 4
                text: "Session"
                selected: root.durationSelected(0)
                onClicked: root.turnOn(0)
              }
            }

            Text {
              width: parent.width
              text: "Choosing a protection mode or duration turns Server Mode on."
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Column {
            visible: root.page === "access"
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader { text: "CONNECT"; foreground: root.foreground; fontFamily: root.fontFamily }
            ActionButton {
              width: parent.width
              text: root.preferredAddress !== "" ? root.preferredAddress : "Address unavailable"
              iconText: "󰆏"
              enabled: root.preferredAddress !== ""
              onClicked: root.copyText(root.preferredAddress)
            }
            StatusRow { label: "Hostname"; value: root.info.hostname || "Unavailable" }
            StatusRow { label: "LAN"; value: root.info.lanIp || "Unavailable" }
            StatusRow {
              label: "Tailscale"
              value: root.tailscale.active
                ? (root.tailscale.ip || root.tailscale.name || "Connected")
                : (root.tailscale.installed ? "Disconnected" : "Not installed")
              valueColor: root.tailscale.active ? root.foreground : root.dim
            }

            PanelSeparator { foreground: root.foreground }
            PanelSectionHeader { text: "SSH"; foreground: root.foreground; fontFamily: root.fontFamily }
            StatusRow {
              label: "Server"
              value: root.ssh.active ? "Running" : (root.ssh.installed ? "Stopped" : "Not installed")
              valueColor: root.ssh.active ? Color.accent : root.dim
            }
            ActionButton {
              width: parent.width
              text: root.sshCommand !== "" ? root.sshCommand : "SSH command unavailable"
              iconText: "󰆍"
              enabled: root.sshCommand !== ""
              onClicked: root.copyText(root.sshCommand)
            }
            Text {
              visible: !root.ssh.active
              width: parent.width
              text: root.ssh.installed
                ? "OpenSSH is installed but stopped. Start it explicitly before connecting."
                : "Install OpenSSH to enable terminal access."
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            PanelSeparator { foreground: root.foreground }
            PanelSectionHeader { text: "REMOTE SCREEN"; foreground: root.foreground; fontFamily: root.fontFamily }
            StatusRow { label: "Provider"; value: root.remoteScreenSummary() }
            Text {
              width: parent.width
              text: Model.hasRemoteDesktop(root.info)
                ? "A remote-screen provider is available on this computer."
                : "Install Sunshine, RustDesk, or WayVNC to add screen access."
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }

  component ChoiceButton: Button {
    bordered: false
    foreground: root.foreground
    accent: Color.accent
    background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
  }

  component ActionButton: Button {
    bordered: true
    leftAlign: true
    foreground: root.foreground
    accent: Color.accent
    background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
  }

  component StatusRow: Item {
    property string label: ""
    property string value: ""
    property color valueColor: root.foreground

    width: parent ? parent.width : Style.space(340)
    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight) + Style.space(2)

    Text {
      id: labelText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width * 0.38
      text: parent.label
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      id: valueText
      anchors.left: labelText.right
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: parent.value
      textFormat: Text.PlainText
      color: parent.valueColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideMiddle
    }
  }
}
