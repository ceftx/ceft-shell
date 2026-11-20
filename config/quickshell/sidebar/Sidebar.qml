import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Panel lateral derecho: ajustes rápidos, sliders, mezclador por app, luz nocturna y notificaciones.
//   qs ipc call sidebar toggle | open | close
// Velo en capa Top (no tapa la barra) y panel en Overlay: en la misma capa el velo tapaba el panel.
Scope {
  id: root

  property bool open: false
  property real shown: open ? 1 : 0
  Behavior on shown { NumberAnimation { duration: root.open ? Theme.animMed : Theme.animFast; easing.type: Easing.OutCubic } }
  readonly property bool mapped: open || shown > 0.001
  readonly property var targetScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
  property string section: ""        // "" | "mixer" | "night"
  property bool awake: false
  // Lado: a la derecha, salvo con la barra vertical a la derecha (entonces a la izquierda, sin superponerse)
  readonly property bool onLeft: BarConfig.isRight

  IpcHandler {
    target: "sidebar"
    function toggle(): void { root.open = !root.open }
    function open(): void { root.open = true }
    function close(): void { root.open = false }
    function awake(on: bool): void { root.awake = on }
    function section(name: string): void { root.section = name === "mixer" || name === "night" ? name : ""; root.open = true }   // atajo y pruebas
  }

  onOpenChanged: {
    SideNet.watching = open
    if (open) { SideNet.refresh(); Night.refresh(); GameMode.refresh(); Brightness.refresh(); PopupState.close(); side.forceActiveFocusSoon(); markTimer.restart() }
    else head.powerOpen = false
  }

  Timer { id: markTimer; interval: 1500; onTriggered: if (root.open && root.nb) root.nb.markAllRead() }   // las ve al abrir el panel
  KeepAwake { id: keep; on: root.awake }
  Component.onCompleted: Night.refresh()

  // ── servicio de notificaciones (de otro módulo): se activa cuando los archivos existen ──
  property bool notifsReady: false
  FileView {
    id: probeA
    path: Quickshell.shellPath("services/Notifs.qml")
    onLoaded: root.notifsReady = probeB.ok
    onLoadFailed: root.notifsReady = false
  }
  FileView {
    id: probeB
    property bool ok: false
    path: Quickshell.shellPath("services/NotificationList.qml")
    onLoaded: { ok = true; probeA.reload() }
    onLoadFailed: ok = false
  }
  Loader { id: bridge; active: root.notifsReady; source: "NotifBridge.qml" }
  readonly property var nb: bridge.item

  // ── velo ──
  PanelWindow {
    screen: root.targetScreen
    visible: root.mapped
    anchors { top: true; bottom: true; left: true; right: true }
    color: Qt.rgba(0, 0, 0, 0.22 * root.shown)
    WlrLayershell.namespace: "quickshell-sidebar-scrim"
    WlrLayershell.layer: WlrLayer.Top
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.open = false }
  }

  // ── panel ──
  PanelWindow {
    id: win
    screen: root.targetScreen
    visible: root.mapped
    anchors { top: true; bottom: true; right: !root.onLeft; left: root.onLeft }
    margins { top: 6; bottom: 10; right: 10; left: 10 }
    implicitWidth: 420 + 24
    color: "transparent"
    WlrLayershell.namespace: "quickshell-sidebar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    FocusScope {
      id: side
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.open = false
      function forceActiveFocusSoon() { fTimer.restart() }
      Timer { id: fTimer; interval: 30; onTriggered: side.forceActiveFocus() }

      // zona transparente (margen de sombra) también cierra
      MouseArea { anchors.fill: parent; onPressed: root.open = false }

      Rectangle {
        id: card
        width: 420
        anchors { top: parent.top; bottom: parent.bottom; right: root.onLeft ? undefined : parent.right; left: root.onLeft ? parent.left : undefined }
        radius: Theme.radius + 4
        color: Theme.glassPopup
        border.width: Theme.borderWidth
        border.color: Theme.glassEdge
        opacity: root.shown
        transform: Translate { x: (1 - root.shown) * (root.onLeft ? -36 : 36) }
        MouseArea { anchors.fill: parent }   // no propagar clics al cierre

        ColumnLayout {
          anchors { fill: parent; margins: 16 }
          spacing: 12

          SideHeader { id: head; Layout.fillWidth: true; onCloseRequested: root.open = false }

          Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }

          // ── controles (se desplazan si no caben; las notificaciones se quedan con el resto) ──
          Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(controls.implicitHeight, card.height * 0.66)
            contentHeight: controls.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

            ColumnLayout {
              id: controls
              width: flick.width
              spacing: 14

              QuickControls { Layout.fillWidth: true; sb: root }

              // ── pestañas Mezclador / Luz nocturna ──
              RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                  model: [
                    { id: "mixer", ic: "tune", l: "Mezclador" },
                    { id: "night", ic: "nightlight", l: "Luz nocturna" }
                  ]
                  Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool cur: root.section === modelData.id
                    Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 20
                    color: cur ? Theme.accentContainer : tma.containsMouse ? DeskTheme.tileHover : DeskTheme.tile
                    border.width: cur ? 1 : 0; border.color: Qt.alpha(Theme.accent, 0.5)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Row {
                      anchors.centerIn: parent; spacing: 8
                      Icon { name: tab.modelData.ic; fill: tab.cur ? 1 : 0; font.pixelSize: 19; color: tab.cur ? Theme.accent : DeskTheme.text; anchors.verticalCenter: parent.verticalCenter }
                      Text {
                        text: tab.modelData.l + (tab.modelData.id === "mixer" && mixer.streamCount > 0 ? " · " + mixer.streamCount : "")
                        color: DeskTheme.text; font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Icon { name: tab.cur ? "expand_less" : "expand_more"; font.pixelSize: 18; color: DeskTheme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.section = tab.cur ? "" : tab.modelData.id }
                  }
                }
              }

              Item {
                Layout.fillWidth: true
                implicitHeight: root.section === "" ? 0 : (root.section === "mixer" ? mixer.implicitHeight : night.implicitHeight)
                clip: true
                Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
                Mixer { id: mixer; width: parent.width; opacity: root.section === "mixer" ? 1 : 0; visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: Theme.animFast } } }
                NightPanel { id: night; width: parent.width; opacity: root.section === "night" ? 1 : 0; visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: Theme.animFast } } }
              }
            }
          }

          Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }

          // ── notificaciones ──
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 150
            Loader { anchors.fill: parent; active: root.notifsReady; source: "NotifPane.qml" }
            ColumnLayout {   // marcador mientras el servicio de notificaciones no existe
              visible: !root.notifsReady
              anchors.centerIn: parent
              spacing: 6
              Icon { Layout.alignment: Qt.AlignHCenter; name: "notifications_off"; font.pixelSize: 30; color: DeskTheme.textFaint }
              Text { Layout.alignment: Qt.AlignHCenter; text: "Notificaciones no disponibles todavía"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12 }
            }
          }
        }
      }
    }
  }
}
