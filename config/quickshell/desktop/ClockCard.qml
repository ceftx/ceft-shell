import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Hora grande + fecha larga + relojes del mundo (2x2: el primero es la hora local)
DeskCard {
  id: card
  height: col.implicitHeight + DeskTheme.pad * 2

  readonly property var days: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
  readonly property var months: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
  readonly property date now: clock.date
  readonly property string dateText: {
    const s = days[now.getDay()] + ", " + now.getDate() + " de " + months[now.getMonth()]
    return s.charAt(0).toUpperCase() + s.slice(1)
  }
  function pad(n) { return (n < 10 ? "0" : "") + n }
  readonly property string hh: pad(now.getHours())
  readonly property string mm: pad(now.getMinutes())
  readonly property int ymd: now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate()

  SystemClock { id: clock; precision: SystemClock.Seconds }

  // Zonas: la 1ª es local (sin TZ). Máximo 3 relojes del mundo.
  readonly property var zones: DeskConfig.worldClocks.slice(0, 3)
  property var remote: []   // [{time, off, ymd}]

  Process {
    id: tzProc
    command: ["sh", "-c", "for tz in \"$@\"; do TZ=\"$tz\" date '+%H:%M %z %Y%m%d'; done", "sh"].concat(card.zones.map(z => z.tz))
    stdout: StdioCollector {
      onStreamFinished: {
        card.remote = text.trim().split("\n").filter(l => l).map(l => {
          const p = l.split(" ")
          const sign = p[1].charAt(0), h = parseInt(p[1].substr(1, 2)), m = parseInt(p[1].substr(3, 2))
          return { time: p[0], off: "UTC" + sign + h + (m ? ":" + (m < 10 ? "0" : "") + m : ""), ymd: parseInt(p[2]) }
        })
      }
    }
  }
  // refresca al cambiar el minuto
  onMmChanged: tzProc.running = true
  Component.onCompleted: tzProc.running = true
  onZonesChanged: tzProc.running = true

  readonly property var cells: {
    const out = [{ city: DeskConfig.city || "Local", time: hh + ":" + mm, off: "", ymd: ymd }]
    for (let i = 0; i < zones.length; i++) {
      const r = remote[i]
      out.push({ city: zones[i].city, time: r ? r.time : "--:--", off: r ? r.off : "", ymd: r ? r.ymd : ymd })
    }
    return out
  }

  Column {
    id: col
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeskTheme.pad }
    spacing: 4

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 0
      Text {
        text: card.hh
        font.family: DeskTheme.sans; font.pixelSize: 76; font.weight: Font.Medium; font.letterSpacing: -2
        color: DeskTheme.text
      }
      Text {
        id: colon
        text: ":"
        font.family: DeskTheme.sans; font.pixelSize: 76; font.weight: Font.Light
        color: Theme.accent
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -4
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        }
      }
      Text {
        text: card.mm
        font.family: DeskTheme.sans; font.pixelSize: 76; font.weight: Font.Medium; font.letterSpacing: -2
        color: DeskTheme.text
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: card.dateText
      font.family: DeskTheme.sans; font.pixelSize: 15; font.weight: Font.Medium
      color: DeskTheme.textMuted
    }
    Item { width: 1; height: 12 }

    Grid {
      columns: 2
      spacing: 8
      Repeater {
        model: card.cells
        Rectangle {
          required property var modelData
          required property int index
          readonly property int hour: parseInt(modelData.time.split(":")[0])
          readonly property bool isDay: hour >= 6 && hour < 18
          readonly property string dayTag: modelData.ymd > card.ymd ? "mañana" : modelData.ymd < card.ymd ? "ayer" : ""
          width: (col.width - 8) / 2
          height: 62
          radius: 18
          color: index === 0 ? Qt.alpha(Theme.accent, 0.16) : DeskTheme.tile
          Column {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 1
            Text {
              text: modelData.city
              width: parent.parent.width - 14 - 40
              elide: Text.ElideRight
              font.family: DeskTheme.sans; font.pixelSize: 12
              color: DeskTheme.textMuted
            }
            Row {
              spacing: 6
              Text {
                text: modelData.time
                font.family: DeskTheme.sans; font.pixelSize: 21; font.weight: Font.DemiBold
                color: DeskTheme.text
              }
              Text {
                visible: dayTag !== ""
                text: dayTag
                anchors.baseline: parent.children[0].baseline
                font.family: DeskTheme.sans; font.pixelSize: 12
                color: Theme.accent2
              }
            }
          }
          Icon {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            name: isDay ? "light_mode" : "bedtime"
            fill: 1
            font.pixelSize: 20
            color: isDay ? Theme.yellow : Theme.accent2
          }
        }
      }
    }
  }
}
