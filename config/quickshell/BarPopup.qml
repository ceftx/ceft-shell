import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Panel desplegable pegado a la barra (debajo si está arriba, encima si está abajo), centrado bajo su icono.
// Barra vertical: se abre al costado (a la derecha si la barra está a la izquierda y viceversa), centrado en vertical
// con su icono y sin salirse de la pantalla.
// Se cierra con click fuera (capa invisible) o Esc.
PanelWindow {
  id: win
  required property string name
  required property var barWindow
  property Item anchorItem: null
  property int panelWidth: 320
  property string title: ""
  default property alias content: col.data
  readonly property bool open: PopupState.current === name

  readonly property bool vertical: BarConfig.vertical
  property real rightMargin: 8
  property real anchorY: 0         // centro vertical del icono (barra vertical), en coordenadas de pantalla
  readonly property real topMargin: Math.max(8, Math.min(barWindow.height - implicitHeight - 8, anchorY - implicitHeight / 2))
  function place() {
    if (!anchorItem) return
    // la barra ocupa todo el ancho (sin margen): x del widget = x de pantalla
    const c = anchorItem.mapToItem(null, anchorItem.width / 2, anchorItem.height / 2)
    if (vertical) { anchorY = c.y; return }
    const sw = barWindow.width
    rightMargin = Math.max(8, Math.min(sw - panelWidth - 8, sw - c.x - panelWidth / 2))
  }

  screen: barWindow.screen
  visible: open
  onOpenChanged: if (open) place()
  readonly property bool atBottom: BarConfig.isBottom
  anchors {
    top: vertical || !atBottom; bottom: !vertical && atBottom
    right: !vertical || BarConfig.isRight; left: BarConfig.isLeft
  }
  margins {   // pegado al borde de la barra que da a las ventanas
    top: vertical ? topMargin : atBottom ? 0 : Theme.barH + Theme.popupGap
    bottom: !vertical && atBottom ? Theme.barH + Theme.popupGap : 0
    right: vertical ? Theme.barW + Theme.popupGap : rightMargin
    left: Theme.barW + Theme.popupGap
  }
  exclusiveZone: -1   // 0 haría que el compositor lo empuje bajo la zona reservada de la barra (hueco doble)
  implicitWidth: panelWidth
  implicitHeight: col.implicitHeight + 32
  color: "transparent"
  WlrLayershell.namespace: "quickshell-popup"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  // Capa invisible a pantalla completa (debajo del panel, sin tapar la barra):
  // un click fuera del panel lo cierra. Más fiable que HyprlandFocusGrab con follow_mouse.
  PanelWindow {
    screen: win.screen
    visible: win.open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "quickshell-scrim"
    WlrLayershell.layer: WlrLayer.Top
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onPressed: PopupState.close()
    }
  }

  // aparición: baja 8 px y se hace opaco
  onVisibleChanged: if (visible) appear.restart()
  ParallelAnimation {
    id: appear
    NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.animMed * 0.8; easing.type: Easing.OutCubic }
    NumberAnimation { target: slide; property: win.vertical ? "x" : "y"; from: win.vertical ? (BarConfig.isRight ? 6 : -6) : win.atBottom ? 6 : -6; to: 0; duration: Theme.animMed; easing.type: Easing.OutCubic }
  }

  Rectangle {
    id: card
    anchors.fill: parent
    radius: Theme.radius
    color: Theme.glassPopup
    border.color: Theme.glassEdge
    border.width: Theme.borderWidth
    transform: Translate { id: slide }
    focus: true
    Keys.onEscapePressed: PopupState.close()

    ColumnLayout {
      id: col
      anchors { fill: parent; margins: 16 }
      spacing: 10

      Text {
        visible: win.title !== ""
        text: win.title
        color: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize + 4
        font.bold: true
        bottomPadding: 2
      }
    }
  }
}
