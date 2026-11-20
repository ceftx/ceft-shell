import QtQuick
import QtQuick.Effects
import qs
import qs.desktop

// Miniatura de wallpaper: carga asíncrona con sourceSize chico, borde de acento si es el actual.
Item {
  id: t
  property string path: ""
  property bool current: false
  property bool busy: false
  signal clicked()

  readonly property string fileName: path.split("/").pop()
  readonly property string label: fileName.replace(/\.[^.]+$/, "").replace(/_/g, " ")

  Rectangle {
    id: frame
    anchors.fill: parent
    radius: 16
    color: DeskTheme.tile
    clip: false
    scale: ma.pressed ? 0.97 : (ma.containsMouse ? 1.025 : 1)
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Image {
      id: img
      anchors.fill: parent
      source: t.path ? "file://" + t.path : ""
      sourceSize.width: 360
      sourceSize.height: 240
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      visible: false
      layer.enabled: true
    }
    Rectangle { id: mask; anchors.fill: parent; radius: 16; visible: false; layer.enabled: true }
    MultiEffect {
      anchors.fill: parent
      source: img
      maskEnabled: true
      maskSource: mask
      opacity: img.status === Image.Ready ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 240 } }
    }

    // degradado inferior con el nombre (solo al pasar el mouse o si es el actual)
    Rectangle {
      id: cap
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
      height: 40
      radius: 16
      opacity: ma.containsMouse || t.current ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
      gradient: Gradient {
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 1; color: Qt.alpha(Theme.shadow, 0.78) }
      }
      Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; bottomMargin: 8 }
        text: t.label
        elide: Text.ElideRight
        color: "#ffffff"
        font.family: Theme.fontSans
        font.pixelSize: 12
        font.weight: Font.Medium
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: 16
      color: "transparent"
      border.width: t.current ? 3 : 1
      border.color: t.current ? Theme.accent : Qt.alpha(Theme.foreground, ma.containsMouse ? 0.30 : 0.10)
      Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    Rectangle {
      visible: t.current
      anchors { top: parent.top; right: parent.right; margins: 8 }
      width: 24; height: 24; radius: 12
      color: Theme.accent
      Icon { anchors.centerIn: parent; name: "check"; font.pixelSize: 17; color: Theme.background; weight: 600 }
    }

    Rectangle {
      visible: t.busy
      anchors.fill: parent
      radius: 16
      color: Qt.alpha(Theme.background, 0.55)
      Icon {
        anchors.centerIn: parent
        name: "progress_activity"
        font.pixelSize: 28
        color: Theme.foreground
        RotationAnimator on rotation { running: t.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
      }
    }
  }
  MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.clicked() }
}
