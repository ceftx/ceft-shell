import QtQuick
import qs

// Tarjeta de vidrio: radio grande, borde fino, aparición escalonada.
Rectangle {
  id: card
  property int order: 0                 // posición en la cascada de entrada
  property alias hovered: hh.hovered
  default property alias content: inner.data
  property bool shown: false

  width: DeskTheme.colWidth
  radius: DeskTheme.cardRadius
  color: DeskTheme.card
  border.width: 1
  border.color: hh.hovered ? DeskTheme.cardEdgeHover : DeskTheme.cardEdge
  Behavior on border.color { ColorAnimation { duration: Theme.animMed } }

  opacity: shown ? 1 : 0
  transform: Translate { y: card.shown ? 0 : 14; Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } } }
  Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
  Timer { interval: 60 + card.order * 70; running: true; onTriggered: card.shown = true }

  HoverHandler { id: hh }

  Item {
    id: inner
    anchors.fill: parent
  }
}
