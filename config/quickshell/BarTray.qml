import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Módulo "tray": íconos del system tray. bar.json tray.hidden = apps que siguen corriendo pero no se muestran
// (nm-applet queda en segundo plano para pedir contraseñas de VPN/802.1x); tray.tint = tinte monocromo.
Item {
  id: root
  property bool vertical: false
  required property var barWindow
  readonly property var hidden: BarConfig.trayHidden
  function isHidden(item) {
    const keys = [item.id, item.title, item.tooltipTitle].map(k => String(k ?? "").toLowerCase())
    return root.hidden.some(h => keys.some(k => k !== "" && k.indexOf(String(h).toLowerCase()) >= 0))
  }
  readonly property bool any: SystemTray.items.values.some(i => !isHidden(i))
  implicitWidth: any ? trayRow.implicitWidth : 0
  implicitHeight: vertical ? (any ? trayRow.implicitHeight : 0) : Theme.barH - 12

  TrayMenu { id: trayMenu; screen: root.barWindow.screen }

  GridLayout {
    id: trayRow
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 1000
    rowSpacing: 6; columnSpacing: 6
    Repeater {
      model: SystemTray.items
      Item {
        id: trayItem
        required property SystemTrayItem modelData
        visible: !root.isHidden(modelData)
        implicitWidth: visible ? 28 : 0; implicitHeight: 28
        Layout.alignment: Qt.AlignCenter
        Rectangle {
          anchors.centerIn: parent
          width: 28; height: 28; radius: 14
          color: trayArea.containsMouse ? Theme.hover : "transparent"
          Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
        Image {
          id: trayImg
          anchors.centerIn: parent
          source: trayItem.modelData.icon
          width: 19; height: 19
          sourceSize: Qt.size(48, 48)
          smooth: true; mipmap: true
          opacity: trayArea.containsMouse ? 1 : 0.9
          scale: trayArea.pressed ? 0.9 : 1
          // Tinte monocromo para que armonice con los glifos Material
          layer.enabled: BarConfig.trayTint
          layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: Theme.foreground
            saturation: -1.0
            brightness: 0.35
            contrast: 0.4
          }
          Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
          Behavior on scale { NumberAnimation { duration: Theme.animFast * 0.65 } }
        }
        MouseArea {
          id: trayArea
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: mouse => {
            // coordenadas de pantalla del punto de anclaje (la barra ocupa un borde: abajo/derecha se desplazan)
            const sw = root.barWindow.screen.width, sh = root.barWindow.screen.height
            const ox = BarConfig.isRight ? sw - root.barWindow.width : 0
            const oy = BarConfig.isBottom ? sh - root.barWindow.height : 0
            const p = root.vertical ? trayItem.mapToItem(null, BarConfig.isLeft ? trayItem.width + 8 : -8, 0)
                                    : trayItem.mapToItem(null, 0, BarConfig.isBottom ? -8 : trayItem.height + 8)
            const x = ox + p.x - (root.vertical && !BarConfig.isLeft ? 240 : 0)
            const y = oy + p.y
            if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
              if (trayItem.modelData.hasMenu) trayMenu.show(trayItem.modelData, x, y, !root.vertical && BarConfig.isBottom)
            } else trayItem.modelData.activate()
          }
        }
      }
    }
  }
}
