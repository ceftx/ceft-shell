import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Selector desplegable en línea (no abre otra ventana): el botón muestra el valor actual y, al pulsarlo,
// se despliega una lista con scroll debajo. items: [{ v, l }]. Con `searchable` agrega un campo de búsqueda.
Item {
  id: s
  property var items: []
  property var value
  property string placeholder: ""
  property bool searchable: false
  property bool fontPreview: false     // dibuja cada opción con su propia tipografía
  property bool open: false
  property int maxRows: 6
  signal picked(var v)

  readonly property string currentLabel: {
    const it = items.find(i => i.v === value)
    return it ? it.l : (value !== undefined && value !== null && value !== "" ? String(value) : placeholder)
  }
  readonly property var shown: {
    const q = search.text.trim().toLowerCase()
    return q === "" ? items : items.filter(i => i.l.toLowerCase().indexOf(q) >= 0)
  }

  Layout.fillWidth: true
  implicitHeight: head.height + (open ? panel.height + 6 : 0)
  Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  clip: true

  Rectangle {
    id: head
    width: parent.width
    height: 38
    radius: 19
    color: hma.containsMouse ? DeskTheme.tileHover : DeskTheme.tile
    border.width: 1
    border.color: s.open ? Qt.alpha(Theme.accent, 0.7) : Qt.alpha(Theme.foreground, 0.10)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Text {
      anchors { left: parent.left; leftMargin: 16; right: chev.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
      text: s.currentLabel
      elide: Text.ElideRight
      color: Theme.foreground
      font.family: s.fontPreview && s.value ? String(s.value) : Theme.fontSans
      font.pixelSize: 14
    }
    Icon {
      id: chev
      anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
      name: "expand_more"
      font.pixelSize: 20
      color: DeskTheme.textMuted
      rotation: s.open ? 180 : 0
      Behavior on rotation { NumberAnimation { duration: 180 } }
    }
    MouseArea { id: hma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { s.open = !s.open; if (s.open && s.searchable) search.input.forceActiveFocus() } }
  }

  Rectangle {
    id: panel
    y: head.height + 6
    width: parent.width
    height: (s.searchable ? 44 : 0) + Math.min(s.maxRows, Math.max(1, s.shown.length)) * 34 + 10
    radius: 18
    color: Qt.alpha(Theme.foreground, 0.06)
    border.width: 1
    border.color: Qt.alpha(Theme.foreground, 0.08)
    opacity: s.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    CCField {
      id: search
      visible: s.searchable
      x: 8; y: 6
      width: parent.width - 16
      implicitHeight: 34
      icon: "search"
      placeholder: "Buscar"
    }
    ListView {
      id: list
      x: 6
      y: (s.searchable ? 44 : 0) + 5
      width: parent.width - 12
      height: parent.height - y - 5
      clip: true
      model: s.shown
      boundsBehavior: Flickable.StopAtBounds
      delegate: Rectangle {
        id: d
        required property var modelData
        width: list.width
        height: 34
        radius: 12
        color: dma.containsMouse ? Qt.alpha(Theme.foreground, 0.10) : (d.modelData.v === s.value ? Theme.accentContainer : "transparent")
        Text {
          anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
          text: d.modelData.l
          elide: Text.ElideRight
          color: Theme.foreground
          font.family: s.fontPreview ? d.modelData.l : Theme.fontSans
          font.pixelSize: 14
        }
        MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { s.open = false; search.text = ""; s.picked(d.modelData.v) } }
      }
    }
  }
}
