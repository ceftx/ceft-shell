import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Icono de red + panel: cable, wifi on/off, redes con contraseña.
// Click en red: conectar/desconectar · Click derecho en red guardada: olvidar
BarText {
  id: root
  required property var barWindow

  readonly property var devs: Networking.devices.values
  readonly property var wired: devs.find(d => d.type === DeviceType.Wired) ?? null
  readonly property var wifi: devs.find(d => d.type === DeviceType.Wifi) ?? null
  readonly property var networks: wifi ? wifi.networks.values
    .filter(n => n.name)
    .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (sig(b) - sig(a))) : []
  readonly property var activeWifi: networks.find(n => n.connected) ?? null
  property string pskFor: ""   // red que está pidiendo contraseña

  // ── VPN (vía nmcli: Quickshell.Networking no expone VPNs) ──
  property var vpns: []          // [{uuid, name, type, active}]
  property string vpnBusy: ""    // uuid en transición
  property string vpnError: ""
  readonly property bool vpnActive: vpns.some(v => v.active)

  // ── Killswitch (~/.local/bin → /usr/local/bin/vpn-killswitch, sudo sin contraseña) ──
  readonly property string ksBin: "/usr/local/bin/vpn-killswitch"
  property bool ksOn: false
  property bool ksBusy: false
  // ON  = activar killswitch + conectar VPN
  // OFF = desconectar VPN + liberar el Wi-Fi
  function setKillswitch(on) {
    if (ksProc.running) return
    const vpn = vpns.find(v => v.active) ?? vpns[0]
    ksBusy = true; vpnError = ""
    ksProc.command = ["sh", "-c", on
      ? `sudo -n ${ksBin} on && ${vpn ? `nmcli connection up uuid ${vpn.uuid}` : "true"}`
      : `for u in $(nmcli -t -f UUID,TYPE,ACTIVE connection show | awk -F: '($2=="vpn"||$2=="wireguard")&&$3=="yes"{print $1}'); do nmcli connection down uuid "$u"; done; sudo -n ${ksBin} off`]
    ksProc.running = true
  }
  Process {
    id: ksState
    command: [root.ksBin, "state"]
    stdout: StdioCollector { onStreamFinished: if (!root.ksBusy) root.ksOn = text.trim() === "on" }
  }
  Process {
    id: ksProc
    stderr: StdioCollector { id: ksErr }
    onExited: code => {
      if (code !== 0) {
        const e = ksErr.text.trim()
        root.vpnError = /password is required|not found|No such file/.test(e)
          ? "Killswitch sin instalar. En una terminal: sudo bash ~/.local/share/vpn-killswitch/install.sh"
          : (e.split("\n").pop() || "Error en el killswitch")
      }
      root.ksBusy = false
      root.refreshVpns()
    }
  }

  function refreshVpns() {
    if (!vpnList.running) vpnList.running = true
    if (!ksState.running) ksState.running = true
  }
  function toggleVpn(v) {
    if (vpnToggle.running) return
    vpnBusy = v.uuid; vpnError = ""
    vpnToggle.command = ["nmcli", "connection", v.active ? "down" : "up", "uuid", v.uuid]
    vpnToggle.running = true
  }

  Process {
    id: vpnList
    command: ["nmcli", "-t", "-f", "UUID,TYPE,ACTIVE,NAME", "connection", "show"]
    stdout: StdioCollector {
      onStreamFinished: {
        const out = []
        for (const line of text.split("\n")) {
          // UUID, TYPE y ACTIVE no llevan ':'; el resto es el nombre (con '\:' escapados)
          const p = line.split(":")
          if (p.length < 4) continue
          const type = p[1]
          if (type !== "vpn" && type !== "wireguard") continue
          out.push({ uuid: p[0], type: type, active: p[2] === "yes",
                     name: p.slice(3).join(":").replace(/\\:/g, ":").replace(/\\\\/g, "\\") })
        }
        root.vpns = out
      }
    }
  }
  Process {
    id: vpnToggle
    stderr: StdioCollector { id: vpnErr }
    onExited: code => {
      if (code !== 0) root.vpnError = (vpnErr.text.trim().split("\n").pop() || "Error al conectar").replace(/^Error:\s*/, "")
      root.vpnBusy = ""
      root.refreshVpns()
    }
  }
  // Mantener el icono de la barra al día; más rápido con el panel abierto
  Timer {
    interval: PopupState.current === "network" ? 2000 : 15000
    running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.refreshVpns()
  }

  function ic(cp) { return String.fromCodePoint(cp) }
  function sig(n) { const s = n.signalStrength ?? 0; return s > 1 ? s / 100 : s }
  function wifiIcon(s) { return ic([0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928][Math.min(4, Math.ceil(s * 4))]) }
  function secured(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe }
  function stateText(n) {
    if (n.state === ConnectionState.Connecting) return "Conectando…"
    if (n.state === ConnectionState.Disconnecting) return "Desconectando…"
    if (n.connected) return "Conectada"
    return n.known ? "Guardada" : secured(n) ? "Protegida" : "Abierta"
  }

  readonly property string kind: wired && wired.connected ? "ethernet" : activeWifi ? "wifi" : "none"
  symbol: true
  filled: kind !== "none"
  text: Theme.sym(kind === "ethernet" ? "lan" : kind === "wifi" ? ["wifi_1_bar", "wifi_1_bar", "wifi_2_bar", "wifi", "wifi"][Math.min(4, Math.ceil(sig(activeWifi) * 4))] : "wifi_off"
        + (vpnActive ? " vpn_key"          // llave si hay VPN activa
           : ksOn ? " lock" : ""))          // candado: killswitch bloqueando (VPN caída)
  lit: PopupState.current === "network"
  color: PopupState.current === "network" ? Theme.accent
       : ksOn && !vpnActive ? Theme.active
       : kind === "none" ? Theme.muted : Theme.foreground

  onClicked: PopupState.toggle("network")

  BarPopup {
    name: "network"
    title: "Red"
    barWindow: root.barWindow
    anchorItem: root
    panelWidth: 340
    // Escanea solo mientras el panel está abierto
    onOpenChanged: {
      if (root.wifi) root.wifi.scannerEnabled = open
      if (!open) { root.pskFor = ""; root.vpnError = "" } else root.refreshVpns()
    }

    // ── Cable ──
    ListRow {
      visible: root.wired !== null
      icon: root.ic(root.wired && root.wired.connected ? 0xf0200 : 0xf0201)
      title: "Ethernet" + (root.wired ? " · " + root.wired.name : "")
      subtitle: !root.wired ? "" : !root.wired.hasLink ? "Cable desconectado"
              : root.wired.connected ? "Conectado" + (root.wired.linkSpeed > 0 ? ` · ${root.wired.linkSpeed} Mb/s` : "") : "Desconectado"
      active: root.wired !== null && root.wired.connected
      onClicked: if (root.wired && root.wired.connected) root.wired.disconnect()
                 else if (root.wired && root.wired.network) root.wired.network.connect()
    }

    // ── Wifi ──
    Toggle {
      visible: root.wifi !== null
      label: "Wi-Fi" + (root.wifi ? " · " + root.wifi.name : "")
      checked: Networking.wifiEnabled
      onToggled: v => Networking.wifiEnabled = v
    }
    Text {
      visible: !root.wifi
      text: "No hay tarjeta Wi-Fi"
      color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    }
    Text {
      visible: root.wifi !== null && Networking.wifiEnabled && root.networks.length === 0
      text: "Buscando redes…"
      color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    }

    Flickable {
      visible: root.wifi !== null && Networking.wifiEnabled
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(netCol.implicitHeight, 360)
      contentHeight: netCol.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: netCol
        width: parent.width
        spacing: 2
        Repeater {
          model: root.networks
          ListRow {
            id: row
            required property var modelData
            readonly property var net: modelData
            readonly property bool asking: root.pskFor === net.name
            icon: root.wifiIcon(root.sig(net))
            title: net.name
            property bool failed: false
            subtitle: failed && !net.connected && !net.stateChanging ? "Error al conectar" : root.stateText(net)
            busy: net.stateChanging
            active: net.connected
            detail: root.secured(net) ? root.ic(0xf033e) : ""   // candado
            onClicked: mouse => {
              if (mouse.button === Qt.RightButton) { if (net.known) net.forget() }
              else if (net.connected) net.disconnect()
              else if (net.known || !root.secured(net)) net.connect()
              else root.pskFor = asking ? "" : net.name
              failed = false
            }
            Connections {
              target: row.net
              // contraseña guardada incorrecta -> volver a pedirla
              function onConnectionFailed(reason) {
                row.failed = true
                if (reason === ConnectionFailReason.NoSecrets) root.pskFor = row.net.name
              }
              function onConnectedChanged() { if (row.net.connected) row.failed = false }
            }

            // Campo de contraseña (solo para la red seleccionada)
            RowLayout {
              visible: row.asking
              Layout.fillWidth: true
              spacing: 6
              TextField {
                id: psk
                Layout.fillWidth: true
                echoMode: show.checked ? TextInput.Normal : TextInput.Password
                placeholderText: "Contraseña"
                color: Theme.foreground
                placeholderTextColor: Theme.dim
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBase
                background: Rectangle { radius: 8; color: Qt.alpha(Theme.foreground, 0.08); border.color: psk.activeFocus ? Theme.accent : Theme.glassEdge }
                onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                onAccepted: if (text.length >= 8) { row.net.connectWithPsk(text); root.pskFor = "" }
                Keys.onEscapePressed: root.pskFor = ""
              }
              CheckBox { id: show; visible: false }
              Text {
                text: root.ic(show.checked ? 0xf0209 : 0xf0208)   // ojo
                color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontBase + 2
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: show.checked = !show.checked }
              }
              Rectangle {
                implicitWidth: 72; implicitHeight: 28; radius: 14
                color: psk.text.length >= 8 ? Theme.accent : Qt.alpha(Theme.foreground, 0.08)
                Text {
                  anchors.centerIn: parent; text: "Conectar"
                  color: psk.text.length >= 8 ? Theme.background : Theme.dim
                  font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: psk.accepted() }
              }
            }
          }
        }
      }
    }

    // ── VPN ──
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
    Text {
      text: "VPN"
      color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize; font.bold: true
    }
    Toggle {
      label: "Killswitch" + (root.ksBusy ? " · …" : "")
      checked: root.ksOn
      onToggled: v => { root.ksOn = v; root.setKillswitch(v) }
    }
    Text {
      visible: root.ksOn && !root.vpnActive
      Layout.fillWidth: true
      wrapMode: Text.Wrap
      text: "Sin VPN no hay internet. Apagá el killswitch para usar el Wi-Fi directo."
      color: Theme.active; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    }
    Text {
      visible: root.vpns.length === 0
      text: "No hay VPNs configuradas"
      color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    }
    Repeater {
      model: root.vpns
      ListRow {
        required property var modelData
        readonly property bool busyRow: root.vpnBusy === modelData.uuid
        icon: root.ic(modelData.active ? 0xf0582 : 0xf099d)   // escudo / escudo-off
        title: modelData.name
        subtitle: busyRow ? (modelData.active ? "Desconectando…" : "Conectando…")
                : modelData.active ? "Conectada" : (modelData.type === "wireguard" ? "WireGuard" : "OpenVPN")
        busy: busyRow
        active: modelData.active
        onClicked: root.toggleVpn(modelData)
      }
    }
    Text {
      visible: root.vpnError !== ""
      Layout.fillWidth: true
      wrapMode: Text.Wrap
      text: root.vpnError
      color: Theme.active; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
    RowLayout {
      Layout.fillWidth: true
      Text {
        text: "Importar VPN " + root.ic(0xf0142)
        color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: PopupState.openNetSettings("new") }
      }
      Item { Layout.fillWidth: true }
      Text {
        text: "Configuración de red " + root.ic(0xf0142)
        color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: PopupState.openNetSettings("summary") }
      }
    }
  }
}
