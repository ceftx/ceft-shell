import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Diálogo "hay cosas en curso" antes de apagar/reiniciar/suspender/cerrar sesión. Esc o "Cancelar" = no hacer nada.
Variants {
  model: Quickshell.screens
  PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    // en todos los monitores se oscurece; solo el que tiene el foco muestra la tarjeta con botones
    visible: PowerGuard.dialogOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Qt.alpha("#000000", 0.45 * fade.opacity)
    WlrLayershell.namespace: "quickshell-powerdialog"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: PowerGuard.dialogOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: if (visible) { fade.opacity = 0; appear.restart(); card.forceActiveFocus() }

    Item {
      id: fade
      anchors.fill: parent
      opacity: 0
      Keys.onEscapePressed: PowerGuard.cancel()

      MouseArea { anchors.fill: parent; onClicked: PowerGuard.cancel() }

      NumberAnimation { id: appear; target: fade; property: "opacity"; from: 0; to: 1; duration: Theme.animMed; easing.type: Easing.OutCubic }

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(460, parent.width - 48)
        height: col.implicitHeight + 40
        radius: Theme.radius
        color: Theme.glassPopup
        border.color: Theme.glassEdge; border.width: Theme.borderWidth
        focus: true
        Keys.onEscapePressed: PowerGuard.cancel()
        Keys.onReturnPressed: PowerGuard.cancel()
        transform: Translate { y: (1 - fade.opacity) * 10 }
        MouseArea { anchors.fill: parent }   // no cerrar al hacer click dentro

        ColumnLayout {
          id: col
          anchors { fill: parent; margins: 20 }
          spacing: 12

          RowLayout {
            spacing: 10
            Text { text: "warning"; font.family: Theme.iconFont; font.pixelSize: 26; color: Theme.yellow
                   Component.onCompleted: font.variableAxes = ({ "FILL": 1 }) }
            Text {
              text: "Hay cosas en curso"
              color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 5; font.bold: true
            }
          }
          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: (PowerGuard.actions[PowerGuard.kind] ? PowerGuard.actions[PowerGuard.kind].label : "") +
                  " ahora puede interrumpirlas o dejar archivos a medias."
            color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
          }
          Repeater {
            model: PowerGuard.blockers.map(b => PowerGuard.describe(b))
            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: rowCol.implicitHeight + 16
              radius: Theme.radiusSmall
              color: Qt.alpha(Theme.foreground, 0.07)
              Column {
                id: rowCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: 2
                Text { text: modelData.title; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1; font.bold: true; width: parent.width; elide: Text.ElideRight }
                Text { visible: modelData.detail !== ""; text: modelData.detail; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSmall; width: parent.width; elide: Text.ElideMiddle }
              }
            }
          }
          RowLayout {
            Layout.topMargin: 6
            Layout.fillWidth: true
            spacing: 10
            Item { Layout.fillWidth: true }
            DialogButton { text: "Cancelar"; primary: true; onClicked: PowerGuard.cancel() }
            DialogButton {
              text: PowerGuard.actions[PowerGuard.kind] ? PowerGuard.actions[PowerGuard.kind].force : ""
              danger: true
              onClicked: PowerGuard.confirm()
            }
          }
        }
      }
    }
  }
}
