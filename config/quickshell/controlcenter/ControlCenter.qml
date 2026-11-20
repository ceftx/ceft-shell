import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Centro de control: ventana flotante centrada (1100x720) sobre un velo.
//   qs ipc call controlcenter open | close | toggle | openTab <rapido|apariencia|barra|escritorio|interfaz|hyprland|atajos|servicios|perfil|sistema>
Scope {
  id: root

  readonly property var tabs: [
    { id: "quick",      name: "Rápido",     icon: "bolt",        file: "QuickPage.qml" },
    { id: "appearance", name: "Apariencia", icon: "palette",     file: "AppearancePage.qml" },
    { id: "bar",        name: "Barra",      icon: "toolbar",     file: "BarPage.qml" },
    { id: "desktop",    name: "Escritorio", icon: "dashboard",   file: "DesktopPage.qml" },
    { id: "interface",  name: "Interfaz",   icon: "tune",        file: "InterfacePage.qml" },
    { id: "hyprland",   name: "Hyprland",   icon: "web_asset",   file: "HyprlandPage.qml" },
    { id: "shortcuts",  name: "Atajos",     icon: "keyboard",    file: "ShortcutsPage.qml" },
    { id: "services",   name: "Servicios",  icon: "cloud_sync",  file: "ServicesPage.qml" },
    { id: "profile",    name: "Perfil",     icon: "account_circle", file: "ProfilePage.qml" },
    { id: "system",     name: "Sistema",    icon: "settings",    file: "SystemPage.qml" }
  ]
  readonly property var aliases: ({
    rapido: "quick", apariencia: "appearance", barra: "bar", escritorio: "desktop", interfaz: "interface",
    ventanas: "hyprland", windows: "hyprland", atajos: "shortcuts", servicios: "services", perfil: "profile", sistema: "system"
  })
  readonly property int tabIndex: Math.max(0, tabs.findIndex(t => t.id === CCState.tab))

  function openTab(name) {
    const id = aliases[name] ?? name
    if (tabs.some(t => t.id === id)) CCState.tab = id
    CCState.open = true
  }

  IpcHandler {
    target: "controlcenter"
    function open(): void { CCState.open = true }
    function close(): void { CCState.open = false }
    function toggle(): void { CCState.open = !CCState.open }
    function openTab(name: string): void { root.openTab(name) }
    // Desplaza la página actual (útil para capturas / pruebas)
    function scroll(px: int): void {
      const f = pageLoader.item?.flick
      if (f) f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, px))
    }
  }

  // 0..1 animado: aparición y desaparición
  property real shown: CCState.open ? 1 : 0
  Behavior on shown { NumberAnimation { duration: CCState.open ? 240 : 160; easing.type: Easing.OutCubic } }
  readonly property bool mapped: CCState.open || shown > 0.001

  readonly property var targetScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

  // ── velo (sin blur: namespace distinto) ──
  PanelWindow {
    screen: root.targetScreen
    visible: root.mapped
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Qt.rgba(0, 0, 0, 0.30 * root.shown)
    WlrLayershell.namespace: "quickshell-controlcenter-scrim"
    // Capa Top (debajo de Overlay): si velo y ventana comparten capa, el compositor puede apilar
    // el velo encima y cada click "dentro" de la ventana la cerraba. Igual que BarPopup.
    WlrLayershell.layer: WlrLayer.Top
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: CCState.open = false }
  }

  // ── ventana ──
  PanelWindow {
    id: win
    screen: root.targetScreen
    visible: root.mapped
    implicitWidth: 1100
    implicitHeight: 720
    exclusiveZone: -1   // 0 la centraría en el área libre bajo la barra; -1 la centra en la pantalla
    color: "transparent"
    WlrLayershell.namespace: "quickshell-controlcenter"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: CCState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    FocusScope {
      id: card
      anchors.fill: parent
      focus: true
      opacity: root.shown
      scale: 0.965 + 0.035 * root.shown
      transformOrigin: Item.Center
      Keys.onEscapePressed: CCState.open = false

      Rectangle {
        anchors.fill: parent
        radius: 30
        color: Qt.alpha(Theme.background, 0.86)
        border.width: 1
        border.color: Theme.glassEdge
      }

      // ── menú lateral ──
      Item {
        id: side
        width: 256
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }

        ColumnLayout {
          anchors { fill: parent; margins: 18 }
          spacing: 0

          // perfil
          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 12
            Rectangle {
              Layout.preferredWidth: 48; Layout.preferredHeight: 48
              radius: 24
              color: Theme.accentContainer
              clip: true
              CircleImage {
                id: avatar
                anchors.fill: parent
                source: CCStore.avatarOk ? "file://" + CCStore.avatarPath + "?v=" + CCStore.avatarRev : ""
                px: 96
              }
              Text {
                visible: !avatar.ready
                anchors.centerIn: parent
                text: userName.text.charAt(0).toUpperCase()
                color: Theme.accent
                font.family: Theme.fontSans
                font.pixelSize: 20
                font.weight: Font.DemiBold
              }
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1
              Text {
                id: userName
                Layout.fillWidth: true
                text: (CCStore.w.profile?.name ?? "") !== "" ? CCStore.w.profile.name : Quickshell.env("USER")
                elide: Text.ElideRight
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 17
                font.weight: Font.DemiBold
              }
              Text {
                Layout.fillWidth: true
                text: Quickshell.env("USER") + "@" + host.t
                elide: Text.ElideRight
                color: DeskTheme.textFaint
                font.family: Theme.fontSans
                font.pixelSize: 12
              }
            }
          }
          Rectangle { Layout.fillWidth: true; Layout.topMargin: 16; Layout.bottomMargin: 14; height: 1; color: Theme.hairline }

          CCButton {
            Layout.fillWidth: true
            implicitHeight: 44
            icon: "edit_document"
            label: "Editar archivos"
            onClicked: { run.run("setsid -f kitty --title ceft-settings -e " + CCStore.cli + " edit settings >/dev/null 2>&1"); CCState.open = false }
          }

          // navegación
          Item {
            Layout.fillWidth: true
            Layout.topMargin: 18
            implicitHeight: root.tabs.length * 46
            Rectangle {
              id: hl
              width: parent.width
              height: 42
              radius: 21
              y: root.tabIndex * 46
              color: Theme.accentContainer
              Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
            }
            Repeater {
              model: root.tabs
              Item {
                id: navItem
                required property var modelData
                required property int index
                readonly property bool active: CCState.tab === modelData.id
                y: index * 46
                width: parent.width
                height: 42
                Rectangle {
                  anchors.fill: parent
                  radius: 21
                  color: Theme.hover
                  opacity: !navItem.active && nma.containsMouse ? 1 : 0
                  Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                }
                Row {
                  anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                  spacing: 14
                  Icon {
                    name: navItem.modelData.icon
                    fill: navItem.active ? 1 : 0
                    font.pixelSize: 22
                    color: navItem.active ? Theme.accent : DeskTheme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                  }
                  Text {
                    text: navItem.modelData.name
                    color: navItem.active ? Theme.foreground : DeskTheme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: 14
                    font.weight: navItem.active ? Font.DemiBold : Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                  }
                }
                MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: CCState.tab = navItem.modelData.id }
              }
            }
          }

          Item { Layout.fillHeight: true }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
              implicitWidth: esc.implicitWidth + 14; implicitHeight: 22
              radius: 7
              color: Qt.alpha(Theme.foreground, 0.09)
              border.width: 1; border.color: Qt.alpha(Theme.foreground, 0.14)
              Text { id: esc; anchors.centerIn: parent; text: "Esc"; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 11; font.weight: Font.DemiBold }
            }
            Text {
              text: "para cerrar"
              color: DeskTheme.textFaint
              font.family: Theme.fontSans
              font.pixelSize: 12
            }
          }
        }
      }

      // separador vertical
      Rectangle { x: side.width; y: 22; width: 1; height: parent.height - 44; color: Theme.hairline }

      // ── contenido ──
      Item {
        id: contentArea
        anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 30; rightMargin: 12; topMargin: 28; bottomMargin: 18 }
        clip: true

        Loader {
          id: pageLoader
          anchors.fill: parent
          active: root.mapped
          source: root.tabs[root.tabIndex].file
          onSourceChanged: enter.restart()
          ParallelAnimation {
            id: enter
            NumberAnimation { target: pageLoader; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: pageLoader; property: "anchors.topMargin"; from: 12; to: 0; duration: 240; easing.type: Easing.OutCubic }
          }
        }

        // aviso de guardado / aplicado
        Rectangle {
          id: toast
          anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
          implicitWidth: toastRow.implicitWidth + 32
          implicitHeight: 38
          radius: 19
          color: Qt.alpha(Theme.surface, 0.97)
          border.width: 1
          border.color: CCStore.toastErr ? Qt.alpha(Theme.yellow, 0.7) : Qt.alpha(Theme.accent, 0.5)
          opacity: 0
          visible: opacity > 0.01
          property real lift: 10
          transform: Translate { y: toast.lift }
          Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8
            Icon {
              name: CCStore.toastErr ? "warning" : "check_circle"
              fill: 1
              font.pixelSize: 19
              color: CCStore.toastErr ? Theme.yellow : Theme.accent
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: CCStore.toast
              color: Theme.foreground
              font.family: Theme.fontSans
              font.pixelSize: 13
              font.weight: Font.Medium
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          SequentialAnimation {
            id: toastAnim
            ParallelAnimation {
              NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 160 }
              NumberAnimation { target: toast; property: "lift"; to: 0; duration: 220; easing.type: Easing.OutCubic }
            }
            PauseAnimation { duration: 2600 }
            ParallelAnimation {
              NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 260 }
              NumberAnimation { target: toast; property: "lift"; to: 10; duration: 260 }
            }
          }
          Connections {
            target: CCStore
            function onToastSeqChanged() { toastAnim.restart() }
          }
        }
      }
    }
  }

  CCRun { id: run }
  FileView {
    id: hostFile
    path: "/proc/sys/kernel/hostname"
    onLoaded: host.t = text().trim()
  }
  QtObject { id: host; property string t: "" }
}
