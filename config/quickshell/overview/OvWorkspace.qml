import QtQuick
import QtQuick.Effects
import qs
import qs.desktop

// Celda de un workspace: wallpaper, número, estado activo / seleccionado / destino de arrastre.
Item {
  id: c
  property int wsId: 1
  property string wallpaper: ""
  property bool active: false
  property bool selected: false
  property bool dropTarget: false
  property int winCount: 0
  signal chosen()
  signal hovered()
  signal dropEntered()
  signal dropExited()

  readonly property real r: 14

  Item {
    anchors.fill: parent
    scale: ma.pressed ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Image {
      id: img
      anchors.fill: parent
      source: c.wallpaper !== "" ? "file://" + c.wallpaper : ""
      sourceSize.width: 640
      sourceSize.height: 360
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      visible: false
      layer.enabled: true
    }
    Rectangle { id: mask; anchors.fill: parent; radius: c.r; visible: false; layer.enabled: true }
    MultiEffect {
      anchors.fill: parent
      source: img
      maskEnabled: true
      maskSource: mask
      brightness: c.dropTarget ? 0.05 : (c.active ? -0.12 : (ma.containsMouse || c.selected ? -0.22 : -0.34))
      saturation: c.active ? 0 : -0.25
      Behavior on brightness { NumberAnimation { duration: 160 } }
    }
    Rectangle { anchors.fill: parent; radius: c.r; color: Theme.background; opacity: img.status === Image.Ready ? 0 : 1 }

    // número grande de fondo
    Text {
      anchors { right: parent.right; bottom: parent.bottom; rightMargin: 14; bottomMargin: 4 }
      text: c.wsId
      color: Theme.foreground
      opacity: c.winCount === 0 ? 0.30 : 0.16
      font.family: Theme.fontSans
      font.pixelSize: Math.round(c.height * 0.34)
      font.weight: Font.Black
    }
    // vacío
    Icon {
      visible: c.winCount === 0
      anchors.centerIn: parent
      name: "add"
      font.pixelSize: 34
      color: Theme.foreground
      opacity: ma.containsMouse ? 0.7 : 0.35
      Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // borde: activo (acento sólido), seleccionado, destino
    Rectangle {
      anchors.fill: parent
      radius: c.r
      color: c.dropTarget ? Qt.alpha(Theme.accent, 0.18) : "transparent"
      border.width: c.dropTarget ? 3 : (c.active ? 2 : (c.selected ? 2 : 1))
      border.color: c.dropTarget ? Theme.accent : (c.active ? Theme.accent : (c.selected ? Qt.alpha(Theme.foreground, 0.7) : Theme.glassEdge))
      Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    // etiqueta
    Rectangle {
      anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 10 }
      height: 24; radius: 12
      width: lbl.implicitWidth + 18
      color: c.active ? Theme.accent : Qt.alpha(Theme.background, 0.72)
      Text {
        id: lbl
        anchors.centerIn: parent
        text: c.active ? "Workspace " + c.wsId + " · activo" : "Workspace " + c.wsId
        color: c.active ? Theme.background : Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: 12
        font.weight: Font.DemiBold
      }
    }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    onClicked: c.chosen()
    onPositionChanged: c.hovered()
  }
  DropArea {
    anchors.fill: parent
    onEntered: c.dropEntered()
    onExited: c.dropExited()
  }
}
