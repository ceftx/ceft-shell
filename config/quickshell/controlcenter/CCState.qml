pragma Singleton
import Quickshell
import QtQuick

// Estado de apertura de la ventana (lo comparten ControlCenter y las páginas).
Singleton {
  property bool open: false
  property string tab: "quick"
}
