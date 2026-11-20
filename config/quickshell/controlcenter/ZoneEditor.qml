import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Una zona de la barra (Izquierda / Centro / Derecha): chips de sus módulos, botón + que despliega
// los módulos disponibles. La selección (para reordenar con ‹ ›) se guarda en `selIndex`.
Item {
  id: z
  property string zone: "left"
  property string title: ""
  property int selIndex: -1             // -1 = ninguno
  property bool picking: false
  signal selectionChanged2()            // al seleccionar, la página limpia las demás zonas

  readonly property var items: CCCustom.zone(zone)
  Layout.fillWidth: true
  implicitHeight: col.implicitHeight + 24

  ColumnLayout {
    id: col
    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 12 }
    spacing: 8

    Text {
      text: z.title
      color: DeskTheme.textFaint
      font.family: Theme.fontSans
      font.pixelSize: 12
      font.weight: Font.DemiBold
      font.letterSpacing: 0.6
    }

    Flow {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: z.items
        ZoneChip {
          required property string modelData
          required property int index
          label: CCCustom.moduleInfo(modelData).name
          icon: CCCustom.moduleInfo(modelData).icon
          selected: z.selIndex === index
          canLeft: index > 0
          canRight: index < (z.items ? z.items.length : 0) - 1
          onClicked: { z.selIndex = selected ? -1 : index; if (z.selIndex >= 0) z.selectionChanged2() }
          onRemoved: { z.selIndex = -1; CCCustom.removeAt(z.zone, index) }
          onMoved: dir => { CCCustom.moveAt(z.zone, index, dir); z.selIndex = index + dir }
        }
      }
      Text {
        visible: z.items.length === 0
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: "Vacía · agregá un módulo con +"
        color: DeskTheme.textFaint
        font.family: Theme.fontSans
        font.pixelSize: 13
        font.italic: true
      }
      Rectangle {
        width: 32; height: 32; radius: 16
        color: z.picking ? Theme.accent : (pma.containsMouse ? Qt.alpha(Theme.accent, 0.30) : Theme.accentContainer)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Icon {
          anchors.centerIn: parent
          name: "add"
          font.pixelSize: 20
          color: z.picking ? Theme.background : Theme.accent
          rotation: z.picking ? 45 : 0
          Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: z.picking = !z.picking }
      }
    }

    // módulos disponibles
    Item {
      Layout.fillWidth: true
      implicitHeight: z.picking ? avail.implicitHeight + 16 : 0
      Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
      clip: true
      Rectangle {
        anchors.fill: parent
        anchors.topMargin: 0
        radius: 16
        color: Qt.alpha(Theme.foreground, 0.05)
        border.width: 1
        border.color: Qt.alpha(Theme.foreground, 0.06)
        opacity: z.picking ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Flow {
          id: avail
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
          spacing: 6
          Repeater {
            model: CCCustom.available
            CCChip {
              required property var modelData
              icon: modelData.icon
              label: modelData.name
              onClicked: CCCustom.addModule(z.zone, modelData.id)
            }
          }
          Text {
            visible: CCCustom.available.length === 0
            text: "No quedan módulos libres"
            color: DeskTheme.textFaint
            font.family: Theme.fontSans
            font.pixelSize: 13
          }
        }
      }
    }
  }
}
