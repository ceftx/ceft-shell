import QtQuick
import QtQuick.Layouts

// Una zona de la barra (izquierda / derecha / un lado del centro): fila de módulos por id
// (columna si la barra es vertical: arriba / abajo / un lado del centro).
// autoSep: separador automático (estilo bar.json "divider") entre módulos consecutivos.
GridLayout {
  id: zone
  readonly property bool vertical: BarConfig.vertical
  columns: vertical ? 1 : 1000
  rowSpacing: spacing
  columnSpacing: spacing
  required property var barWindow
  property var ids: []
  property bool autoSep: false
  property bool stretch: false     // un solo módulo: ocupa todo el ancho de la zona
  property real spacing: 6

  function withSeps(list) {
    const out = []
    for (let i = 0; i < list.length; i++) {
      if (i > 0 && list[i] !== "divider" && list[i - 1] !== "divider") out.push("~sep")
      out.push(list[i])
    }
    return out
  }

  Repeater {
    model: zone.autoSep ? zone.withSeps(zone.ids) : zone.ids
    BarSlot {
      required property string modelData
      modId: modelData
      barWindow: zone.barWindow
      stretch: zone.stretch && zone.ids.length === 1
    }
  }
}
