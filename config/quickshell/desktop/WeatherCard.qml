import QtQuick
import qs

DeskCard {
  id: card
  height: 198

  MouseArea { anchors.fill: parent; onClicked: DeskWeather.refresh(); z: -1 }

  // ícono grande a la derecha
  Rectangle {
    anchors { right: parent.right; top: parent.top; margins: 16 }
    width: 64; height: 64; radius: 32
    color: Qt.alpha(Theme.accent2, 0.16)
    Icon {
      anchors.centerIn: parent
      name: DeskWeather.ready ? DeskWeather.icon : "cloud_off"
      fill: 1; font.pixelSize: 38
      color: DeskWeather.day ? Theme.yellow : Theme.accent2
      opacity: DeskWeather.loading ? 0.5 : 1
      Behavior on opacity { NumberAnimation { duration: 200 } }
    }
  }

  Row {
    x: DeskTheme.pad; y: DeskTheme.pad - 4
    Text {
      text: DeskWeather.ready ? Math.round(DeskWeather.temp) : "--"
      font.family: DeskTheme.sans; font.pixelSize: 58; font.weight: Font.Light; font.letterSpacing: -2
      color: DeskTheme.text
    }
    Text {
      text: DeskWeather.unit
      topPadding: 8
      font.family: DeskTheme.sans; font.pixelSize: 22; font.weight: Font.Light
      color: DeskTheme.textMuted
    }
  }
  Column {
    x: DeskTheme.pad; y: 82
    spacing: 1
    Text {
      text: DeskWeather.ready ? DeskWeather.description : (DeskWeather.failed ? "Sin conexión" : "Cargando…")
      font.family: DeskTheme.sans; font.pixelSize: 15; font.weight: Font.Medium
      color: DeskTheme.text
    }
    Text {
      text: (DeskConfig.city || "Clima") + (DeskWeather.ready ? " · sensación " + Math.round(DeskWeather.feels) + "°" : "")
      font.family: DeskTheme.sans; font.pixelSize: 12
      color: DeskTheme.textMuted
    }
  }

  // humedad · viento · amanecer · atardecer
  Row {
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
    spacing: 6
    Repeater {
      model: [
        { i: "humidity_percentage", v: DeskWeather.ready ? DeskWeather.humidity + "%" : "--" },
        { i: "air", v: DeskWeather.ready ? Math.round(DeskWeather.wind) + " km/h" : "--" },
        { i: "wb_twilight", v: DeskWeather.sunrise },
        { i: "bedtime", v: DeskWeather.sunset }
      ]
      Rectangle {
        required property var modelData
        width: (card.width - 28 - 18) / 4; height: 48; radius: 14
        color: DeskTheme.tile
        Column {
          anchors.centerIn: parent
          spacing: 0
          Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData.i; font.pixelSize: 15; color: DeskTheme.textMuted }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.v
            font.family: DeskTheme.sans; font.pixelSize: 13; font.weight: Font.Medium
            color: DeskTheme.text
          }
        }
      }
    }
  }
}
