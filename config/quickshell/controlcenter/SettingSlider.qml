import QtQuick
import QtQuick.Layouts
import qs

// Fila con slider ligada a una clave de settings (look.gaps_in, nightlight...). Escribe en overrides.json al soltar.
CCRow {
  id: r
  property string key: ""
  property real from: 0
  property real to: 100
  property real step: 1
  property string unit: ""
  property int decimals: 0
  modified: CCStore.isSet(key)
  controlWidth: 300

  CCSlider {
    Layout.fillWidth: true
    from: r.from; to: r.to; step: r.step; unit: r.unit; decimals: r.decimals
    value: Number(CCStore.eff(r.key) ?? r.from)
    onCommitted: v => CCStore.setOver(r.key, v)
  }
}
