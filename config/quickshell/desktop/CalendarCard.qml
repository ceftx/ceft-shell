import Quickshell
import QtQuick
import qs

// Mes con navegación (◀ ▶, rueda, click en el título = hoy). Siempre 6 filas: la tarjeta no cambia de alto.
DeskCard {
  id: card
  height: col.implicitHeight + DeskTheme.pad * 2

  SystemClock { id: clock; precision: SystemClock.Minutes }
  readonly property date today: clock.date
  property int year: today.getFullYear()
  property int month: today.getMonth()
  readonly property var monthNames: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
  readonly property bool isThisMonth: today.getFullYear() === year && today.getMonth() === month

  function shift(n) { const d = new Date(year, month + n, 1); year = d.getFullYear(); month = d.getMonth() }
  function goToday() { year = today.getFullYear(); month = today.getMonth() }

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

  Column {
    id: col
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeskTheme.pad }
    spacing: 10

    Item {
      width: parent.width; height: 36
      Item {
        id: title
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: t.implicitWidth; height: parent.height
        Text {
          id: t
          anchors.verticalCenter: parent.verticalCenter
          text: card.monthNames[card.month] + " " + card.year
          font.family: DeskTheme.sans; font.pixelSize: 18; font.weight: Font.DemiBold
          color: card.isThisMonth ? DeskTheme.text : Theme.accent
          Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.goToday() }
      }
      Row {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 6
        RoundButton { icon: "chevron_left"; size: 34; onClicked: card.shift(-1) }
        RoundButton { icon: "chevron_right"; size: 34; onClicked: card.shift(1) }
      }
    }

    Grid {
      columns: 7
      width: parent.width
      Repeater {
        model: ["L", "M", "X", "J", "V", "S", "D"]
        Text {
          required property string modelData
          width: col.width / 7; height: 24
          horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
          text: modelData
          font.family: DeskTheme.sans; font.pixelSize: 12; font.weight: Font.DemiBold
          color: DeskTheme.textFaint
        }
      }
      Repeater {
        model: card.cells
        Item {
          required property var modelData
          width: col.width / 7; height: 38
          Rectangle {
            anchors.centerIn: parent
            width: 34; height: 34; radius: 17
            color: modelData.today ? Theme.accent : cellHover.hovered && modelData.inMonth ? DeskTheme.tileHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            HoverHandler { id: cellHover }
            Text {
              anchors.centerIn: parent
              text: modelData.day
              font.family: DeskTheme.sans; font.pixelSize: 14
              font.weight: modelData.today ? Font.Bold : Font.Normal
              color: modelData.today ? DeskTheme.onAccent : modelData.inMonth ? DeskTheme.text : DeskTheme.textFaint
            }
          }
        }
      }
    }
  }
  WheelHandler { onWheel: e => card.shift(e.angleDelta.y > 0 ? -1 : 1) }
}
