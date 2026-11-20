import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.services

// OSD: píldora de vidrio centrada abajo (arriba de la barra si ésta está abajo) para volumen, micrófono y brillo.
// Barra vertical: al costado de la barra, centrado en vertical.
// Volumen y micrófono se detectan directo en Pipewire (teclas, sliders, pavucontrol, lo que sea); el brillo llega por
//   qs ipc call osd flash brightness <0-100>     (lo llama `ceft-shell brightness set` al cambiar)
//   qs ipc call osd flash volume|mic <0-100>     (opcional, p. ej. para pruebas)
Scope {
  id: root
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  PwObjectTracker { objects: [root.sink, root.source].filter(n => n) }

  readonly property real vol: sink && sink.audio ? sink.audio.volume : -1
  readonly property bool volMuted: sink && sink.audio ? sink.audio.muted : false
  readonly property bool micMuted: source && source.audio ? source.audio.muted : false
  property bool armed: false       // evita mostrar el OSD por los valores iniciales de Pipewire
  Timer { interval: 1500; running: true; onTriggered: root.armed = true }

  property string kind: "volume"
  property real value: 0           // 0..1 (puede pasar de 1 en volumen: sobreamplificado)
  property bool muted: false
  property bool shown: false

  function show(k, v, m) {
    kind = k; value = v; muted = m; shown = true
    hideTimer.restart()
  }
  Timer { id: hideTimer; interval: 1700; onTriggered: root.shown = false }

  // Cambiar de salida/entrada no es "cambiar el volumen": se ignora un instante tras el cambio de nodo por defecto
  property bool settling: false
  Timer { id: settle; interval: 600; onTriggered: root.settling = false }
  onSinkChanged: { settling = true; settle.restart(); pendVol.stop() }
  onSourceChanged: { settling = true; settle.restart(); pendMic.stop() }
  readonly property bool live: armed && !settling
  // Se espera un instante: si es solo un cambio de nodo por defecto, `settling` cancela el aviso
  Timer { id: pendVol; interval: 60; onTriggered: if (root.live && root.vol >= 0) root.show("volume", root.vol, root.volMuted) }
  Timer { id: pendMic; interval: 60; onTriggered: if (root.live) root.show("mic", 1, root.micMuted) }
  onVolChanged: pendVol.restart()
  onVolMutedChanged: pendVol.restart()
  onMicMutedChanged: pendMic.restart()

  function fromIpc(kind, value) {
    const v = Math.max(0, Math.min(150, value)) / 100
    if (kind === "brightness" || kind === "volume") show(kind, v, kind === "volume" && volMuted)
    else if (kind === "mic") show("mic", 1, micMuted)
  }
  // OJO: `qs ipc call osd show ...` NO funciona desde la terminal (el CLI lee "show" como su subcomando `qs ipc show`
  // y rechaza los argumentos). Por eso existe el alias `flash`; `show` se mantiene por el contrato.
  IpcHandler {
    target: "osd"
    function flash(kind: string, value: int): void { root.fromIpc(kind, value) }
    function show(kind: string, value: int): void { root.fromIpc(kind, value) }
  }

  readonly property var targetScreen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]

  PanelWindow {
    id: win
    screen: root.targetScreen
    readonly property bool atBottom: BarConfig.isBottom
    readonly property bool vertical: BarConfig.vertical
    visible: root.shown || card.opacity > 0.01
    anchors { bottom: true; top: vertical; left: BarConfig.isLeft; right: BarConfig.isRight }
    margins.bottom: vertical ? 0 : atBottom ? Theme.barH + 56 : 64
    margins.left: Theme.barW + Theme.popupGap
    margins.right: Theme.barW + Theme.popupGap
    exclusiveZone: -1
    implicitWidth: card.width + 40
    implicitHeight: vertical ? 0 : card.height + 40
    color: "transparent"
    mask: Region {}      // nunca captura el mouse
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      id: card
      anchors.horizontalCenter: win.vertical ? undefined : parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      x: win.vertical ? (BarConfig.isLeft ? 4 : parent.width - width - 4) : 0
      width: root.kind === "mic" ? 232 : 300
      height: 56
      radius: height / 2
      color: Theme.glassPopup
      border.width: Theme.borderWidth; border.color: Theme.glassEdge
      opacity: root.shown ? 1 : 0
      scale: root.shown ? 1 : 0.94
      transform: Translate { x: win.vertical && !root.shown ? (BarConfig.isLeft ? -10 : 10) : 0; y: win.vertical || root.shown ? 0 : (win.atBottom ? -8 : 8); Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } } }
      Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
      Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

      readonly property bool off: root.kind === "mic" ? root.muted : (root.kind === "volume" && (root.muted || root.value <= 0.001))
      readonly property color tone: off ? Theme.muted : (root.kind === "volume" && root.value > 1.001 ? Theme.yellow : Theme.accent)
      readonly property string icon: {
        if (root.kind === "mic") return root.muted ? "mic_off" : "mic"
        if (root.kind === "brightness") return root.value < 0.34 ? "brightness_low" : root.value < 0.67 ? "brightness_medium" : "brightness_high"
        if (off) return "volume_off"
        return root.value < 0.34 ? "volume_mute" : root.value < 0.67 ? "volume_down" : "volume_up"
      }

      RowLayout {
        anchors { fill: parent; leftMargin: 18; rightMargin: 20 }
        spacing: 12
        NSym { name: card.icon; font.pixelSize: 26; fill: 1; color: card.tone
               Behavior on color { ColorAnimation { duration: Theme.animFast } } }

        // pista + relleno
        Item {
          visible: root.kind !== "mic"
          Layout.fillWidth: true
          Layout.preferredHeight: 10
          Rectangle { anchors.fill: parent; radius: 5; color: Qt.alpha(Theme.foreground, 0.14) }
          Rectangle {
            height: parent.height; radius: 5
            width: Math.max(height, parent.width * Math.min(1, root.value))
            color: card.tone
            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
          }
        }
        Text {
          visible: root.kind !== "mic"
          Layout.preferredWidth: 38
          horizontalAlignment: Text.AlignRight
          text: card.off && root.kind === "volume" ? "Mute" : Math.round(root.value * 100)
          color: Theme.foreground
          font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 2; font.weight: Font.DemiBold
        }
        Text {
          visible: root.kind === "mic"
          Layout.fillWidth: true
          text: root.muted ? "Micrófono silenciado" : "Micrófono activo"
          color: Theme.foreground
          font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 2; font.weight: Font.DemiBold
        }
      }
    }
  }
}
