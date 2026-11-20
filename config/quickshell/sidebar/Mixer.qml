import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Mezclador: volumen por app (streams de reproducción de Pipewire) + elegir salida / entrada por defecto.
ColumnLayout {
  id: root
  spacing: 10

  readonly property var all: Pipewire.nodes.values
  readonly property var sinks: all.filter(n => n.audio && !n.isStream && n.isSink)
  readonly property var sources: all.filter(n => n.audio && !n.isStream && !n.isSink && !(n.properties["media.class"] || "").includes("Virtual"))
  readonly property var streams: all.filter(n => n.audio && n.isStream && n.isSink)
  readonly property int streamCount: streams.length

  PwObjectTracker { objects: root.all.filter(n => n.audio) }

  function nodeName(n) { return n.nickname || n.description || n.name }
  function appName(n) { return n.properties["application.name"] || n.properties["node.name"] || nodeName(n) }
  function appIcon(n) {
    const i = n.properties["application.icon-name"] || n.properties["application.process.binary"] || ""
    return i !== "" ? Quickshell.iconPath(i.toLowerCase(), "") : ""
  }

  // ── por app ──
  Text { text: "Aplicaciones"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.6; font.capitalization: Font.AllUppercase }

  // estado vacío con personalidad
  RowLayout {
    visible: root.streams.length === 0
    Layout.fillWidth: true
    spacing: 10
    Icon { name: "music_off"; font.pixelSize: 22; color: DeskTheme.textFaint }
    Text {
      Layout.fillWidth: true
      text: "Nada suena ahora. Cuando una app reproduzca audio, aparece acá con su propio volumen."
      wrapMode: Text.Wrap
      color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12
    }
  }

  Repeater {
    model: root.streams
    RowLayout {
      id: row
      required property var modelData
      readonly property var audio: modelData.audio
      Layout.fillWidth: true
      spacing: 12
      Item {
        Layout.preferredWidth: 34; Layout.preferredHeight: 34
        Rectangle { anchors.fill: parent; radius: 10; color: DeskTheme.tile }
        Image {
          id: img
          anchors.centerIn: parent; width: 22; height: 22
          source: root.appIcon(row.modelData)
          sourceSize: Qt.size(44, 44)
          visible: status === Image.Ready
        }
        Icon { visible: img.status !== Image.Ready; anchors.centerIn: parent; name: "music_note"; fill: 1; font.pixelSize: 18; color: DeskTheme.textMuted }
      }
      SSlider {
        compact: true
        label: root.appName(row.modelData) + (row.modelData.properties["media.name"] ? " · " + row.modelData.properties["media.name"] : "")
        value: row.audio ? row.audio.volume : 0
        muted: row.audio ? row.audio.muted : true
        icon: muted ? "volume_off" : "volume_up"
        onMoved: v => { if (row.audio) { row.audio.volume = v; if (v > 0) row.audio.muted = false } }
        onIconClicked: if (row.audio) row.audio.muted = !row.audio.muted
      }
    }
  }

  // ── dispositivos ──
  Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
  Text { text: "Salida"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.6; font.capitalization: Font.AllUppercase }
  Repeater {
    model: root.sinks
    DevRow {
      required property var modelData
      icon: modelData.properties["device.bus"] === "bluetooth" ? "headphones" : (modelData.properties["device.form-factor"] === "headphone" ? "headphones" : "speaker")
      title: root.nodeName(modelData)
      current: modelData === Pipewire.defaultAudioSink
      onPicked: Pipewire.preferredDefaultAudioSink = modelData
    }
  }
  Text {
    visible: root.sources.length > 0
    text: "Entrada"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.6; font.capitalization: Font.AllUppercase
  }
  Repeater {
    model: root.sources
    DevRow {
      required property var modelData
      icon: "mic"
      title: root.nodeName(modelData)
      current: modelData === Pipewire.defaultAudioSource
      onPicked: Pipewire.preferredDefaultAudioSource = modelData
    }
  }

  component DevRow: Rectangle {
    id: dev
    property string icon: ""
    property string title: ""
    property bool current: false
    signal picked()
    Layout.fillWidth: true
    implicitHeight: 38
    radius: Theme.radiusSmall
    color: current ? Theme.accentContainer : dma.containsMouse ? DeskTheme.tile : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    RowLayout {
      anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
      spacing: 10
      Icon { name: dev.icon; fill: dev.current ? 1 : 0; font.pixelSize: 18; color: dev.current ? Theme.accent : DeskTheme.textMuted }
      Text {
        Layout.fillWidth: true; text: dev.title; elide: Text.ElideRight
        color: dev.current ? DeskTheme.text : DeskTheme.textMuted
        font.family: Theme.fontSans; font.pixelSize: 13; font.weight: dev.current ? Font.DemiBold : Font.Normal
      }
      Icon { visible: dev.current; name: "check"; font.pixelSize: 18; color: Theme.accent }
    }
    MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dev.picked() }
  }
}
