import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.desktop

// Tema fijo: la tarjeta se pinta con los colores del propio tema (lee themes/<name>.json).
Item {
  id: c
  property string name: ""
  property bool selected: false
  property bool busy: false
  property bool dynamic: false     // tarjeta "Desde el wallpaper": usa la paleta actual de Theme
  signal clicked()

  property var pal: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.config/ceft-shell/themes/" + c.name + ".json"
    onLoaded: { try { c.pal = JSON.parse(text()) } catch (e) { c.pal = ({}) } }
  }
  readonly property color bg: dynamic ? Theme.background : (pal.background ?? "#202020")
  readonly property color fg: dynamic ? Theme.foreground : (pal.foreground ?? "#dddddd")
  readonly property var swatches: dynamic
    ? [Theme.accent, Theme.accent2, Theme.active, Theme.green, Theme.yellow]
    : [pal.accent ?? bg, pal.accent2 ?? bg, pal.active ?? bg, pal.green ?? bg, pal.yellow ?? bg]
  readonly property string title: dynamic ? "Desde el wallpaper" : (pal.name ?? name)

  Rectangle {
    id: card
    anchors.fill: parent
    radius: 16
    color: c.bg
    scale: ma.pressed ? 0.97 : (ma.containsMouse ? 1.02 : 1)
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 300 } }

    Column {
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
      spacing: 10
      Row {
        spacing: 6
        Icon {
          visible: c.dynamic
          name: "wallpaper"
          fill: 1
          font.pixelSize: 17
          color: c.fg
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          width: Math.min(implicitWidth, card.width - 28 - (c.dynamic ? 24 : 0))
          text: c.title
          elide: Text.ElideRight
          color: c.fg
          font.family: Theme.fontSans
          font.pixelSize: 13
          font.weight: Font.DemiBold
        }
      }
      Row {
        spacing: 5
        Repeater {
          model: c.swatches
          Rectangle {
            required property var modelData
            width: 18; height: 18; radius: 9
            color: modelData
            border.width: 1
            border.color: Qt.alpha(c.fg, 0.25)
          }
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: 16
      color: "transparent"
      border.width: c.selected ? 3 : 1
      border.color: c.selected ? Theme.accent : Qt.alpha(Theme.foreground, ma.containsMouse ? 0.32 : 0.12)
      Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }
    Rectangle {
      visible: c.selected
      anchors { bottom: parent.bottom; right: parent.right; margins: 12 }
      width: 22; height: 22; radius: 11
      color: Theme.accent
      Icon { anchors.centerIn: parent; name: "check"; font.pixelSize: 16; color: Theme.background; weight: 600 }
    }
    Rectangle {
      visible: c.busy
      anchors.fill: parent
      radius: 16
      color: Qt.alpha(Theme.background, 0.55)
      Icon {
        anchors.centerIn: parent
        name: "progress_activity"
        font.pixelSize: 26
        color: Theme.foreground
        RotationAnimator on rotation { running: c.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
      }
    }
  }
  MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.clicked() }
}
