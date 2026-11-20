import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.desktop

// Página con scroll: título grande + contenido (hijos) apilado.
Item {
  id: page
  property string title: ""
  property string subtitle: ""
  default property alias content: col.data
  property alias flick: flick

  Flickable {
    id: flick
    anchors.fill: parent
    contentWidth: width
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    ColumnLayout {
      id: col
      x: 0
      y: 0
      width: flick.width - 22
      spacing: 22

      ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 3
        Text {
          text: page.title
          color: Theme.foreground
          font.family: Theme.fontSans
          font.pixelSize: 28
          font.weight: Font.DemiBold
          font.letterSpacing: -0.4
        }
        Text {
          visible: page.subtitle !== ""
          text: page.subtitle
          color: DeskTheme.textMuted
          font.family: Theme.fontSans
          font.pixelSize: 13
        }
      }
    }

    ScrollBar.vertical: ScrollBar {
      id: sb
      policy: ScrollBar.AsNeeded
      width: 8
      contentItem: Rectangle {
        implicitWidth: 6
        radius: 3
        color: Qt.alpha(Theme.foreground, sb.pressed ? 0.45 : 0.25)
      }
      background: Item {}
    }
  }
}
