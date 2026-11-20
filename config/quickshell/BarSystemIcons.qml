import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// Módulo "systemIcons": micrófono, bluetooth, red/VPN, audio y batería (cada uno con su popup).
// Barra vertical: la misma lista en columna (batería: glifo sobre el porcentaje).
GridLayout {
  id: root
  required property var barWindow
  property bool vertical: false
  columns: vertical ? 1 : 1000
  rowSpacing: 10; columnSpacing: 12

  BarText {
    id: micIcon
    readonly property var src: Pipewire.defaultAudioSource
    readonly property bool muted: src && src.audio ? src.audio.muted : true
    visible: src !== null
    symbol: true; filled: true
    text: Theme.sym(muted ? "mic_off" : "mic")
    color: muted ? Theme.muted : Theme.foreground
    onClicked: mouse => { if (src && src.audio) src.audio.muted = !src.audio.muted }
    PwObjectTracker { objects: micIcon.src ? [micIcon.src] : [] }
  }
  // Modo juego activo (click = desactivar)
  BarText {
    visible: GameMode.on
    symbol: true; filled: true
    text: Theme.sym("sports_esports")
    color: Theme.accent
    onClicked: GameMode.toggle()
  }
  BluetoothWidget { barWindow: root.barWindow }
  NetworkWidget { barWindow: root.barWindow }
  AudioWidget { barWindow: root.barWindow }

  // Batería (solo si hay una)
  BarText {
    readonly property var dev: UPower.displayDevice
    readonly property real pct: dev ? dev.percentage * (dev.percentage <= 1 ? 100 : 1) : 0
    readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging
    visible: dev !== null && dev.isLaptopBattery
    font.family: Theme.font
    font.pixelSize: Theme.fontSmall + 1
    text: (charging ? String.fromCodePoint(0xf0084) : String.fromCodePoint([0xf008e, 0xf007a, 0xf007c, 0xf007e, 0xf0080, 0xf0079][Math.round(pct / 20)])) + (root.vertical ? "\n" : " ") + Math.round(pct) + "%"
    horizontalAlignment: Text.AlignHCenter
    color: !charging && pct <= 15 ? Theme.active : Theme.foreground
  }
}
