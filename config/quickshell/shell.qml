//@ pragma UseQApplication
import Quickshell
import QtQuick
import qs.desktop
import qs.controlcenter
import qs.launcher
import qs.overview
import qs.screenshot
import qs.services
import qs.sidebar
import qs.taskmgr

// Barra estilo Omarchy: una por monitor.
//   izquierda: menú + workspaces
//   centro:    reloj ("dddd HH:mm", click alterna fecha)
//   derecha:   tray, bluetooth, red, audio, batería, power
ShellRoot {
  NetSettings {}
  TaskManager {}
  Desktop {}
  ControlCenter {}
  Launcher {}
  Overview {}
  Sidebar {}
  WallRotator {}
  PowerDialog {}
  PowerMenu {}
  NotifPopups {}
  Osd {}
  Screenshot {}
  Variants {
    model: Quickshell.screens
    Bar {
      required property var modelData
      screen: modelData
    }
  }
}
