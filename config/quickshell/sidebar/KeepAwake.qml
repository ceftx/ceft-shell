import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Mantener despierto: inhibidor de idle de Wayland (hypridle lo respeta). Necesita una superficie visible:
// una ventana de 1x1 px transparente que solo existe mientras está activo.
Scope {
  id: root
  property bool on: false
  // Segundo seguro: inhibidor de idle de logind (hypridle también lo respeta).
  Process {
    running: root.on
    command: ["systemd-inhibit", "--what=idle", "--who=ceft-shell", "--why=Mantener despierto", "--mode=block", "sleep", "infinity"]
  }
  PanelWindow {
    id: win
    visible: root.on
    anchors { top: true; left: true }
    implicitWidth: 1; implicitHeight: 1
    exclusiveZone: -1
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "quickshell-sidebar-awake"
    WlrLayershell.layer: WlrLayer.Background
    IdleInhibitor { enabled: root.on && win.visible; window: win }
  }
}
