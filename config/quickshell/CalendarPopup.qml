import Quickshell
import QtQuick
import QtQuick.Layouts

// Calendario bajo el reloj (mismo lenguaje que desktop/CalendarCard): título del mes (click = hoy),
// botones circulares ◀ ▶, cabecera de días legible, hoy resaltado, siempre 6 filas.
BarPopup {
  id: win
  name: "calendar"
  panelWidth: 340

  SystemClock { id: sysClock; precision: SystemClock.Minutes }
  property date today: sysClock.date
  property int year: today.getFullYear()
  property int month: today.getMonth()   // 0-11
  readonly property var monthNames: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
                                     "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
  readonly property bool isThisMonth: today.getFullYear() === year && today.getMonth() === month

  function shift(n) {
    const d = new Date(year, month + n, 1)
    year = d.getFullYear(); month = d.getMonth()
  }
  function goToday() { year = today.getFullYear(); month = today.getMonth() }
  // Al abrir, vuelve siempre al mes actual
  onOpenChanged: if (open) goToday()

  // 42 celdas desde el lunes de la primera semana; las de otros meses salen atenuadas
  readonly property var cells: {
    const first = new Date(year, month, 1)
    const start = new Date(year, month, 1 - ((first.getDay() + 6) % 7))
    const out = []
    for (let i = 0; i < 42; i++) {
      const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
      out.push({ day: d.getDate(), inMonth: d.getMonth() === month,
                 today: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate() })
    }
    return out
  }

  // Cabecera: Mes Año ........ ◀ ▶
  Item {
    Layout.fillWidth: true
    implicitHeight: 38
    Text {
      id: monthTitle
      anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
      text: win.monthNames[win.month] + " " + win.year
      font.family: Theme.fontSans; font.pixelSize: 18; font.weight: Font.DemiBold
      color: win.isThisMonth ? Theme.foreground : Theme.accent
      Behavior on color { ColorAnimation { duration: Theme.animFast } }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.goToday() }
    }
    Row {
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      spacing: 6
      Repeater {
        model: [{ s: "chevron_left", n: -1 }, { s: "chevron_right", n: 1 }]
        Rectangle {
          required property var modelData
          width: 34; height: 34; radius: 17
          color: btn.containsMouse ? Qt.alpha(Theme.foreground, 0.16) : Theme.hover
          scale: btn.pressed ? 0.92 : 1
          Behavior on color { ColorAnimation { duration: Theme.animFast } }
          Behavior on scale { NumberAnimation { duration: 90 } }
          Text {
            anchors.centerIn: parent
            text: Theme.sym(parent.modelData.s)
            font.family: Theme.iconFont; font.pixelSize: 22
            color: Theme.foreground
          }
          MouseArea {
            id: btn
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: win.shift(parent.modelData.n)
          }
        }
      }
    }
  }

  Grid {
    id: grid
    Layout.fillWidth: true
    columns: 7
    readonly property real cw: width / 7

    Repeater {
      model: ["L", "M", "X", "J", "V", "S", "D"]
      Text {
        required property string modelData
        width: grid.cw; height: 26
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        text: modelData
        font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.DemiBold
        color: Qt.alpha(Theme.foreground, 0.68)
      }
    }

    Repeater {
      model: win.cells
      Item {
        required property var modelData
        width: grid.cw; height: 38
        Rectangle {
          anchors.centerIn: parent
          width: 34; height: 34; radius: 17
          color: modelData.today ? Theme.accent : cellHover.hovered && modelData.inMonth ? Theme.hover : "transparent"
          Behavior on color { ColorAnimation { duration: Theme.animFast } }
          HoverHandler { id: cellHover }
          Text {
            anchors.centerIn: parent
            text: modelData.day
            font.family: Theme.fontSans; font.pixelSize: 14
            font.weight: modelData.today ? Font.Bold : Font.Normal
            color: modelData.today ? Theme.background : modelData.inMonth ? Theme.foreground : Qt.alpha(Theme.foreground, 0.38)
          }
        }
      }
    }
  }

  // Rueda del ratón sobre el calendario = cambiar de mes
  WheelHandler { onWheel: event => win.shift(event.angleDelta.y > 0 ? -1 : 1) }
}
