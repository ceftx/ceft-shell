import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Menú de sesión (bloquear / suspender / reiniciar / apagar / cerrar sesión). Se abre con PowerGuard.openMenu().
// Las acciones destructivas pasan por PowerGuard.request (aviso si hay cosas en curso).
Variants {
  model: Quickshell.screens
  PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    visible: PowerGuard.menuOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Qt.alpha("#000000", 0.35 * fade.opacity)
    WlrLayershell.namespace: "quickshell-powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: PowerGuard.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: if (visible) { fade.opacity = 0; appear.restart(); card.forceActiveFocus() }

    readonly property var entries: [
      { icon: "lock",               label: "Bloquear",      act: () => PowerGuard.lock(),                danger: false },
      { icon: "bedtime",            label: "Suspender",     act: () => PowerGuard.request("suspend"),    danger: false },
      { icon: "restart_alt",        label: "Reiniciar",     act: () => PowerGuard.request("reboot"),     danger: false },
      { icon: "power_settings_new", label: "Apagar",        act: () => PowerGuard.request("poweroff"),   danger: true  },
      { icon: "logout",             label: "Cerrar sesión", act: () => PowerGuard.request("logout"),     danger: false }
    ]

    Item {
      id: fade
      anchors.fill: parent
      opacity: 0
      NumberAnimation { id: appear; target: fade; property: "opacity"; from: 0; to: 1; duration: Theme.animMed; easing.type: Easing.OutCubic }
      MouseArea { anchors.fill: parent; onClicked: PowerGuard.closeMenu() }

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: 280
        height: col.implicitHeight + 24
        radius: Theme.radius
        color: Theme.glassPopup
        border.color: Theme.glassEdge; border.width: Theme.borderWidth
        focus: true
        Keys.onEscapePressed: PowerGuard.closeMenu()
        transform: Translate { y: (1 - fade.opacity) * 10 }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
          id: col
          anchors { fill: parent; margins: 12 }
          spacing: 4
          Text {
            text: "Sistema"
            color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 3; font.bold: true
            leftPadding: 8; topPadding: 2; bottomPadding: 6
          }
          Repeater {
            model: win.entries
            Rectangle {
              id: row
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: 40
              radius: Theme.radiusSmall
              color: ma.containsMouse ? (modelData.danger ? Qt.alpha(Theme.active, 0.22) : Theme.hover) : "transparent"
              Behavior on color { ColorAnimation { duration: Theme.animFast } }
              RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12
                Text {
                  text: row.modelData.icon
                  font.family: Theme.iconFont; font.pixelSize: 22
                  color: row.modelData.danger && ma.containsMouse ? Theme.active : Theme.foreground
                }
                Text {
                  Layout.fillWidth: true
                  text: row.modelData.label
                  color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1
                }
              }
              MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { PowerGuard.closeMenu(); row.modelData.act() }
              }
            }
          }
        }
      }
    }
  }
}
