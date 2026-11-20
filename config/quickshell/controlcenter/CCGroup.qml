import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Tarjeta tonal con título (ícono + texto), acción opcional a la derecha (p.ej. Restablecer) y filas debajo.
Item {
  id: g
  property string title: ""
  property string icon: ""
  property string subtitle: ""
  property bool resettable: false      // muestra "Restablecer" cuando hay claves modificadas
  signal resetClicked()
  default property alias rows: body.data
  property alias headerExtra: extra.data

  Layout.fillWidth: true
  implicitHeight: col.implicitHeight

  ColumnLayout {
    id: col
    anchors { left: parent.left; right: parent.right }
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 4
      spacing: 10
      Icon {
        visible: g.icon !== ""
        name: g.icon
        font.pixelSize: 20
        color: Theme.accent
        fill: 1
      }
      ColumnLayout {
        spacing: 1
        Text {
          text: g.title
          color: Theme.foreground
          font.family: Theme.fontSans
          font.pixelSize: 16
          font.weight: Font.DemiBold
        }
        Text {
          visible: g.subtitle !== ""
          text: g.subtitle
          color: DeskTheme.textFaint
          font.family: Theme.fontSans
          font.pixelSize: 12
        }
      }
      Item { Layout.fillWidth: true }
      RowLayout { id: extra; spacing: 8 }
      CCButton {
        compact: true
        visible: g.resettable
        icon: "restart_alt"
        label: "Restablecer"
        onClicked: g.resetClicked()
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: body.implicitHeight
      radius: 20
      color: DeskTheme.tile
      border.width: 1
      border.color: Qt.alpha(Theme.foreground, 0.06)
      ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right }
        spacing: 0
      }
    }
  }
}
