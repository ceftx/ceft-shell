import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.services

// Popups de notificaciones: esquina superior derecha bajo la barra (o inferior derecha si la barra está abajo);
// con barra vertical, esquina superior del lado contrario a la barra,
// en el monitor con foco. Apilados, con barra de tiempo (pausa al pasar el mouse); las críticas no expiran solas.
// Con "no molestar" Notifs solo encola las críticas.
Scope {
  id: root
  readonly property string focusedName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  readonly property var targetScreen: Quickshell.screens.find(s => s.name === focusedName) ?? Quickshell.screens[0]

  PanelWindow {
    id: win
    screen: root.targetScreen
    readonly property bool atBottom: BarConfig.isBottom
    visible: Notifs.popups.count > 0 || hold.running
    readonly property bool vertical: BarConfig.vertical
    readonly property bool onLeft: BarConfig.isRight          // barra a la derecha: las notificaciones van a la izquierda
    anchors { top: true; bottom: true; right: !onLeft; left: onLeft }
    margins {
      top: vertical ? 10 : atBottom ? 0 : Theme.barH + Theme.popupGap
      bottom: !vertical && atBottom ? Theme.barH + Theme.popupGap : 0
      right: 10
      left: 10
    }
    exclusiveZone: -1
    implicitWidth: 392
    color: "transparent"
    WlrLayershell.namespace: "quickshell-notif"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Solo el área de las tarjetas recibe el mouse; el resto de la ventana (alto completo) es transparente al input
    mask: Region { item: list }

    Timer { id: hold; interval: 400 }
    Connections { target: Notifs.popups; function onCountChanged() { hold.restart() } }

    ListView {
      id: list
      anchors { left: parent.left; right: parent.right }
      anchors.top: win.atBottom && !win.vertical ? undefined : parent.top
      anchors.bottom: win.atBottom && !win.vertical ? parent.bottom : undefined
      height: contentHeight
      interactive: false
      spacing: 8
      verticalLayoutDirection: win.atBottom && !win.vertical ? ListView.BottomToTop : ListView.TopToBottom
      model: Notifs.popups

      add: Transition {
        ParallelAnimation {
          NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animMed; easing.type: Easing.OutCubic }
          NumberAnimation { property: "x"; from: win.onLeft ? -70 : 70; to: 0; duration: Theme.animMed; easing.type: Easing.OutCubic }
        }
      }
      remove: Transition {
        ParallelAnimation {
          NumberAnimation { property: "opacity"; to: 0; duration: Theme.animMed; easing.type: Easing.InCubic }
          NumberAnimation { property: "x"; to: win.onLeft ? -70 : 70; duration: Theme.animMed; easing.type: Easing.InCubic }
        }
      }
      displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.animMed; easing.type: Easing.OutCubic } }

      delegate: Item {
        id: d
        required property int nid
        readonly property var entry: Notifs.byId(nid)
        readonly property int life: {
          if (!entry || entry.urgency === "critical") return 0
          if (entry.expire > 0) return Math.max(4000, Math.min(15000, entry.expire))
          return entry.urgency === "low" ? 4000 : 7000
        }
        width: ListView.view.width
        height: card.implicitHeight
        visible: entry !== null

        NotifCard {
          id: card
          width: parent.width
          entry: d.entry ?? ({ id: -1, appName: "", appIcon: "", image: "", summary: "", body: "", time: 0, urgency: "normal", actions: [], live: false, read: true })
          popup: true
          progress: d.life > 0 ? life.progress : -1
          onDismissed: Notifs.hidePopup(d.nid)
          onActivated: Notifs.markRead(d.nid)
        }

        QtObject { id: life; property real progress: 1 }
        NumberAnimation {
          target: life; property: "progress"; from: 1; to: 0
          duration: d.life
          running: d.life > 0
          paused: card.hovered
          onFinished: Notifs.hidePopup(d.nid)
        }
      }
    }
  }
}
