import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// Icono de volumen + panel: salida, entrada, dispositivos y volumen por app.
// Click: panel · Click derecho: mute · Rueda: volumen
BarText {
  id: root
  required property var barWindow

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : true

  readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
  readonly property var sinks: nodes.filter(n => n.isSink)
  readonly property var sources: nodes.filter(n => !n.isSink && !(n.properties["media.class"] || "").includes("Virtual"))
  readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.isSink)

  function ic(cp) { return String.fromCodePoint(cp) }
  function nodeName(n) { return n.nickname || n.description || n.name }
  function volIcon(v, m) { return m ? ic(0xf0581) : v > 0.66 ? ic(0xf057e) : v > 0.33 ? ic(0xf0580) : ic(0xf057f) }

  symbol: true
  filled: true
  text: Theme.sym(muted ? "volume_off" : vol > 0.66 ? "volume_up" : vol > 0.33 ? "volume_down" : vol > 0 ? "volume_mute" : "volume_off")
  lit: PopupState.current === "audio"
  readonly property bool popupOpen: PopupState.current === "audio"
  onPopupOpenChanged: if (popupOpen) Brightness.refresh()
  color: PopupState.current === "audio" ? Theme.accent : muted ? Theme.muted : Theme.foreground

  PwObjectTracker { objects: root.nodes.concat(root.streams) }

  onClicked: mouse => {
    if (mouse.button === Qt.RightButton) { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted }
    else PopupState.toggle("audio")
  }
  onScrolled: d => { if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1, vol + (d > 0 ? 0.05 : -0.05))) }

  BarPopup {
    name: "audio"
    title: "Sonido"
    barWindow: root.barWindow
    anchorItem: root
    panelWidth: 340

    // ── Salida ──
    VolumeSlider { node: root.sink; label: root.sink ? "Salida · " + root.nodeName(root.sink) : "Sin salida" }
    // ── Entrada ──
    VolumeSlider {
      node: root.source
      label: root.source ? "Micrófono · " + root.nodeName(root.source) : "Sin micrófono"
      iconOn: root.ic(0xf036c); iconOff: root.ic(0xf036d)
    }

    BrightnessSlider {}

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
    Text { text: "Salida"; color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize }
    Repeater {
      model: root.sinks
      ListRow {
        required property var modelData
        icon: root.ic(modelData.properties["device.bus"] === "bluetooth" ? 0xf02cb : 0xf04c3)
        title: root.nodeName(modelData)
        active: modelData === root.sink
        onClicked: Pipewire.preferredDefaultAudioSink = modelData
      }
    }

    Text { text: "Entrada"; color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize; visible: root.sources.length > 0 }
    Repeater {
      model: root.sources
      ListRow {
        required property var modelData
        icon: root.ic(0xf036c)
        title: root.nodeName(modelData)
        active: modelData === root.source
        onClicked: Pipewire.preferredDefaultAudioSource = modelData
      }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline; visible: root.streams.length > 0 }
    Text { text: "Aplicaciones"; color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize; visible: root.streams.length > 0 }
    Repeater {
      model: root.streams
      VolumeSlider {
        required property var modelData
        node: modelData
        iconOn: root.ic(0xf075a)
        label: modelData.properties["application.name"] || root.nodeName(modelData)
      }
    }
  }
}
