import QtQuick
import QtQuick.Layouts

// Contenido de la barra vertical (izquierda / derecha): las zonas left · center · right de bar.json pasan a ser
// arriba · centro · abajo. El centro queda centrado verticalmente en la pantalla; con "workspaces" en el centro
// ese módulo es el eje y los dos lados se igualan en alto para que quede exacto.
Item {
  id: root
  required property var barWin

  // Alto máximo de arriba / abajo: hasta el borde del centro
  readonly property real centerH: centerBox.implicitHeight
  readonly property real sideMax: centerH > 0 ? Math.max(0, (height - centerH) / 2 - 20) : Math.max(0, height / 2 - 20)

  // ───────────── ARRIBA ─────────────
  BarZone {
    id: topZone
    barWindow: root.barWin
    ids: BarConfig.left
    spacing: 8
    anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
    height: Math.min(implicitHeight, root.sideMax)
  }

  // ───────────── CENTRO ─────────────
  Item {
    id: centerBox
    anchors.centerIn: parent
    implicitWidth: Theme.barW - 12
    implicitHeight: BarConfig.center.length === 0 ? 0 : (pivoted ? pivotCol.implicitHeight : flatZone.implicitHeight)
    width: implicitWidth; height: implicitHeight

    readonly property int pivot: BarConfig.center.indexOf("workspaces")
    readonly property bool pivoted: pivot >= 0
    readonly property var before: pivoted ? BarConfig.center.slice(0, pivot) : []
    readonly property var after: pivoted ? BarConfig.center.slice(pivot + 1) : []
    // Lados iguales (alto = el mayor): el eje queda en el centro exacto
    readonly property real sideH: Math.max(beforeZone.implicitHeight, afterZone.implicitHeight)

    BarZone {
      id: flatZone
      visible: !centerBox.pivoted
      barWindow: root.barWin
      ids: centerBox.pivoted ? [] : BarConfig.center
      autoSep: true
      anchors.centerIn: parent
    }

    ColumnLayout {
      id: pivotCol
      visible: centerBox.pivoted
      anchors.centerIn: parent
      spacing: 0

      Item {   // lado anterior (arriba del eje)
        Layout.preferredHeight: centerBox.sideH
        Layout.preferredWidth: Theme.barW - 12
        Layout.alignment: Qt.AlignHCenter
        BarZone {
          id: beforeZone
          barWindow: root.barWin
          ids: centerBox.before
          autoSep: true
          stretch: true
          y: (parent.height - height) / 2
          height: stretch ? parent.height : implicitHeight
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
      BarSlot { modId: "~sep"; barWindow: root.barWin; blankSep: centerBox.before.length === 0 }
      BarSlot { modId: "workspaces"; barWindow: root.barWin }
      BarSlot { modId: "~sep"; barWindow: root.barWin; blankSep: centerBox.after.length === 0 }
      Item {   // lado posterior (debajo del eje)
        Layout.preferredHeight: centerBox.sideH
        Layout.preferredWidth: Theme.barW - 12
        Layout.alignment: Qt.AlignHCenter
        BarZone {
          id: afterZone
          barWindow: root.barWin
          ids: centerBox.after
          autoSep: true
          stretch: true
          y: (parent.height - height) / 2
          height: stretch ? parent.height : implicitHeight
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
    }
  }

  // ───────────── ABAJO ─────────────
  BarZone {
    id: bottomZone
    barWindow: root.barWin
    ids: BarConfig.right
    spacing: 6
    anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
    height: Math.min(implicitHeight, root.sideMax)
  }
}
