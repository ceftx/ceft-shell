import QtQuick

// Línea de puntos horizontal (separador de la barra, estilo end-4).
Item {
  id: root
  property real dot: 2
  property real gap: 4
  property color color: Theme.muted
  implicitHeight: dot

  Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.gap
    Repeater {
      model: Math.max(0, Math.floor((root.width + root.gap) / (root.dot + root.gap)))
      Rectangle { width: root.dot; height: root.dot; radius: root.dot / 2; color: root.color; opacity: 0.55 }
    }
  }
}
