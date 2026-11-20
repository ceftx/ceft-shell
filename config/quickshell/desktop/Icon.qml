import QtQuick

// Glifo de Material Symbols Rounded (por nombre de ligadura). fill: 0 contorno · 1 relleno
Text {
  property string name: ""
  property real fill: 0
  property real weight: 400
  text: name
  color: DeskTheme.text
  font.family: DeskTheme.icons
  font.pixelSize: 22
  // Los ejes se asignan imperativamente (sin binding) para no realimentar font.* -> variableAxes.
  function applyAxes() { font.variableAxes = ({ "FILL": fill, "wght": weight, "opsz": 24 }) }
  Component.onCompleted: applyAxes()
  onFillChanged: applyAxes()
  onWeightChanged: applyAxes()
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
  renderType: Text.NativeRendering
}
