import QtQuick
import QtQuick.Layouts
import qs

// Fila con slider ligada a una clave de ui.json (o bar.json con file: "bar").
CCRow {
  id: r
  property string key: ""
  property string file: "ui"
  property real from: 0
  property real to: 100
  property real step: 1
  property string unit: ""
  property int decimals: 0
  readonly property bool isUi: file === "ui"
  modified: isUi ? CCCustom.uiIsSet(key) : CCCustom.barIsSet(key)
  controlWidth: 300

  CCSlider {
    Layout.fillWidth: true
    from: r.from; to: r.to; step: r.step; unit: r.unit; decimals: r.decimals
    value: Number((r.isUi ? CCCustom.uiGet(r.key) : CCCustom.barGet(r.key)) ?? r.from)
    onCommitted: v => { if (r.isUi) CCCustom.setUi(r.key, v); else CCCustom.setBar(r.key, v) }
  }
}
