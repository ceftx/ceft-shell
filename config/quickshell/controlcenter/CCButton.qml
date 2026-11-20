import QtQuick
import qs
import qs.desktop

// Botón píldora: tonal | primary | danger. `busy` muestra un giro y bloquea el click.
Rectangle {
  id: b
  property string label: ""
  property string icon: ""
  property bool primary: false
  property bool danger: false
  property bool busy: false
  property bool compact: false
  signal clicked()

  readonly property bool usable: enabled && !busy
  readonly property color fg: primary ? Theme.background : (danger ? Theme.active : Theme.foreground)
  implicitHeight: compact ? 30 : 36
  implicitWidth: row.implicitWidth + (compact ? 22 : 30)
  radius: height / 2
  opacity: enabled ? 1 : 0.45
  color: {
    const hov = ma.containsMouse && usable
    if (primary) return hov ? Qt.lighter(Theme.accent, 1.12) : Theme.accent
    if (danger) return Qt.alpha(Theme.active, hov ? 0.30 : 0.16)
    return hov ? DeskTheme.tileHover : DeskTheme.tile
  }
  border.width: primary || danger ? 0 : 1
  border.color: Qt.alpha(Theme.foreground, 0.10)
  Behavior on color { ColorAnimation { duration: Theme.animFast } }
  scale: ma.pressed && usable ? 0.95 : 1
  Behavior on scale { NumberAnimation { duration: 100 } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 7
    Icon {
      visible: b.icon !== "" || b.busy
      name: b.busy ? "progress_activity" : b.icon
      font.pixelSize: b.compact ? 17 : 19
      color: b.fg
      anchors.verticalCenter: parent.verticalCenter
      RotationAnimator on rotation { running: b.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite; onRunningChanged: if (!running) parent.rotation = 0 }
      onVisibleChanged: if (!visible) rotation = 0
    }
    Text {
      visible: b.label !== ""
      text: b.label
      color: b.fg
      font.family: Theme.fontSans
      font.pixelSize: b.compact ? 13 : 14
      font.weight: Font.Medium
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: b.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (b.usable) b.clicked()
  }
}
