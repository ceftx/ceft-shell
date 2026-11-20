import QtQuick
import QtQuick.Layouts

// Contenido de la barra horizontal (arriba / abajo): zonas izquierda · centro · derecha.
// Ancho máximo de los lados: hasta el borde del centro (módulos "shrink", p. ej. la ventana activa, se encogen con "…").
Item {
  id: root
  required property var barWin

  // ───────────── IZQUIERDA ─────────────
  // Ancho máximo: hasta el borde del centro (módulos "shrink", p. ej. la ventana activa, se encogen con "…")
  readonly property real centerW: centerBox.implicitWidth
  readonly property real sideMax: centerW > 0 ? Math.max(0, (width - centerW) / 2 - 26) : Math.max(0, width / 2 - 20)

  BarZone {
    id: leftZone
    barWindow: root.barWin
    ids: BarConfig.left
    spacing: 10
    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
    width: Math.min(implicitWidth, root.sideMax)
  }

  // ───────────── CENTRO ─────────────
  Item {
    id: centerBox
    anchors.centerIn: parent
    implicitWidth: BarConfig.center.length === 0 ? 0 : (pivoted ? pivotRow.implicitWidth : flatZone.implicitWidth)
    implicitHeight: Theme.barH - 12
    width: implicitWidth; height: implicitHeight

    readonly property int pivot: BarConfig.center.indexOf("workspaces")
    readonly property bool pivoted: pivot >= 0
    readonly property var before: pivoted ? BarConfig.center.slice(0, pivot) : []
    readonly property var after: pivoted ? BarConfig.center.slice(pivot + 1) : []
    // Lados iguales (ancho = el mayor): el eje queda en el centro exacto
    readonly property real sideW: Math.max(beforeZone.implicitWidth, afterZone.implicitWidth)

    BarZone {
      id: flatZone
      visible: !centerBox.pivoted
      barWindow: root.barWin
      ids: centerBox.pivoted ? [] : BarConfig.center
      autoSep: true
      anchors.centerIn: parent
    }

    RowLayout {
      id: pivotRow
      visible: centerBox.pivoted
      anchors.centerIn: parent
      spacing: 0

      Item {   // lado anterior
        Layout.preferredWidth: centerBox.sideW
        Layout.preferredHeight: Theme.barH - 12
        BarZone {
          id: beforeZone
          barWindow: root.barWin
          ids: centerBox.before
          autoSep: true
          stretch: true
          x: (parent.width - width) / 2
          width: stretch ? parent.width : implicitWidth
          anchors.verticalCenter: parent.verticalCenter
        }
      }
      BarSlot { modId: "~sep"; barWindow: root.barWin; blankSep: centerBox.before.length === 0; Layout.alignment: Qt.AlignVCenter }
      BarSlot { modId: "workspaces"; barWindow: root.barWin }
      BarSlot { modId: "~sep"; barWindow: root.barWin; blankSep: centerBox.after.length === 0; Layout.alignment: Qt.AlignVCenter }
      Item {   // lado posterior
        Layout.preferredWidth: centerBox.sideW
        Layout.preferredHeight: Theme.barH - 12
        BarZone {
          id: afterZone
          barWindow: root.barWin
          ids: centerBox.after
          autoSep: true
          stretch: true
          x: (parent.width - width) / 2
          width: stretch ? parent.width : implicitWidth
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
  }

  // ───────────── DERECHA ─────────────
  BarZone {
    id: rightZone
    barWindow: root.barWin
    ids: BarConfig.right
    spacing: 6
    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
    width: Math.min(implicitWidth, root.sideMax)
  }
}
