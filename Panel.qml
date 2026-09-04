pragma ComponentBehavior: Bound

import QtQuick
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

  function copyText(value) {
    var text = String(value || "")
    if (text === "") return
    Quickshell.execDetached(["wl-copy", "--", text])
  }

  function turnOn(minutes) {
    if (serverService) serverService.enableFor(minutes)
  }

  onOpenedChanged: if (opened && serverService) serverService.refreshAll()

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    // Match Omarchy's standard panel cap so fractional display scaling never
    // leaves the card pressed against the bottom edge of the screen.
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") {
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

        Column {
          id: content
          width: panelFlick.width - Style.space(8)
          spacing: Style.space(8)

          PanelHero {
            width: parent.width
            title: "Server Mode"
            detail: root.serverService && root.serverService.active ? "ON" : "OFF"
            meta: root.serverService
              ? Model.connectionSummary(root.info)
              : "Loading service"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              OpticalGlyph {
                text: "\uf233"
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

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader { text: "POWER PROTECTION"; foreground: root.foreground; fontFamily: root.fontFamily }

          StatusRow {
            label: "State"
            value: root.serverService && root.serverService.active ? "Protected" : "Normal sleep"
            valueColor: root.serverService && root.serverService.active ? Color.accent : root.dim
          }
          StatusRow {
            label: "Scope"
            value: root.serverService ? Model.scopeLabel(root.serverService.scope) : "—"
          }
          StatusRow {
            label: "Duration"
            value: root.serverService && root.serverService.active
              ? (root.serverService.deadline > 0
                ? Model.remainingLabel(root.serverService.remainingSeconds)
                : "Until logout")
              : (root.serverService
                ? Model.durationLabel(root.serverService.defaultDurationMinutes)
                : "—")
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

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - parent.spacing * 3) / 4
              text: "30m"
              bordered: true
              background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
              selected: root.serverService && root.serverService.active && root.serverService.remainingSeconds > 0
                && root.serverService.remainingSeconds <= 30 * 60
              foreground: root.foreground
              accent: Color.accent
              onClicked: root.turnOn(30)
            }
            Button {
              width: (parent.width - parent.spacing * 3) / 4
              text: "1h"
              bordered: true
              background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
              selected: root.serverService && root.serverService.active && root.serverService.remainingSeconds > 30 * 60
                && root.serverService.remainingSeconds <= 60 * 60
              foreground: root.foreground
              accent: Color.accent
              onClicked: root.turnOn(60)
            }
            Button {
              width: (parent.width - parent.spacing * 3) / 4
              text: "4h"
              bordered: true
              background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
              selected: root.serverService && root.serverService.active && root.serverService.remainingSeconds > 60 * 60
                && root.serverService.remainingSeconds <= 240 * 60
              foreground: root.foreground
              accent: Color.accent
              onClicked: root.turnOn(240)
            }
            Button {
              width: (parent.width - parent.spacing * 3) / 4
              text: "Session"
              bordered: true
              background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
              selected: root.serverService && root.serverService.active && root.serverService.deadline === 0
              foreground: root.foreground
              accent: Color.accent
              onClicked: root.turnOn(0)
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Full server"
              bordered: true
              background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
              selected: root.serverService && root.serverService.active && root.serverService.scope === "full"
              foreground: root.foreground
              accent: Color.accent
              onClicked: if (root.serverService)
                root.serverService.enableWith("full", root.serverService.defaultDurationMinutes)
            }
            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Lid only"
              bordered: true
              background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
              selected: root.serverService && root.serverService.active && root.serverService.scope === "lid"
              foreground: root.foreground
              accent: Color.accent
              onClicked: if (root.serverService)
                root.serverService.enableWith("lid", root.serverService.defaultDurationMinutes)
            }
          }

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader { text: "CONNECTION"; foreground: root.foreground; fontFamily: root.fontFamily }

          StatusRow { label: "Hostname"; value: root.info.hostname || "Unavailable" }
          StatusRow { label: "LAN"; value: root.info.lanIp || "Unavailable" }
          StatusRow {
            label: "Tailscale"
            value: root.tailscale.active
              ? (root.tailscale.ip || root.tailscale.name || "Connected")
              : (root.tailscale.installed ? "Disconnected" : "Not installed")
            valueColor: root.tailscale.active ? root.foreground : root.dim
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            Button {
              width: (parent.width - parent.spacing) / 2
              text: root.preferredAddress !== "" ? "Copy address" : "No address"
              iconText: "󰆏"
              bordered: true
              background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
              enabled: root.preferredAddress !== ""
              foreground: root.foreground
              accent: Color.accent
              onClicked: root.copyText(root.preferredAddress)
            }
            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Refresh"
              iconText: "󰑐"
              bordered: true
              background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
              foreground: root.foreground
              accent: Color.accent
              onClicked: if (root.serverService) root.serverService.refreshAll()
            }
          }

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader { text: "SSH"; foreground: root.foreground; fontFamily: root.fontFamily }

          StatusRow {
            label: "Server"
            value: root.ssh.active ? "Running" : (root.ssh.installed ? "Stopped" : "Not installed")
            valueColor: root.ssh.active ? Color.accent : root.dim
          }
          StatusRow { label: "Port"; value: root.ssh.installed ? String(root.ssh.port || 22) : "—" }

          Button {
            width: parent.width
            text: root.sshCommand !== "" ? root.sshCommand : "SSH command unavailable"
            iconText: "󰆍"
            bordered: true
            background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
            leftAlign: true
            enabled: root.sshCommand !== ""
            foreground: root.foreground
            accent: Color.accent
            onClicked: root.copyText(root.sshCommand)
          }

          Text {
            visible: !root.ssh.active
            width: parent.width
            text: root.ssh.installed
              ? "The SSH server is installed but not running. Server Mode does not start privileged services automatically."
              : "OpenSSH server is not installed. Server Mode will never install it or open a firewall port without your explicit action."
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader { text: "REMOTE SCREEN"; foreground: root.foreground; fontFamily: root.fontFamily }

          StatusRow {
            label: "Sunshine"
            value: Model.providerLabel(root.remoteDesktop.sunshine)
            valueColor: root.remoteDesktop.sunshine && root.remoteDesktop.sunshine.active ? Color.accent : root.dim
          }
          StatusRow {
            label: "RustDesk"
            value: Model.providerLabel(root.remoteDesktop.rustdesk)
            valueColor: root.remoteDesktop.rustdesk && root.remoteDesktop.rustdesk.active ? Color.accent : root.dim
          }
          StatusRow {
            label: "WayVNC"
            value: Model.providerLabel(root.remoteDesktop.wayvnc)
            valueColor: root.remoteDesktop.wayvnc && root.remoteDesktop.wayvnc.active ? Color.accent : root.dim
          }

          Text {
            width: parent.width
            text: Model.hasRemoteDesktop(root.info)
              ? "Provider control and headless-display support are planned for the next milestone."
              : "Install Sunshine, RustDesk, or WayVNC to add remote-screen access. No provider is installed automatically."
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Item {
            width: parent.width
            height: Style.space(2)
          }
        }

      }

      Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Style.space(2)
        visible: panelFlick.interactive
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        radius: width / 2
        z: 2

        Rectangle {
          width: parent.width
          height: Math.max(Style.space(24), parent.height * panelFlick.visibleArea.heightRatio)
          y: parent.height * panelFlick.visibleArea.yPosition
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
          radius: width / 2
        }
      }
    }
  }

  component StatusRow: Item {
    property string label: ""
    property string value: ""
    property color valueColor: root.foreground

    width: parent ? parent.width : Style.space(360)
    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight) + Style.space(4)

    Text {
      id: labelText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width * 0.34
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
