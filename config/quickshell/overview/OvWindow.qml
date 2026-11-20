import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs
import qs.desktop

// Miniatura de una ventana dentro de la celda de su workspace. Arrastrable a otra celda.
Item {
  id: w
  required property var tl
  required property var ov
  property int cols: 5
  property real cellW: 400
  property real cellH: 225
  property real gap: 16
  property real k: 0.15
  property real offX: 0
  property real offY: 0
  property real scrW: 1920
  property real scrH: 1080
  property real originX: 0
  property real originY: 0
  property bool dimmed: false
  property bool isFirst: false
  property bool confirming: false
  signal focusRequested()
  signal moveRequested(int ws)
  signal closeRequested()

  readonly property var ipc: tl.lastIpcObject ?? ({})
  property int overrideWs: -1
  readonly property int ws: overrideWs > 0 ? overrideWs : (ipc.workspace?.id ?? 1)
  onIpcChanged: overrideWs = -1
  readonly property real baseX: ((ws - 1) % cols) * (cellW + gap)
  readonly property real baseY: Math.floor((ws - 1) / cols) * (cellH + gap)
  readonly property real lx: Math.max(0, Math.min(scrW * k - 6, ((ipc.at?.[0] ?? 0) - originX) * k))
  readonly property real ly: Math.max(0, Math.min(scrH * k - 6, ((ipc.at?.[1] ?? 0) - originY) * k))
  readonly property real relX: offX + lx
  readonly property real relY: offY + ly
  readonly property string cls: ipc.class ?? ""
  readonly property string iconSrc: Quickshell.iconPath(DesktopEntries.heuristicLookup(cls)?.icon ?? cls.toLowerCase(), true)

  width: Math.max(10, Math.min(scrW * k - lx, (ipc.size?.[0] ?? 100) * k))
  height: Math.max(10, Math.min(scrH * k - ly, (ipc.size?.[1] ?? 100) * k))
  Binding on x { when: !ma.drag.active; value: w.baseX + w.relX }
  Binding on y { when: !ma.drag.active; value: w.baseY + w.relY }
  Behavior on x { enabled: !ma.drag.active; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on y { enabled: !ma.drag.active; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  z: ma.drag.active ? 1000 : (ipc.floating ? 2 : 1)
  opacity: dimmed ? 0.16 : 1
  Behavior on opacity { NumberAnimation { duration: 160 } }
  scale: ma.drag.active ? 1.05 : (ma.containsMouse ? 1.02 : 1)
  Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  Drag.active: ma.drag.active
  Drag.source: w
  Drag.hotSpot.x: width / 2
  Drag.hotSpot.y: height / 2

  Rectangle {
    id: frame
    anchors.fill: parent
    radius: 6
    color: Theme.surface
    clip: true
    border.width: w.isFirst ? 2 : 1
    border.color: w.confirming ? Theme.active : (w.isFirst ? Theme.accent : (ma.containsMouse ? Theme.accent : Qt.alpha(Theme.foreground, 0.28)))
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    ScreencopyView {
      id: scv
      anchors.fill: parent
      captureSource: w.ov.open ? w.tl.wayland : null
      live: w.ov.live
      paintCursor: false
      visible: hasContent

    }

    Image {
      visible: !scv.hasContent && w.iconSrc !== ""
      anchors.centerIn: parent
      width: Math.min(48, parent.width * 0.5); height: width
      source: w.iconSrc
      sourceSize.width: 64; sourceSize.height: 64
      asynchronous: true
    }
    Text {
      visible: !scv.hasContent && w.iconSrc === ""
      anchors.centerIn: parent
      text: w.cls.charAt(0).toUpperCase()
      color: Theme.muted
      font.family: Theme.fontSans
      font.pixelSize: 24
      font.weight: Font.Bold
    }

    // nombre de la app
    Rectangle {
      visible: w.width > 90 && (ma.containsMouse || w.isFirst || !scv.hasContent)
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
      height: 20
      color: Qt.alpha(Theme.background, 0.8)
      Text {
        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: w.ipc.title ? w.ipc.title : w.cls
        color: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: 11
      }
    }

    // confirmación de cierre
    Rectangle {
      anchors.fill: parent
      color: Qt.alpha(Theme.active, 0.80)
      opacity: w.confirming ? 1 : 0
      visible: opacity > 0.01
      Behavior on opacity { NumberAnimation { duration: 120 } }
      Column {
        anchors.centerIn: parent
        spacing: 2
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "close"; font.pixelSize: 26; color: Theme.background }
        Text {
          visible: w.width > 110
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Clic medio para cerrar"
          color: Theme.background
          font.family: Theme.fontSans
          font.pixelSize: 11
          font.weight: Font.DemiBold
        }
      }
    }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    drag.target: w
    drag.threshold: 10
    drag.filterChildren: true
    property bool moved: false
    onPressed: mouse => { moved = false; ov.dropWs = -1 }
    onPositionChanged: if (drag.active) { moved = true; ov.dragging = true }
    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) w.closeRequested()
      else if (!moved) w.focusRequested()
    }
    onReleased: mouse => {
      if (!moved) return
      const t = ov.dropWs
      ov.dragging = false
      ov.dropWs = -1
      if (t > 0 && t !== w.ws) { w.overrideWs = t; w.moveRequested(t) }
    }
    onCanceled: ov.dragging = false
  }
}
