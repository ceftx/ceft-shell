import QtQuick
import qs

// Fila con interruptor ligada a una clave booleana de ui.json (o bar.json con file: "bar").
CCRow {
  id: r
  property string key: ""
  property string file: "ui"
  readonly property bool isUi: file === "ui"
  modified: isUi ? CCCustom.uiIsSet(key) : CCCustom.barIsSet(key)

  CCSwitch {
    checked: (r.isUi ? CCCustom.uiGet(r.key) : CCCustom.barGet(r.key)) === true
    onToggled: v => { if (r.isUi) CCCustom.setUi(r.key, v); else CCCustom.setBar(r.key, v) }
  }
}
