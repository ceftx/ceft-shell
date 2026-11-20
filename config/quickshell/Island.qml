import QtQuick

// Grupo de la barra: píldora tonal (groupBackground) o de vidrio (estilo islands) sobre la barra.
// Los hijos van dentro; `inner` define el largo (ancho en barra horizontal, alto en vertical). Sin fondo activo es
// solo un contenedor transparente. En barra vertical el ancho es fijo (grosor de la barra menos 12).
Rectangle {
  id: root
  property Item inner: null        // item cuyo implicitWidth/implicitHeight define el largo
  property bool round: false       // true: botón circular (largo = grosor)
  property int pad: 12
  property real minWidth: 0        // para igualar largos de grupos simétricos
  property real extra: 0           // alto extra de la píldora en barra horizontal (activeWindow: dos líneas con aire)
  property bool bg: true           // este grupo admite fondo (activeWindow: solo en islands)
  readonly property bool vertical: BarConfig.vertical
  readonly property bool islands: BarConfig.style === "islands"
  readonly property bool boxed: bg && (islands || Theme.groupAlpha > 0)
  readonly property real thick: BarConfig.thickness - 12 + (vertical ? 0 : extra)
  readonly property real innerLen: inner ? (vertical ? inner.implicitHeight : inner.implicitWidth) : 0
  readonly property real wanted: round ? thick : Math.max(minWidth, innerLen + pad * 2)

  implicitWidth: vertical ? thick : wanted
  implicitHeight: vertical ? wanted : thick
  radius: Math.min(width, height) / 2
  color: !boxed ? "transparent" : islands ? Theme.islandBg : Theme.groupBg
  border.width: boxed && islands ? Theme.borderWidth : 0
  border.color: Theme.islandEdge
  visible: round || innerLen > 0

  Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
  Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
  Behavior on color { ColorAnimation { duration: Theme.animFast } }
}
