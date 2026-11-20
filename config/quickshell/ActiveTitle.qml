import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// Izquierda de la barra (como ActiveWindow de end-4): app chica arriba, título abajo.
// Sin ventana enfocada: "Escritorio" / "Workspace N".
Item {
  id: root
  required property var barScreen
  property bool vertical: false      // barra vertical: se oculta (no hay sitio para el título)
  readonly property var monitor: Hyprland.monitorFor(barScreen)
  readonly property var tl: ToplevelManager.activeToplevel
  readonly property bool hasWin: tl !== null && tl !== undefined && (tl.title ?? "") !== ""
  readonly property int wsId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1

  // Ancho máximo ~480 px (con "…"); alto = las dos líneas, la píldora del slot da el aire vertical
  implicitWidth: vertical ? 0 : Math.min(480, Math.ceil(Math.max(appMetrics.advanceWidth, titleMetrics.advanceWidth)) + 2)
  implicitHeight: vertical ? 0 : col.implicitHeight
  clip: true

  // Ancho natural del texto (el implicitWidth de un Text con elide se encoge con el ancho disponible)
  TextMetrics { id: appMetrics; text: appText.text; font: appText.font }
  TextMetrics { id: titleMetrics; text: titleText.text; font: titleText.font }

  Column {
    id: col
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    spacing: 1
    Text {
      id: appText
      width: parent.width
      text: root.hasWin ? root.tl.appId : "Escritorio"
      color: Theme.barText
      font.family: Theme.fontSans; font.pixelSize: Theme.fontSmall - 1; font.weight: Font.Medium
      elide: Text.ElideRight
    }
    Text {
      id: titleText
      width: parent.width
      text: root.hasWin ? root.tl.title : "Workspace " + root.wsId
      color: Theme.foreground
      font.family: Theme.fontSans; font.pixelSize: Theme.fontBase; font.weight: Font.DemiBold
      elide: Text.ElideRight
    }
  }
}
