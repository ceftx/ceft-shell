import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import qs

DeskCard {
  id: card
  height: content.implicitHeight + DeskTheme.pad * 2

  property string user: Quickshell.env("USER")
  property string host: ""
  property string realName: ""
  property real uptimeSec: 0
  property bool avatarExists: false

  readonly property string displayName: (DeskConfig.profile.name || realName || user)
  readonly property string avatarPath: {
    const p = DeskConfig.profile.avatar || "~/.face"
    return p.replace(/^~/, Quickshell.env("HOME"))
  }
  readonly property string uptimeText: {
    const m = Math.floor(uptimeSec / 60), h = Math.floor(m / 60), d = Math.floor(h / 24)
    if (d > 0) return "activo " + d + " d " + (h % 24) + " h"
    if (h > 0) return "activo " + h + " h " + (m % 60) + " min"
    return "activo " + m + " min"
  }

  Process {
    id: info
    command: ["sh", "-c", "echo \"$USER\"; cat /proc/sys/kernel/hostname; getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1; cut -d' ' -f1 /proc/uptime; if [ -f \"$1\" ]; then echo yes; else echo no; fi", "sh", card.avatarPath]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const l = text.split("\n")
        card.user = l[0] || card.user; card.host = l[1] || ""; card.realName = /[A-Za-z]/.test(l[2] || "") ? l[2] : ""
        card.uptimeSec = parseFloat(l[3]) || 0
        card.avatarExists = l[4] === "yes"
      }
    }
  }
  Timer { interval: 60000; running: true; repeat: true; onTriggered: info.running = true }

  Process { id: runner }
  function run(cmd) { runner.command = ["sh", "-c", cmd]; runner.running = true }

  Column {
    id: content
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeskTheme.pad }
    spacing: 16

    Row {
      spacing: 16
      // Avatar circular (imagen -> ~/.face; si no existe, inicial sobre el acento)
      Item {
        id: avatar
        width: 68; height: 68
        readonly property bool hasImage: img.status === Image.Ready
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          visible: !avatar.hasImage
          color: Theme.accent
          Text {
            anchors.centerIn: parent
            text: card.displayName.charAt(0).toUpperCase()
            font.family: DeskTheme.sans; font.pixelSize: 30; font.weight: Font.DemiBold
            color: DeskTheme.onAccent
          }
        }
        Image {
          id: img
          anchors.fill: parent
          source: card.avatarExists ? "file://" + card.avatarPath : ""
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(136, 136)
          visible: false
          layer.enabled: true
        }
        Rectangle { id: mask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect {
          anchors.fill: parent
          visible: avatar.hasImage
          source: img
          maskEnabled: true
          maskSource: mask
        }
        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 2; border.color: Qt.alpha(Theme.accent, 0.55) }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        width: content.width - 68 - 16
        Text {
          width: parent.width
          text: card.displayName
          elide: Text.ElideRight
          font.family: DeskTheme.sans; font.pixelSize: 20; font.weight: Font.DemiBold
          color: DeskTheme.text
        }
        Text {
          width: parent.width
          text: card.user + "@" + card.host
          elide: Text.ElideRight
          font.family: DeskTheme.sans; font.pixelSize: 13
          color: DeskTheme.textMuted
        }
        Text {
          text: card.uptimeText
          font.family: DeskTheme.sans; font.pixelSize: 13
          color: DeskTheme.textMuted
        }
      }
    }

    // frase de clima
    Rectangle {
      width: parent.width; height: 38
      radius: 19
      color: DeskTheme.tile
      Row {
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
        spacing: 8
        Icon { name: DeskWeather.ready ? DeskWeather.icon : "cloud_off"; font.pixelSize: 20; fill: 1; color: Theme.accent2; anchors.verticalCenter: parent.verticalCenter }
        Text {
          text: DeskWeather.phrase
          font.family: DeskTheme.sans; font.pixelSize: 13
          color: DeskTheme.text
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    Row {
      spacing: 8
      RoundButton { icon: "lock"; label: "Bloquear"; primary: true; iconFill: 1; onClicked: card.run("if command -v hyprlock >/dev/null; then hyprlock; else loginctl lock-session; fi") }
      RoundButton {
        id: settingsBtn
        icon: "settings"; iconFill: 1
        // Si el panel de control (IPC) existe lo abre; si no, abre settings.lua en kitty (nunca falla en silencio)
        onClicked: card.run("if qs ipc show 2>/dev/null | grep -q '^target controlcenter'; then qs ipc call controlcenter open; else setsid -f kitty --title ceft-settings -e ~/.local/bin/ceft-shell edit settings >/dev/null 2>&1; fi")
      }
      RoundButton {
        icon: "power_settings_new"
        onClicked: PowerGuard.openMenu()
      }
    }
  }
}
