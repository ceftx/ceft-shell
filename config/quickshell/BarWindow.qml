import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Barra guiada por ~/.config/ceft-shell/bar.json (ver BarConfig.qml y BarSlot.qml: registro de módulos).
//   position  top | bottom | left | right        style  hug | float | islands       autohide, groupBackground, showBackground, divider
// Zonas: izquierda y derecha pegadas a los bordes; el centro queda centrado en pantalla
// (con "workspaces" en el centro, ese módulo es el eje y los lados se igualan para que quede exacto).
// Vertical (left | right): ancho Theme.barW, alto completo; las zonas pasan a ser arriba / centro / abajo (BarColumn).
PanelWindow {
  id: bar
  readonly property bool atBottom: BarConfig.isBottom
  readonly property bool vertical: BarConfig.vertical
  readonly property bool atRight: BarConfig.isRight
  readonly property string barStyle: BarConfig.style

  // ── Autohide: la ventana se encoge a una franja sensible de pocos px; reaparece al acercar el puntero
  // o al abrir un popup. Sin zona exclusiva mientras está oculta.
  readonly property int stripPx: 3
  property bool kept: false                    // se mantiene un instante tras salir el puntero
  property bool collapsed: false
  readonly property bool shown: !BarConfig.autohide || hover.hovered || kept || PopupState.current !== ""
  property real slide: shown ? 0 : BarConfig.thickness + 2
  Behavior on slide { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

  function sync() {
    if (shown || !BarConfig.autohide) { collapseTimer.stop(); collapsed = false }
    else collapseTimer.restart()
  }
  onShownChanged: sync()
  Connections { target: BarConfig; function onAutohideChanged() { bar.sync() } }
  Component.onCompleted: sync()
  Timer { id: collapseTimer; interval: Theme.animSlow + 60; onTriggered: bar.collapsed = BarConfig.autohide && !bar.shown }
  Timer { id: leaveTimer; interval: 450; onTriggered: bar.kept = false }

  anchors {
    top: vertical || !atBottom; bottom: vertical || atBottom
    left: !vertical || !atRight; right: !vertical || atRight
  }
  // El tamaño del eje largo es concreto (no 0): al cambiar de orientación Qt no se queda con el tamaño anterior
  implicitHeight: vertical ? screen.height : collapsed ? stripPx : Theme.barH
  implicitWidth: vertical ? (collapsed ? stripPx : Theme.barW) : screen.width
  exclusiveZone: BarConfig.autohide ? 0 : BarConfig.thickness
  color: "transparent"
  WlrLayershell.namespace: "quickshell-bar"

  Item {
    id: frame
    anchors.fill: parent
    HoverHandler {
      id: hover
      onHoveredChanged: {
        if (hovered) { bar.kept = true; leaveTimer.stop() }
        else leaveTimer.restart()
      }
    }

    // Contenido: alto fijo de la barra; se desliza fuera del borde al ocultarse
    Item {
      id: content
      width: bar.vertical ? Theme.barW : parent.width
      height: bar.vertical ? parent.height : Theme.barH
      anchors.left: bar.vertical && !bar.atRight ? parent.left : undefined
      anchors.right: bar.vertical && bar.atRight ? parent.right : undefined
      anchors.top: bar.vertical || !bar.atBottom ? parent.top : undefined
      anchors.bottom: !bar.vertical && bar.atBottom ? parent.bottom : undefined
      anchors.topMargin: bar.vertical ? 0 : -bar.slide
      anchors.bottomMargin: -bar.slide
      anchors.leftMargin: -bar.slide
      anchors.rightMargin: -bar.slide

      // Fondo: vidrio sutil a todo el ancho (el blur lo pide Hyprland al namespace). hug = pegada, algo más
      // opaca y sin filo; float = la de siempre, con filo tenue hacia las ventanas; islands = sin barra.
      Rectangle {
        anchors.fill: parent
        visible: BarConfig.showBackground && bar.barStyle !== "islands"
        color: bar.barStyle === "hug" ? Qt.alpha(Theme.background, Math.min(1, Theme.barAlpha + 0.2)) : Theme.barBg
        Behavior on color { ColorAnimation { duration: Theme.animMed } }
        Rectangle {
          visible: bar.barStyle === "float"
          x: bar.vertical && !bar.atRight ? parent.width - width : 0
          y: !bar.vertical && !bar.atBottom ? parent.height - height : 0
          width: bar.vertical ? Theme.borderWidth : parent.width
          height: bar.vertical ? parent.height : Theme.borderWidth
          color: Theme.barEdge
        }
      }

      Loader {
        anchors.fill: parent
        active: !BarConfig.vertical
        sourceComponent: BarRow { barWin: bar }
      }
      Loader {
        anchors.fill: parent
        active: BarConfig.vertical
        sourceComponent: BarColumn { barWin: bar }
      }
    }
  }
}
