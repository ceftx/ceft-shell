import QtQuick
import qs

// Fila con interruptor ligada a una clave booleana de settings.
CCRow {
  id: r
  property string key: ""
  modified: CCStore.isSet(key)

  CCSwitch {
    checked: CCStore.eff(r.key) === true
    onToggled: v => CCStore.setOver(r.key, v)
  }
}
