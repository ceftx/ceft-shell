import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Módulo "media": reproductor MPRIS compacto. Click: play/pausa · rueda: siguiente/anterior.
// Oculto si no hay reproductor con algo cargado.
Item {
  id: root
  property bool vertical: false
  readonly property var players: Mpris.players.values
  readonly property var player: {
    for (let i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
    return players.length > 0 ? players[0] : null
  }
  readonly property bool has: player !== null && (player.trackTitle !== "" || player.isPlaying)
  readonly property string label: !player ? "" : [player.trackTitle || "Sin título", player.trackArtist].filter(s => s).join(" · ")

  readonly property real natural: icon.implicitWidth + 6 + metrics.advanceWidth
  implicitWidth: has ? (vertical ? icon.implicitWidth : Math.min(natural, 280)) : 0
  implicitHeight: vertical ? (has ? icon.implicitHeight + 8 : 0) : Theme.barH - 12
  property real wheelAcc: 0

  TextMetrics {
    id: metrics
    text: root.label
    font.family: Theme.fontSans; font.pixelSize: Theme.fontBase; font.weight: Font.Medium
  }

  Rectangle {
    anchors.centerIn: parent
    width: parent.width + (root.vertical ? 12 : 16); height: parent.height - 4; radius: height / 2
    color: area.containsMouse ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }
  Text {
    id: icon
    anchors { left: root.vertical ? undefined : parent.left; horizontalCenter: root.vertical ? parent.horizontalCenter : undefined; verticalCenter: parent.verticalCenter }
    text: Theme.sym(root.player && root.player.isPlaying ? "pause" : "play_arrow")
    color: root.player && root.player.isPlaying ? Theme.accent : Theme.muted
    font.family: Theme.iconFont; font.pixelSize: 19
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }
  Text {
    visible: !root.vertical
    anchors { left: icon.right; leftMargin: 6; right: parent.right; verticalCenter: parent.verticalCenter }
    text: root.label
    elide: Text.ElideRight
    color: Theme.barText
    font.family: Theme.fontSans; font.pixelSize: Theme.fontBase; font.weight: Font.Medium
  }
  MouseArea {
    id: area
    anchors.fill: parent; anchors.margins: -4
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
    onWheel: wheel => {
      root.wheelAcc += wheel.angleDelta.y
      if (Math.abs(root.wheelAcc) < 120 || !root.player) return
      if (root.wheelAcc > 0) { if (root.player.canGoNext) root.player.next() }
      else if (root.player.canGoPrevious) root.player.previous()
      root.wheelAcc = 0
    }
  }
}
