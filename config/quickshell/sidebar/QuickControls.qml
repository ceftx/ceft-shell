import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Grilla de ajustes rápidos + sliders (volumen, micrófono, brillo).
ColumnLayout {
  id: root
  required property var sb              // Sidebar (estado: awake, nb, section)
  spacing: 14

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var bt: Bluetooth.defaultAdapter
  property bool ksArm: false            // apagar el killswitch pide una segunda pulsación
  Timer { id: ksDisarm; interval: 3500; onTriggered: root.ksArm = false }

  PwObjectTracker { objects: [root.sink, root.source].filter(n => n !== null) }

  GridLayout {
    Layout.fillWidth: true
    columns: 2
    columnSpacing: 8
    rowSpacing: 8

    QTile {
      Layout.fillWidth: true; Layout.preferredWidth: 1
      icon: !SideNet.wifiOn ? "wifi_off" : "wifi"
      title: "Wi-Fi"; subtitle: SideNet.wifiLabel
      checked: SideNet.wifiOn && SideNet.wifi !== null
      enabled2: SideNet.wifi !== null
      detail: true
      onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
      onSecondary: { root.sb.open = false; PopupState.openNetSettings("summary") }
    }
    QTile {
      Layout.fillWidth: true; Layout.preferredWidth: 1
      icon: !root.bt || !root.bt.enabled ? "bluetooth_disabled" : "bluetooth"
      title: "Bluetooth"
      subtitle: !root.bt ? "Sin adaptador" : !root.bt.enabled ? "Apagado" : (Bluetooth.devices.values.filter(d => d.connected).length + " conectados")
      checked: root.bt !== null && root.bt.enabled
      enabled2: root.bt !== null
      onClicked: root.bt.enabled = !root.bt.enabled
    }
    QTile {
      Layout.fillWidth: true; Layout.preferredWidth: 1
      icon: "vpn_key"
      title: "VPN"; subtitle: SideNet.vpnBusy !== "" ? "Cambiando…" : SideNet.vpnActive ? SideNet.vpnLabel : SideNet.vpns.length === 0 ? "Sin VPN" : "Desconectada"
      checked: SideNet.vpnActive
      busy: SideNet.vpnBusy !== ""
      enabled2: SideNet.vpns.length > 0
      onClicked: SideNet.toggleVpn()
    }
    QTile {
      Layout.fillWidth: true; Layout.preferredWidth: 1
      icon: "shield_lock"
      title: "Killswitch"
      subtitle: SideNet.ksBusy ? "Cambiando…" : root.ksArm ? "Tocá otra vez para apagar" : SideNet.ksOn ? (SideNet.vpnActive ? "Protegido" : "Sin VPN: bloqueando") : "Apagado"
      checked: SideNet.ksOn
      warn: SideNet.ksOn && !SideNet.vpnActive
      busy: SideNet.ksBusy
      onClicked: {
        if (!SideNet.ksOn) SideNet.setKillswitch(true)
        else if (root.ksArm) { root.ksArm = false; SideNet.setKillswitch(false) }
        else { root.ksArm = true; ksDisarm.restart() }
      }
    }
    QTile {
      Layout.fillWidth: true; Layout.preferredWidth: 1
      icon: root.sb.nb && root.sb.nb.dnd ? "notifications_paused" : "notifications_active"
      title: "No molestar"
      subtitle: !root.sb.nb ? "No disponible" : root.sb.nb.dnd ? "Solo críticas" : "Avisos activos"
      checked: root.sb.nb ? root.sb.nb.dnd : false
      enabled2: root.sb.nb !== null && root.sb.nb !== undefined
      onClicked: root.sb.nb.toggleDnd()
    }
    QTile {
      Layout.fillWidth: true; Layout.preferredWidth: 1
      icon: "nightlight"
      title: "Luz nocturna"
      subtitle: Night.running ? Night.temp + " K" + (Night.auto ? " · auto" : "") : Night.auto ? "Auto " + Night.from + "–" + Night.to : "Apagada"
      checked: Night.running
      detail: true
      onClicked: Night.toggle()
      onSecondary: root.sb.section = root.sb.section === "night" ? "" : "night"
    }
    QTile {
      Layout.fillWidth: true; Layout.preferredWidth: 1
      icon: "sports_esports"
      title: "Modo juego"
      subtitle: GameMode.error !== "" ? "Error" : GameMode.on ? "Activo" : "Apagado"
      checked: GameMode.on
      busy: GameMode.busy
      onClicked: GameMode.toggle()
    }
    QTile {
      Layout.fillWidth: true; Layout.preferredWidth: 1
      icon: "coffee"
      title: "Mantener despierto"
      subtitle: root.sb.awake ? "No se bloquea ni apaga" : "Normal"
      checked: root.sb.awake
      onClicked: root.sb.awake = !root.sb.awake
    }
    QTile {
      Layout.fillWidth: true; Layout.preferredWidth: 1
      icon: root.source && root.source.audio && root.source.audio.muted ? "mic_off" : "mic"
      title: "Micrófono"
      subtitle: !root.source ? "Sin micrófono" : root.source.audio && root.source.audio.muted ? "Silenciado" : "Activo"
      checked: root.source !== null && root.source.audio !== null && root.source.audio.muted
      warn: checked
      enabled2: root.source !== null && root.source.audio !== null
      onClicked: root.source.audio.muted = !root.source.audio.muted
    }
  }

  Text {
    visible: SideNet.error !== "" || GameMode.error !== ""
    Layout.fillWidth: true; wrapMode: Text.Wrap
    text: SideNet.error !== "" ? SideNet.error : GameMode.error
    color: Theme.active; font.family: Theme.fontSans; font.pixelSize: 12
  }

  // ── sliders ──
  SSlider {
    icon: !root.sink || !root.sink.audio || root.sink.audio.muted ? "volume_off" : root.sink.audio.volume > 0.5 ? "volume_up" : "volume_down"
    enabled2: root.sink !== null && root.sink.audio !== null
    value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
    muted: !root.sink || !root.sink.audio || root.sink.audio.muted
    label: root.sink ? "Salida · " + (root.sink.nickname || root.sink.description || root.sink.name) : "Sin salida de audio"
    onMoved: v => { root.sink.audio.volume = v; if (v > 0) root.sink.audio.muted = false }
    onIconClicked: root.sink.audio.muted = !root.sink.audio.muted
  }
  SSlider {
    icon: root.source && root.source.audio && !root.source.audio.muted ? "mic" : "mic_off"
    enabled2: root.source !== null && root.source.audio !== null
    value: root.source && root.source.audio ? root.source.audio.volume : 0
    muted: !root.source || !root.source.audio || root.source.audio.muted
    label: root.source ? "Entrada · " + (root.source.nickname || root.source.description || root.source.name) : "Sin micrófono"
    onMoved: v => { root.source.audio.volume = v; if (v > 0) root.source.audio.muted = false }
    onIconClicked: root.source.audio.muted = !root.source.audio.muted
  }
  SSlider {
    visible: Brightness.available
    icon: "brightness_6"
    value: Brightness.value / 100
    label: "Brillo"
    onMoved: v => Brightness.set(v * 100)
    onIconClicked: {}
  }
}
