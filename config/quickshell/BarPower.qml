import Quickshell
import QtQuick

// Módulo "power": botón circular que abre el menú de sesión (PowerMenu). Apagar/reiniciar/suspender/cerrar sesión
// pasan por PowerGuard (aviso si hay bloqueos).
Item {
  property bool vertical: false
  implicitWidth: Theme.barH - 12
  implicitHeight: Theme.barH - 12

  BarText {
    anchors.centerIn: parent
    symbol: true
    text: Theme.sym("power_settings_new")
    pill: false
    color: powerHover.hovered ? Theme.active : Theme.foreground
    onClicked: PowerGuard.openMenu()
    HoverHandler { id: powerHover }
  }
}
