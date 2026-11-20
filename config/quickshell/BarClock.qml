import Quickshell
import qs.desktop
import QtQuick

// Módulo "clock": [clima] [fecha · hora]. Formatos y 24 h/segundos desde ui.json; clima y fecha según bar.json clock.
// Click: calendario · click derecho: alternar el formato corto con "18 de noviembre".
// Barra vertical: clima (ícono + °), HH arriba y mm abajo, y la fecha corta (día / mes) apiladas.
Item {
  id: root
  required property var barWindow
  property bool vertical: false
  implicitWidth: vertical ? vCol.implicitWidth : hRow.implicitWidth
  implicitHeight: vertical ? vCol.implicitHeight : Theme.barH - 12

  SystemClock { id: vClock; precision: Theme.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }

  Column {
    id: vCol
    visible: root.vertical
    anchors.centerIn: parent
    spacing: 6
    Weather { vertical: true; visible: BarConfig.clockShowWeather && DeskWeather.ready; anchors.horizontalCenter: parent.horizontalCenter }
    Item {
      id: vclock
      readonly property bool lit: PopupState.current === "calendar"
      anchors.horizontalCenter: parent.horizontalCenter
      implicitWidth: 34
      implicitHeight: vTime.implicitHeight + (BarConfig.clockShowDate ? vDate.implicitHeight + 5 : 0)
      width: implicitWidth; height: implicitHeight
      Rectangle {
        anchors.centerIn: parent
        width: parent.width + 4; height: parent.height + 6; radius: 14
        color: vclock.lit ? Theme.accentContainer : vArea.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
      }
      Column {
        id: vTime
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        spacing: -2
        Repeater {
          model: [Qt.formatDateTime(vClock.date, Theme.clock24h ? "HH" : "h"), Qt.formatDateTime(vClock.date, "mm")]
          Text {
            required property string modelData
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData
            color: vclock.lit ? Theme.accent : Theme.foreground
            font.family: Theme.font; font.pixelSize: Theme.fontBase + 2; font.bold: true
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
          }
        }
      }
      Column {
        id: vDate
        visible: BarConfig.clockShowDate
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        spacing: -2
        Repeater {
          model: [Theme.formatDate(vClock.date, "d"), Theme.formatDate(vClock.date, "MMM").replace(".", "")]
          Text {
            required property string modelData
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData
            color: Theme.barText
            font.family: Theme.fontSans; font.pixelSize: Theme.fontSmall; font.weight: Font.Medium
          }
        }
      }
      MouseArea {
        id: vArea
        anchors.fill: parent; anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupState.toggle("calendar")
      }
    }
  }

  Row {
    id: hRow
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: 12

  Weather { visible: BarConfig.clockShowWeather && DeskWeather.ready; anchors.verticalCenter: parent.verticalCenter }

  Item {
    id: clock
    property bool alt: false
    readonly property bool lit: PopupState.current === "calendar"
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: clockText.implicitWidth
    implicitHeight: Theme.barH - 12
    width: implicitWidth; height: implicitHeight
    SystemClock { id: sysClock; precision: Theme.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width + 20; height: parent.height - 4; radius: height / 2
      color: clock.lit ? Theme.accentContainer : clockArea.containsMouse ? Theme.hover : "transparent"
      Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }
    Row {
      id: clockText
      anchors.centerIn: parent
      spacing: 6
      Text {
        visible: BarConfig.clockShowDate
        anchors.baseline: timeText.baseline
        text: Theme.formatDate(sysClock.date, clock.alt ? "d 'de' MMMM" : Theme.dateFormat)
        color: Theme.barText
        font.family: Theme.fontSans; font.pixelSize: Theme.fontBase; font.weight: Font.Medium
      }
      Text {
        visible: BarConfig.clockShowDate
        anchors.baseline: timeText.baseline
        text: "·"; color: Theme.barText
        font.family: Theme.fontSans; font.pixelSize: Theme.fontBase
      }
      Text {
        id: timeText
        text: Qt.formatDateTime(sysClock.date, Theme.timeFormat)
        color: clock.lit ? Theme.accent : Theme.foreground
        font.family: Theme.font; font.pixelSize: Theme.fontBase + 1; font.bold: true
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
      }
    }
    MouseArea {
      id: clockArea
      anchors.fill: parent; anchors.margins: -4
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: mouse => { if (mouse.button === Qt.RightButton) clock.alt = !clock.alt; else PopupState.toggle("calendar") }
    }
  }

  }

  CalendarPopup { barWindow: root.barWindow; anchorItem: root.vertical ? vclock : clock }
}
