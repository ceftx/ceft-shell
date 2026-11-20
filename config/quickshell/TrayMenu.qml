import Quickshell
import Quickshell.Wayland
import Quickshell.DBusMenu
import QtQuick
import QtQuick.Layouts

// Menú contextual temático de un ícono del tray (dbusmenu). Se abre con open(item, x, y) en coordenadas de pantalla.
// Click fuera (capa invisible) o Esc lo cierra. Los submenús reemplazan el contenido con una fila "atrás".
PanelWindow {
  id: win
  property var item: null
  property real px: 0
  property real py: 0
  property var stack: []               // handles de menús padre (para volver)
  property var current: null           // handle (QsMenuHandle) del nivel visible
  property string currentTitle: ""
  property var titles: []
  property bool open: false
  property bool above: false

  function show(trayItem, x, y, up) {
    item = trayItem; px = x; py = y; above = !!up
    stack = []; titles = []; currentTitle = ""
    current = trayItem.menu
    open = true
  }
  function close() { open = false }
  function enter(entry) { stack = stack.concat([current]); titles = titles.concat([currentTitle]); currentTitle = entry.text; current = entry }
  function back() {
    current = stack[stack.length - 1]; currentTitle = titles[titles.length - 1]
    stack = stack.slice(0, -1); titles = titles.slice(0, -1)
  }

  visible: open
  anchors { top: true; bottom: true; left: true; right: true }
  exclusiveZone: -1
  color: "transparent"
  WlrLayershell.namespace: "quickshell-traymenu"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    onPressed: win.close()
  }

  QsMenuOpener { id: opener; menu: win.current }

  Rectangle {
    id: card
    readonly property int pad: 6
    width: 240
    height: col.implicitHeight + pad * 2
    x: Math.max(8, Math.min(win.width - width - 8, win.px))
    y: Math.max(8, Math.min(win.height - height - 8, win.above ? win.py - height : win.py))
    radius: Theme.radiusSmall + 4
    color: Theme.glassPopup
    border.color: Theme.glassEdge; border.width: Theme.borderWidth
    focus: true
    Keys.onEscapePressed: win.close()
    opacity: win.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    ColumnLayout {
      id: col
      anchors { fill: parent; margins: card.pad }
      spacing: 1

      Rectangle {
        visible: win.stack.length > 0
        Layout.fillWidth: true
        implicitHeight: 32
        radius: Theme.radiusSmall
        color: backArea.containsMouse ? Theme.hover : "transparent"
        RowLayout {
          anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
          spacing: 8
          Text { text: "chevron_left"; font.family: Theme.iconFont; font.pixelSize: 18; color: Theme.foreground }
          Text { Layout.fillWidth: true; text: win.currentTitle; elide: Text.ElideRight; font.bold: true
                 color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize }
        }
        MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; onClicked: win.back() }
      }

      Repeater {
        model: opener.children
        Item {
          id: row
          required property var modelData
          readonly property bool sep: modelData.isSeparator
          Layout.fillWidth: true
          implicitHeight: sep ? 9 : 32

          Rectangle {
            visible: row.sep
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
            height: 1; color: Theme.hairline
          }
          Rectangle {
            visible: !row.sep
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: rowArea.containsMouse && row.modelData.enabled ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            opacity: row.modelData.enabled ? 1 : 0.45
            RowLayout {
              anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
              spacing: 8
              // check / radio / ícono del entry
              Item {
                implicitWidth: 18; implicitHeight: 18
                Text {
                  anchors.centerIn: parent
                  visible: row.modelData.buttonType !== QsMenuButtonType.None
                  text: row.modelData.buttonType === QsMenuButtonType.RadioButton
                        ? (row.modelData.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked")
                        : (row.modelData.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank")
                  font.family: Theme.iconFont; font.pixelSize: 18
                  color: row.modelData.checkState === Qt.Checked ? Theme.accent : Theme.muted
                }
                Image {
                  anchors.centerIn: parent
                  visible: row.modelData.buttonType === QsMenuButtonType.None && row.modelData.icon !== ""
                  source: row.modelData.icon
                  width: 16; height: 16; sourceSize: Qt.size(32, 32)
                }
              }
              Text {
                Layout.fillWidth: true
                text: row.modelData.text.replace(/_(.)/g, "$1")
                elide: Text.ElideRight
                color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1
              }
              Text {
                visible: row.modelData.hasChildren
                text: "chevron_right"; font.family: Theme.iconFont; font.pixelSize: 18; color: Theme.muted
              }
            }
            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              enabled: row.modelData.enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (row.modelData.hasChildren) win.enter(row.modelData)
                else { row.modelData.triggered(); win.close() }
              }
            }
          }
        }
      }
    }
  }
}
