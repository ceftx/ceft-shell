import QtQuick
import QtQuick.Shapes
import Quickshell
import qs

// Reloj analógico "cookie": silueta ondulada, agujas redondeadas, día arriba-izq y mes abajo-der.
Item {
  id: root
  width: DeskTheme.colWidth
  height: 280
  property int order: 0
  property bool shown: false
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 400 } }
  Timer { interval: 60 + root.order * 70; running: true; onTriggered: root.shown = true }

  SystemClock { id: clock; precision: SystemClock.Seconds }
  readonly property date now: clock.date
  readonly property real minuteAngle: (now.getMinutes() + now.getSeconds() / 60) * 6
  readonly property real hourAngle: ((now.getHours() % 12) + now.getMinutes() / 60) * 30
  readonly property var months: ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]

  readonly property int d: 272
  readonly property real rad: d / 2

  // Silueta: r(θ) = R·(1 − a + a·cos(12θ)) → 12 lóbulos suaves
  readonly property var outline: {
    const pts = [], n = 240, a = 0.035
    for (let i = 0; i <= n; i++) {
      const t = i / n * Math.PI * 2
      const r = (rad - 2) * (1 - a + a * Math.cos(12 * t))
      pts.push(Qt.point(rad + r * Math.cos(t), rad + r * Math.sin(t)))
    }
    return pts
  }

  Item {
    id: face
    width: root.d; height: root.d
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    scale: root.shown ? 1 : 0.9
    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: Qt.alpha(Theme.background, 0.72)
        strokeColor: DeskTheme.cardEdge
        strokeWidth: 1
        PathPolyline { path: root.outline }
      }
    }

    // numerales tenues
    Repeater {
      model: [{ t: "12", a: 0 }, { t: "3", a: 90 }, { t: "6", a: 180 }, { t: "9", a: 270 }]
      Text {
        required property var modelData
        x: root.rad + Math.sin(modelData.a * Math.PI / 180) * (root.rad - 34) - width / 2
        y: root.rad - Math.cos(modelData.a * Math.PI / 180) * (root.rad - 34) - height / 2
        text: modelData.t
        font.family: DeskTheme.sans; font.pixelSize: 26; font.weight: Font.DemiBold
        color: DeskTheme.textFaint
      }
    }
    // marcas de minuto
    Repeater {
      model: 60
      Item {
        required property int index
        readonly property bool major: index % 5 === 0
        visible: index % 15 !== 0
        width: 4; height: root.rad - 12
        x: root.rad - 2; y: 12
        rotation: index * 6
        transformOrigin: Item.Bottom
        Rectangle {
          width: parent.major ? 3 : 2; height: parent.major ? 8 : 4
          radius: width / 2
          anchors.horizontalCenter: parent.horizontalCenter
          color: parent.major ? DeskTheme.textMuted : DeskTheme.textFaint
        }
      }
    }

    // fecha
    Text {
      x: 34; y: 38
      text: root.now.getDate()
      font.family: DeskTheme.sans; font.pixelSize: 30; font.weight: Font.Bold
      color: DeskTheme.text
    }
    Text {
      anchors { right: parent.right; rightMargin: 36; bottom: parent.bottom; bottomMargin: 52 }
      text: root.months[root.now.getMonth()]
      font.family: DeskTheme.sans; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 1
      color: Theme.accent
    }

    // agujas: Item con la base en el centro del reloj, rotando sobre su borde inferior
    Item {   // hora
      width: 12; height: root.rad * 0.5
      x: root.rad - 6; y: root.rad - height
      rotation: root.hourAngle; transformOrigin: Item.Bottom
      Rectangle { anchors.fill: parent; radius: 6; color: DeskTheme.text }
    }
    Item {   // minutos
      width: 8; height: root.rad * 0.74
      x: root.rad - 4; y: root.rad - height
      rotation: root.minuteAngle; transformOrigin: Item.Bottom
      Rectangle { anchors.fill: parent; radius: 4; color: Theme.accent }
    }
    Item {   // segundero
      width: 2; height: root.rad * 0.8
      x: root.rad - 1; y: root.rad - height
      rotation: root.now.getSeconds() * 6; transformOrigin: Item.Bottom
      Behavior on rotation { enabled: root.now.getSeconds() !== 0; NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
      Rectangle { anchors.fill: parent; radius: 1; color: Theme.accent2 }
    }
    Rectangle { width: 16; height: 16; radius: 8; anchors.centerIn: parent; color: DeskTheme.text
      Rectangle { width: 6; height: 6; radius: 3; anchors.centerIn: parent; color: Theme.background } }
  }
}
