import Quickshell
import QtQuick

// Una barra por monitor (shell.qml la instancia con `screen`). La ventana (BarWindow) se recrea al cambiar de posición:
// cambiar entre anclajes de borde distintos (p. ej. abajo -> izquierda) dejaba la superficie con el tamaño anterior.
Scope {
  id: root
  property var screen: null

  Loader {
    id: win
    active: true
    property string key: BarConfig.position
    onKeyChanged: { active = false; Qt.callLater(() => { win.active = true }) }
    sourceComponent: BarWindow { screen: root.screen }
  }
}
