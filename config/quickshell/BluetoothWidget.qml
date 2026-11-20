import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

// Icono Bluetooth + panel: encender, buscar, emparejar/conectar dispositivos.
// Click en dispositivo: conectar/desconectar (o emparejar) · Click derecho: olvidar
BarText {
  id: root
  required property var barWindow

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool on: adapter !== null && adapter.enabled
  readonly property var devices: Bluetooth.devices.values
    .filter(d => d.paired || d.connected || (d.deviceName && d.deviceName !== d.address.replace(/:/g, "-")))
    .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
  readonly property bool anyConnected: devices.some(d => d.connected)

  function ic(cp) { return String.fromCodePoint(cp) }
  function devIcon(d) {
    const i = d.icon || ""
    return ic(i.includes("headset") || i.includes("headphone") ? 0xf02cb
            : i.includes("audio") ? 0xf04c3
            : i.includes("mouse") ? 0xf037d
            : i.includes("keyboard") ? 0xf030c
            : i.includes("phone") ? 0xf011c
            : i.includes("gaming") || i.includes("joystick") ? 0xf0eb5
            : 0xf00af)
  }
  function stateText(d) {
    if (d.state === BluetoothDeviceState.Connecting) return "Conectando…"
    if (d.state === BluetoothDeviceState.Disconnecting) return "Desconectando…"
    if (d.pairing) return "Emparejando…"
    if (d.connected) return "Conectado" + (d.batteryAvailable ? ` · ${Math.round(d.battery * 100)}% batería` : "")
    if (d.paired) return "Emparejado"
    return "Disponible"
  }

  visible: adapter !== null
  symbol: true
  text: Theme.sym(!on ? "bluetooth_disabled" : anyConnected ? "bluetooth_connected" : "bluetooth")
  lit: PopupState.current === "bluetooth"
  color: PopupState.current === "bluetooth" ? Theme.accent : on ? Theme.foreground : Theme.muted

  onClicked: mouse => {
    if (mouse.button === Qt.RightButton && adapter) adapter.enabled = !adapter.enabled
    else PopupState.toggle("bluetooth")
  }

  BarPopup {
    id: popup
    name: "bluetooth"
    title: "Bluetooth"
    barWindow: root.barWindow
    anchorItem: root
    // Al cerrar el panel, deja de buscar (gasta batería/radio)
    onOpenChanged: if (!open && root.adapter && root.adapter.discovering) root.adapter.discovering = false

    Toggle {
      label: root.on ? "Activado" : "Desactivado"
      checked: root.on
      onToggled: v => { if (root.adapter) root.adapter.enabled = v }
    }
    Toggle {
      visible: root.on
      label: root.adapter && root.adapter.discovering ? "Buscando dispositivos…" : "Buscar dispositivos"
      checked: root.adapter !== null && root.adapter.discovering
      onToggled: v => { if (root.adapter) root.adapter.discovering = v }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline; visible: root.on }
    Text {
      visible: root.on && root.devices.length === 0
      text: "No hay dispositivos. Activa «Buscar»."
      color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    }
    Repeater {
      model: root.on ? root.devices : []
      ListRow {
        required property var modelData
        readonly property var dev: modelData
        icon: root.devIcon(dev)
        title: dev.name || dev.address
        subtitle: root.stateText(dev)
        active: dev.connected
        detail: dev.paired && !dev.connected ? root.ic(0xf0337) : ""   // eslabón = emparejado
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton) { if (dev.paired) dev.forget() }
          else if (dev.connected) dev.disconnect()
          else if (dev.paired) dev.connect()
          else { dev.trusted = true; dev.pair() }
        }
        // tras emparejar, conecta automáticamente
        Connections {
          target: dev
          function onPairedChanged() { if (dev.paired && !dev.connected) dev.connect() }
        }
      }
    }
    Text {
      visible: root.on && root.devices.some(d => d.paired)
      text: "click derecho sobre un dispositivo emparejado = olvidar"
      color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
      Layout.alignment: Qt.AlignRight
    }
  }
}
