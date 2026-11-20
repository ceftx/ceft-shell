import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import qs

DeskCard {
  id: card
  height: 156

  // Reproductor activo: el que suena, si no el primero
  readonly property var players: Mpris.players.values
  readonly property var player: {
    for (let i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
    return players.length > 0 ? players[0] : null
  }
  readonly property bool has: player !== null && (player.trackTitle !== "" || player.isPlaying)
  readonly property real len: player && player.lengthSupported ? player.length : 0
  readonly property real pos: player && player.positionSupported ? player.position : 0
  readonly property real frac: len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0
  function fmt(s) { const m = Math.floor(s / 60), r = Math.floor(s % 60); return m + ":" + (r < 10 ? "0" : "") + r }

  Timer {
    interval: 1000; repeat: true
    running: card.player !== null && card.player.isPlaying
    onTriggered: card.player.positionChanged()
  }

  // ── estado vacío ──
  Column {
    anchors.centerIn: parent
    spacing: 8
    visible: !card.has
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 56; height: 56; radius: 28; color: DeskTheme.tile
      Icon { anchors.centerIn: parent; name: "music_note"; font.pixelSize: 28; color: DeskTheme.textMuted; fill: 1 }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Nada sonando"
      font.family: DeskTheme.sans; font.pixelSize: 15; font.weight: Font.Medium
      color: DeskTheme.textMuted
    }
  }

  // ── reproduciendo ──
  Item {
    anchors.fill: parent
    visible: card.has
    opacity: card.has ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 240 } }

    Rectangle {
      id: art
      x: DeskTheme.pad; y: DeskTheme.pad - 2
      width: 92; height: 92; radius: 20
      color: DeskTheme.tile
      Image {
        id: artImg
        anchors.fill: parent
        source: card.player ? card.player.trackArtUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        layer.enabled: true
      }
      Rectangle { id: artMask; anchors.fill: parent; radius: art.radius; visible: false; layer.enabled: true }
      MultiEffect {
        anchors.fill: parent
        source: artImg
        maskEnabled: true
        maskSource: artMask
        opacity: artImg.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
      }
      Icon { anchors.centerIn: parent; name: "music_note"; fill: 1; font.pixelSize: 36; color: DeskTheme.textFaint; visible: artImg.status !== Image.Ready }
    }

    Column {
      x: art.x + art.width + 14; y: art.y + 2
      width: card.width - x - DeskTheme.pad
      spacing: 2
      Text {
        width: parent.width
        text: card.player ? (card.player.trackTitle || "Sin título") : ""
        elide: Text.ElideRight
        font.family: DeskTheme.sans; font.pixelSize: 16; font.weight: Font.DemiBold
        color: DeskTheme.text
      }
      Text {
        width: parent.width
        text: card.player ? (card.player.trackArtist || card.player.identity) : ""
        elide: Text.ElideRight
        font.family: DeskTheme.sans; font.pixelSize: 13
        color: DeskTheme.textMuted
      }
      Item { width: 1; height: 8 }
      Row {
        spacing: 6
        RoundButton { icon: "skip_previous"; iconFill: 1; size: 38; enabled: card.player && card.player.canGoPrevious; opacity: enabled ? 1 : 0.4; onClicked: card.player.previous() }
        RoundButton {
          icon: card.player && card.player.isPlaying ? "pause" : "play_arrow"
          primary: true; iconFill: 1; size: 42; iconSize: 24
          onClicked: card.player.togglePlaying()
        }
        RoundButton { icon: "skip_next"; iconFill: 1; size: 38; enabled: card.player && card.player.canGoNext; opacity: enabled ? 1 : 0.4; onClicked: card.player.next() }
      }
    }

    // progreso (click para saltar si el reproductor lo permite)
    Item {
      id: bar
      x: DeskTheme.pad; width: parent.width - DeskTheme.pad * 2
      y: parent.height - 26; height: 14
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 5; radius: 2.5; color: DeskTheme.tile }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * card.frac; height: 5; radius: 2.5
        color: Theme.accent
        Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
      }
      MouseArea {
        anchors.fill: parent
        enabled: card.player && card.player.canSeek && card.len > 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => { card.player.position = card.len * (m.x / width) }
      }
    }
  }
}
