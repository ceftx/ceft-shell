import QtQuick
import qs

// Glifo de Material Symbols por nombre (Qt no resuelve ligaduras en esta fuente: se mapea nombre -> codepoint).
Text {
  id: t
  property string name: ""
  property real fill: 0
  property real weight: 400
  readonly property var map: ({
    "close": 0xe5cd, "notifications": 0xe7f4, "notifications_off": 0xe7f6, "notifications_active": 0xe7f7,
    "delete_sweep": 0xe16c, "expand_more": 0xe5cf, "expand_less": 0xe5ce, "done_all": 0xe877, "check": 0xe5ca,
    "volume_off": 0xe04f, "volume_up": 0xe050, "volume_down": 0xe04d, "volume_mute": 0xe04e,
    "mic": 0xe31d, "mic_off": 0xe02b,
    "brightness_high": 0xe1ac, "brightness_medium": 0xe1ae, "brightness_low": 0xe1ad
  })
  text: map[name] ? String.fromCodePoint(map[name]) : name
  color: Theme.foreground
  font.family: Theme.iconFont
  font.pixelSize: 20
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
  function axes() { font.variableAxes = ({ "FILL": fill, "wght": weight, "opsz": 24 }) }
  Component.onCompleted: axes()
  onFillChanged: axes()
  onWeightChanged: axes()
}
