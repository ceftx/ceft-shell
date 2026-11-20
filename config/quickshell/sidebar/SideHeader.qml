import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop
import qs.controlcenter

// Cabecera: avatar, hora y fecha; botones Centro de control / bloquear / apagar (este abre las acciones de PowerGuard).
ColumnLayout {
  id: root
  spacing: 10
  property bool powerOpen: false
  signal closeRequested()
  readonly property string user: Quickshell.env("USER") || "usuario"

  SystemClock { id: clk; precision: SystemClock.Minutes }

  RowLayout {
    Layout.fillWidth: true
    spacing: 14

    Item {
      Layout.preferredWidth: 52; Layout.preferredHeight: 52
      Rectangle {
        anchors.fill: parent; radius: 26; color: Theme.accentContainer
        Text { anchors.centerIn: parent; text: root.user.charAt(0).toUpperCase(); color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: 22; font.weight: Font.Bold; visible: !face.ready }
      }
      CircleImage { id: face; anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; px: 104 }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      Text {
        text: Qt.formatTime(clk.date, Theme.clock24h ? "HH:mm" : "h:mm AP")
        color: DeskTheme.text; font.family: Theme.fontSans; font.pixelSize: 30; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
      }
      Text {
        text: Theme.formatDate(clk.date, "dddd d 'de' MMMM")
        color: DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 13
      }
    }

    Repeater {
      model: [
        { ic: "settings", tip: "Centro de control", id: "cc" },
        { ic: "lock", tip: "Bloquear", id: "lock" },
        { ic: "power_settings_new", tip: "Apagar…", id: "power" }
      ]
      Rectangle {
        id: btn
        required property var modelData
        Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
        readonly property bool lit: modelData.id === "power" && root.powerOpen
        color: lit ? Theme.accentContainer : bma.containsMouse ? DeskTheme.tileHover : DeskTheme.tile
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Icon { anchors.centerIn: parent; name: btn.modelData.ic; font.pixelSize: 20; color: btn.lit ? Theme.accent : DeskTheme.text; fill: btn.lit ? 1 : 0 }
        MouseArea {
          id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (btn.modelData.id === "cc") { root.closeRequested(); CCState.open = true }
            else if (btn.modelData.id === "lock") { root.closeRequested(); Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock"]) }
            else root.powerOpen = !root.powerOpen
          }
        }
        // tooltip mínimo
        Text {
          visible: bma.containsMouse
          anchors { top: parent.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
          text: btn.modelData.tip; color: DeskTheme.text; font.family: Theme.fontSans; font.pixelSize: 11
          z: 10
          Rectangle { z: -1; anchors.fill: parent; anchors.margins: -5; radius: 6; color: Qt.alpha(Theme.background, 0.95); border.color: Theme.glassEdge }
        }
      }
    }
  }

  // Acciones de sesión: pasan por PowerGuard (aviso si hay pacman / descargas / grabación)
  Item {
    Layout.fillWidth: true
    implicitHeight: root.powerOpen ? 42 : 0
    clip: true
    opacity: root.powerOpen ? 1 : 0
    Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
    RowLayout {
      anchors { left: parent.left; right: parent.right; top: parent.top }
      spacing: 6
      Repeater {
        model: [
          { k: "suspend", ic: "bedtime", l: "Suspender" },
          { k: "reboot", ic: "restart_alt", l: "Reiniciar" },
          { k: "poweroff", ic: "power_settings_new", l: "Apagar" },
          { k: "logout", ic: "logout", l: "Salir" }
        ]
        Rectangle {
          id: pb
          required property var modelData
          Layout.fillWidth: true; Layout.preferredHeight: 38; radius: Theme.radiusSmall + 2
          color: pma.containsMouse ? (modelData.k === "poweroff" ? Qt.alpha(Theme.active, 0.28) : DeskTheme.tileHover) : DeskTheme.tile
          Behavior on color { ColorAnimation { duration: Theme.animFast } }
          Row {
            anchors.centerIn: parent; spacing: 6
            Icon { name: pb.modelData.ic; font.pixelSize: 17; color: pb.modelData.k === "poweroff" ? Theme.active : DeskTheme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: pb.modelData.l; color: DeskTheme.text; font.family: Theme.fontSans; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
          }
          MouseArea {
            id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: root.powerOpen
            onClicked: { root.closeRequested(); PowerGuard.request(pb.modelData.k) }
          }
        }
      }
    }
  }
}
