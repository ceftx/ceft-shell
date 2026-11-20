import QtQuick
import qs

// Slider con valor numérico. Mientras se arrastra solo cambia la etiqueta; `committed` se emite al soltar.
Item {
  id: s
  property real from: 0
  property real to: 100
  property real step: 1
  property real value: 0
  property string unit: ""
  property int decimals: 0
  property string zeroLabel: ""
  signal committed(real value)

  implicitWidth: 260
  implicitHeight: 30

  property real shown: value
  property bool dragging: false
  onValueChanged: if (!dragging) shown = value

  readonly property real frac: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

  function snap(v) {
    const n = Math.round((v - from) / step) * step + from
    return Math.max(from, Math.min(to, Number(n.toFixed(4))))
  }

  Item {
    id: track
    anchors { left: parent.left; right: label.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
    height: 20
    Rectangle {
      id: rail
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
      height: 6; radius: 3
      color: Qt.alpha(Theme.foreground, 0.14)
      Rectangle {
        width: knob.x + knob.width / 2
        height: parent.height; radius: 3
        color: Theme.accent
        Behavior on width { enabled: !s.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      }
    }
    Rectangle {
      id: knob
      width: ma.pressed ? 20 : (ma.containsMouse ? 18 : 16)
      height: width; radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      x: s.frac * (track.width - 16) + (16 - width) / 2
      color: Theme.accent
      border.width: 3
      border.color: Theme.background
      Behavior on width { NumberAnimation { duration: 100 } }
      Behavior on x { enabled: !s.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
    MouseArea {
      id: ma
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      function setFrom(mx) {
        const f = Math.max(0, Math.min(1, (mx - 8) / (track.width - 16)))
        s.shown = s.snap(s.from + f * (s.to - s.from))
      }
      onPressed: (m) => { s.dragging = true; setFrom(m.x) }
      onPositionChanged: (m) => { if (pressed) setFrom(m.x) }
      onReleased: { s.dragging = false; if (s.shown !== s.value) s.committed(s.shown) }
      onCanceled: { s.dragging = false; s.shown = s.value }
    }
  }
  Text {
    id: label
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    width: 58
    horizontalAlignment: Text.AlignRight
    text: (s.zeroLabel !== "" && s.shown === 0) ? s.zeroLabel : s.shown.toFixed(s.decimals) + s.unit
    color: Theme.foreground
    font.family: Theme.fontSans
    font.pixelSize: 13
    font.weight: Font.Medium
    font.features: ({ "tnum": 1 })
  }
}
