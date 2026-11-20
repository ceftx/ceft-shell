import Quickshell
import QtQuick
import QtQuick.Effects
import qs

// Imagen de la notificación (cuadrado redondeado): foto/imagen > ícono de la app > inicial del nombre sobre un tono propio.
Item {
  id: av
  property string image: ""
  property string icon: ""
  property string appName: ""
  property int size: 40
  implicitWidth: size
  implicitHeight: size

  function resolve(s) {
    if (!s) return ""
    // image://icon/<nombre>: solo si el tema tiene ese ícono (si no, Qt dibuja el recuadro magenta de "falta")
    if (s.startsWith("image://icon/")) return Quickshell.iconPath(decodeURIComponent(s.substring(13)), true)
    if (s.startsWith("image://") || s.startsWith("file://")) return s
    if (s.startsWith("/")) return "file://" + s
    return Quickshell.iconPath(s, true)
  }
  readonly property string photo: resolve(image)
  readonly property string glyph: resolve(icon)
  readonly property bool usePhoto: photo !== "" && pic.status !== Image.Error
  readonly property bool useGlyph: !usePhoto && glyph !== "" && ico.status !== Image.Error
  readonly property var tones: [Theme.accent, Theme.green, Theme.yellow, Theme.accent2, Theme.active]
  readonly property color tone: {
    let h = 0
    for (let i = 0; i < appName.length; i++) h = (h * 31 + appName.charCodeAt(i)) >>> 0
    return tones[h % tones.length]
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusSmall
    color: av.useGlyph ? Qt.alpha(Theme.foreground, 0.08) : Qt.alpha(av.tone, 0.22)
    visible: !av.usePhoto
    Text {
      anchors.centerIn: parent
      visible: !av.useGlyph
      text: av.appName.length ? av.appName.charAt(0).toUpperCase() : "?"
      color: av.tone
      font.family: Theme.fontSans; font.pixelSize: av.size * 0.46; font.weight: Font.DemiBold
    }
    Image {
      id: ico
      anchors.centerIn: parent
      width: av.size * 0.66; height: width
      visible: av.useGlyph
      source: av.glyph
      sourceSize.width: 64; sourceSize.height: 64
      fillMode: Image.PreserveAspectFit
      asynchronous: true
    }
  }

  Image {
    id: pic
    anchors.fill: parent
    source: av.photo
    sourceSize.width: 128; sourceSize.height: 128
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    visible: false
    layer.enabled: true
  }
  Rectangle { id: mask; anchors.fill: parent; radius: Theme.radiusSmall; visible: false; layer.enabled: true }
  MultiEffect {
    anchors.fill: parent
    visible: av.usePhoto
    source: pic
    maskEnabled: true
    maskSource: mask
    opacity: pic.status === Image.Ready ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
  }
}
