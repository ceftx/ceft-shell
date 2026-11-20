import Quickshell
import Quickshell.Hyprland
import QtQuick

// Indicador de workspaces: una píldora que se desliza hasta el activo y se estira en la
// dirección del movimiento (el borde delantero llega antes que el trasero).
// Barra vertical: los workspaces van en columna y la píldora se desliza hacia arriba/abajo.
Item {
  id: root
  required property var barScreen
  property bool vertical: false

  readonly property int cellW: 26
  readonly property int cellGap: 2
  readonly property var monitor: Hyprland.monitorFor(barScreen)
  readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1

  // Workspaces 1-5 siempre visibles + los que existan por encima
  readonly property var ids: {
    const out = [1, 2, 3, 4, 5]
    for (const ws of Hyprland.workspaces.values)
      if (ws.id > 0 && out.indexOf(ws.id) < 0) out.push(ws.id)
    return out.sort((a, b) => a - b)
  }
  readonly property int activeIndex: ids.indexOf(activeId)

  readonly property real run: ids.length * cellW + (ids.length - 1) * cellGap     // largo del eje
  implicitWidth: vertical ? Theme.barW - 12 : run
  implicitHeight: vertical ? run : Theme.barH - 12
  width: implicitWidth; height: implicitHeight
  Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
  Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

  // ── píldora activa: dos bordes con tiempos distintos ──
  property real leftEdge: 0
  property real rightEdge: cellW
  property bool movingRight: true
  function target() {
    if (activeIndex < 0) return
    const l = activeIndex * (cellW + cellGap)
    movingRight = l >= leftEdge
    leftEdge = l
    rightEdge = l + cellW
  }
  onActiveIndexChanged: target()
  Component.onCompleted: {
    if (activeIndex >= 0) { leftEdge = activeIndex * (cellW + cellGap); rightEdge = leftEdge + cellW }
  }
  Behavior on leftEdge  { NumberAnimation { duration: root.movingRight ? 320 : 170; easing.type: Easing.OutCubic } }
  Behavior on rightEdge { NumberAnimation { duration: root.movingRight ? 170 : 320; easing.type: Easing.OutCubic } }

  Rectangle {
    visible: root.activeIndex >= 0
    x: root.vertical ? (root.width - width) / 2 : root.leftEdge
    y: root.vertical ? root.leftEdge : (root.height - height) / 2
    width: root.vertical ? 22 : root.rightEdge - root.leftEdge
    height: root.vertical ? root.rightEdge - root.leftEdge : 22
    radius: height / 2
    color: Theme.accent
  }

  Grid {
    columns: root.vertical ? 1 : 100
    spacing: root.cellGap
    x: root.vertical ? (root.width - width) / 2 : 0
    y: root.vertical ? 0 : (root.height - height) / 2
    Repeater {
      model: root.ids
      BarText {
        id: cell
        required property int modelData
        readonly property var ws: Hyprland.workspaces.values.find(w => w.id === modelData) ?? null
        readonly property bool shown: root.activeId === modelData
        readonly property bool occupied: ws !== null && ws.toplevels.values.length > 0
        readonly property bool urgent: ws !== null && ws.urgent && !shown
        width: root.vertical ? root.width : root.cellW
        height: root.vertical ? root.cellW : Theme.barH - 12
        horizontalAlignment: Text.AlignHCenter
        pill: false
        font.family: Theme.font
        font.pixelSize: Theme.fontSmall + 1
        text: modelData === 10 ? "0" : String(modelData)
        font.bold: shown
        color: shown ? Theme.background : urgent ? Theme.active : occupied ? Theme.foreground : Theme.muted
        scale: cell.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }

        // hover: aro suave (solo en los inactivos)
        Rectangle {
          z: -1
          anchors.centerIn: parent
          width: root.vertical ? 22 : parent.width; height: root.vertical ? root.cellW : 22; radius: Math.min(width, height) / 2
          color: cell.hovered && !cell.shown ? Theme.hover : cell.occupied && !cell.shown ? Theme.accentContainer : "transparent"
          Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
        // urgente: puntito que respira
        Rectangle {
          visible: cell.urgent
          width: 5; height: 5; radius: 2.5
          color: Theme.active
          anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
          SequentialAnimation on opacity {
            running: cell.urgent; loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
          }
        }
        onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace=${modelData}})`)
        onScrolled: d => Hyprland.dispatch(`hl.dsp.focus({workspace="${d < 0 ? "e+1" : "e-1"}"})`)
      }
    }
  }
}
