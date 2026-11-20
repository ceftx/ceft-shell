import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Suelta imágenes aquí -> WEBP junto al original (scripts/desk-convert.sh; notify-send al terminar).
DeskCard {
  id: card
  height: 196

  property int busy: 0          // archivos en proceso
  property string state: "idle" // idle | busy | done | error

  // file:///ruta%20con%20espacios -> /ruta con espacios (tolera % sueltos)
  function toPath(u) {
    let p = u.toString().trim()
    if (!p.startsWith("file://")) return ""
    p = p.substring(7)
    try { return decodeURIComponent(p) } catch (e) { return p }
  }

  DropArea {
    id: drop
    anchors.fill: parent
    // Sin `keys`: Dolphin/Nautilus mandan text/uri-list, Brave puede mandar text/plain o http(s); filtramos abajo.
    onEntered: drag => { drag.accepted = drag.hasUrls || drag.hasText }
    onDropped: drop => {
      const raw = drop.hasUrls ? Array.from(drop.urls) : (drop.text || "").split("\n")
      const files = raw.map(u => card.toPath(u)).filter(p => p !== "")
      if (files.length === 0) {   // p. ej. imagen arrastrada desde una web (http): no hay archivo local
        card.state = "error"; reset.restart(); return
      }
      drop.accept(Qt.CopyAction)
      card.busy = files.length
      card.state = "busy"
      conv.command = ["bash", Quickshell.shellDir + "/scripts/desk-convert.sh"].concat(files)
      conv.running = true
    }
  }

  Process {
    id: conv
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.match(/ok=(\d+)/)
        card.state = (m && parseInt(m[1]) > 0) ? "done" : "error"
        reset.restart()
      }
    }
    onExited: code => { if (code !== 0 && card.state === "busy") { card.state = "error"; reset.restart() } }
  }
  Timer { id: reset; interval: 3500; onTriggered: card.state = "idle" }

  Text {
    x: DeskTheme.pad; y: DeskTheme.pad - 4
    text: "PNG · JPG · AVIF · BMP · TIFF · GIF"
    font.family: DeskTheme.sans; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: 0.6
    color: DeskTheme.textFaint
  }

  // zona de soltar con borde discontinuo
  Item {
    id: zone
    x: DeskTheme.pad; y: 34
    width: card.width - DeskTheme.pad * 2; height: 104
    readonly property bool active: drop.containsDrag
    readonly property color tone: card.state === "error" ? Theme.active : card.state === "done" ? Theme.green : Theme.accent

    Rectangle {
      anchors.fill: parent
      radius: 20
      color: zone.active ? Qt.alpha(Theme.accent, 0.16) : card.state === "done" ? Qt.alpha(Theme.green, 0.12) : DeskTheme.tile
      Behavior on color { ColorAnimation { duration: Theme.animMed } }
      scale: zone.active ? 1.02 : 1
      Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
    }
    // borde discontinuo (segmentos)
    Canvas {
      id: dash
      anchors.fill: parent
      property color c: zone.active || card.state !== "idle" ? zone.tone : DeskTheme.textFaint
      onCChanged: requestPaint()
      onWidthChanged: requestPaint()
      onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = c
        ctx.lineWidth = 1.5
        ctx.setLineDash([6, 5])
        const r = 20, w = width - 1.5, h = height - 1.5, o = 0.75
        ctx.beginPath()
        ctx.moveTo(o + r, o); ctx.lineTo(o + w - r, o); ctx.arcTo(o + w, o, o + w, o + r, r)
        ctx.lineTo(o + w, o + h - r); ctx.arcTo(o + w, o + h, o + w - r, o + h, r)
        ctx.lineTo(o + r, o + h); ctx.arcTo(o, o + h, o, o + h - r, r)
        ctx.lineTo(o, o + r); ctx.arcTo(o, o, o + r, o, r)
        ctx.stroke()
      }
    }
    Column {
      anchors.centerIn: parent
      spacing: 4
      Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: card.state === "done" ? "check_circle" : card.state === "error" ? "error" : card.state === "busy" ? "sync" : zone.active ? "download" : "add_photo_alternate"
        fill: card.state === "idle" ? 0 : 1
        font.pixelSize: 32
        color: card.state === "idle" && !zone.active ? DeskTheme.textMuted : zone.tone
        RotationAnimation on rotation { running: card.state === "busy"; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
        Behavior on y { NumberAnimation { duration: 200 } }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        text: card.state === "busy" ? "Convirtiendo " + card.busy + (card.busy === 1 ? " imagen…" : " imágenes…")
            : card.state === "done" ? "Listo, junto al original"
            : card.state === "error" ? "No se pudo convertir"
            : zone.active ? "Soltá para convertir" : "Soltá imágenes acá"
        font.family: DeskTheme.sans; font.pixelSize: 13; font.weight: Font.Medium
        color: DeskTheme.text
      }
    }
  }

  Row {
    x: DeskTheme.pad; anchors.bottom: parent.bottom; anchors.bottomMargin: 16
    spacing: 8
    Text { text: "Convertir a"; anchors.verticalCenter: parent.verticalCenter; font.family: DeskTheme.sans; font.pixelSize: 14; color: DeskTheme.textMuted }
    Rectangle {
      height: 30; width: fmt.implicitWidth + 28; radius: 15
      color: Qt.alpha(Theme.accent, 0.18)
      Text { id: fmt; anchors.centerIn: parent; text: "WEBP"; font.family: DeskTheme.sans; font.pixelSize: 13; font.weight: Font.Bold; color: Theme.accent }
    }
  }
}
