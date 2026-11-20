import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import qs

// Fichas CPU / RAM / GPU (+ batería si existe). Cada una con un anillo de carga alrededor del ícono.
Item {
  id: root
  width: DeskTheme.colWidth
  height: 104
  property int order: 0
  property bool shown: false
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 320 } }
  Timer { interval: 60 + root.order * 70; running: true; onTriggered: root.shown = true }

  readonly property var bat: UPower.displayDevice
  readonly property bool hasBat: bat !== null && bat.ready && bat.isLaptopBattery
  readonly property var tiles: {
    const t = [
      { label: "CPU", icon: "memory", value: DeskSys.cpu, sub: "" },
      { label: "RAM", icon: "developer_board", value: DeskSys.ram, sub: DeskSys.ramUsed.toFixed(1) + " GB" }
    ]
    if (DeskSys.hasGpu) t.push({ label: "GPU", icon: "videogame_asset", value: DeskSys.gpu, sub: DeskSys.gpuTemp + "°" })
    if (hasBat) t.push({ label: "Batería", icon: bat.state === UPowerDeviceState.Charging ? "battery_charging_full" : "battery_full", value: Math.round(bat.percentage * 100), sub: "", invert: true })
    return t
  }

  Row {
    anchors.fill: parent
    spacing: DeskTheme.gap - 4
    Repeater {
      model: root.tiles
      Rectangle {
        id: tile
        required property var modelData
        width: (root.width - (root.tiles.length - 1) * (DeskTheme.gap - 4)) / root.tiles.length
        height: root.height
        radius: 24
        color: DeskTheme.card
        border.width: 1
        border.color: hh.hovered ? DeskTheme.cardEdgeHover : DeskTheme.cardEdge
        Behavior on border.color { ColorAnimation { duration: Theme.animMed } }
        HoverHandler { id: hh }

        property real v: modelData.value
        Behavior on v { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        readonly property color tone: modelData.invert
            ? (v < 20 ? Theme.active : v < 40 ? Theme.yellow : Theme.green)
            : (v > 85 ? Theme.active : v > 60 ? Theme.yellow : Theme.accent)

        // anillo + ícono
        Item {
          id: ring
          width: 38; height: 38
          anchors { right: parent.right; top: parent.top; margins: 12 }
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              fillColor: "transparent"; strokeColor: DeskTheme.tile; strokeWidth: 4; capStyle: ShapePath.RoundCap
              PathAngleArc { centerX: 19; centerY: 19; radiusX: 16; radiusY: 16; startAngle: -90; sweepAngle: 359.9 }
            }
            ShapePath {
              fillColor: "transparent"; strokeColor: tile.tone; strokeWidth: 4; capStyle: ShapePath.RoundCap
              PathAngleArc { centerX: 19; centerY: 19; radiusX: 16; radiusY: 16; startAngle: -90; sweepAngle: Math.max(0.1, 3.6 * tile.v) }
            }
          }
          Icon { anchors.centerIn: parent; name: modelData.icon; fill: 1; font.pixelSize: 17; color: DeskTheme.text }
        }

        Column {
          anchors { left: parent.left; bottom: parent.bottom; margins: 14 }
          spacing: 0
          Row {
            Text {
              text: Math.round(tile.v)
              font.family: DeskTheme.sans; font.pixelSize: 28; font.weight: Font.DemiBold; font.letterSpacing: -1
              color: DeskTheme.text
            }
            Text { text: "%"; topPadding: 6; font.family: DeskTheme.sans; font.pixelSize: 14; color: DeskTheme.textMuted }
          }
          Text {
            text: modelData.label + (modelData.sub ? " · " + modelData.sub : "")
            font.family: DeskTheme.sans; font.pixelSize: 13
            color: DeskTheme.textMuted
          }
        }
      }
    }
  }
}
