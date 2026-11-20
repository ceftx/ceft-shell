pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// Estado de red para el panel: Wi-Fi, VPN y killswitch. Misma lógica y mismos comandos que NetworkWidget
// (nmcli para VPN; /usr/local/bin/vpn-killswitch con sudo sin contraseña para el killswitch).
// Hooks de prueba: CEFT_SIDEBAR_DRYRUN=1 no ejecuta los cambios de VPN/killswitch (los anota en
// $XDG_RUNTIME_DIR/ceft-sidebar-dryrun).
Singleton {
  id: root
  readonly property bool dryRun: (Quickshell.env("CEFT_SIDEBAR_DRYRUN") || "") === "1"

  readonly property var devs: Networking.devices.values
  readonly property var wifi: devs.find(d => d.type === DeviceType.Wifi) ?? null
  readonly property var wired: devs.find(d => d.type === DeviceType.Wired) ?? null
  readonly property bool wifiOn: Networking.wifiEnabled
  readonly property var activeWifi: wifi ? (wifi.networks.values.find(n => n.connected) ?? null) : null
  readonly property string wifiLabel: !wifi ? "Sin Wi-Fi" : activeWifi ? activeWifi.name : wifiOn ? "Sin conexión" : "Apagado"

  property var vpns: []
  property string vpnBusy: ""
  property string error: ""
  readonly property bool vpnActive: vpns.some(v => v.active)
  readonly property string vpnLabel: vpns.length === 0 ? "Sin VPN" : (vpns.find(v => v.active) ?? vpns[0]).name

  readonly property string ksBin: "/usr/local/bin/vpn-killswitch"
  property bool ksOn: false
  property bool ksBusy: false

  function refresh() {
    if (!vpnList.running) vpnList.running = true
    if (!ksState.running) ksState.running = true
  }
  function note(what) {
    Quickshell.execDetached(["sh", "-c", "echo \"$1\" >> \"${XDG_RUNTIME_DIR:-/tmp}/ceft-sidebar-dryrun\"", "sh", what])
  }

  function toggleVpn() {
    if (vpnToggle.running || vpns.length === 0) return
    const v = vpns.find(x => x.active) ?? vpns[0]
    vpnBusy = v.uuid; error = ""
    if (dryRun) { note("vpn " + (v.active ? "down" : "up")); vpnBusy = ""; return }
    vpnToggle.command = ["nmcli", "connection", v.active ? "down" : "up", "uuid", v.uuid]
    vpnToggle.running = true
  }

  function setKillswitch(on) {
    if (ksProc.running) return
    const vpn = vpns.find(v => v.active) ?? vpns[0]
    ksBusy = true; error = ""
    if (dryRun) { note("killswitch " + (on ? "on" : "off")); ksBusy = false; return }
    ksProc.command = ["sh", "-c", on
      ? `sudo -n ${ksBin} on && ${vpn ? `nmcli connection up uuid ${vpn.uuid}` : "true"}`
      : `for u in $(nmcli -t -f UUID,TYPE,ACTIVE connection show | awk -F: '($2=="vpn"||$2=="wireguard")&&$3=="yes"{print $1}'); do nmcli connection down uuid "$u"; done; sudo -n ${ksBin} off`]
    ksProc.running = true
  }

  Process {
    id: vpnList
    command: ["nmcli", "-t", "-f", "UUID,TYPE,ACTIVE,NAME", "connection", "show"]
    stdout: StdioCollector {
      onStreamFinished: {
        const out = []
        for (const line of text.split("\n")) {
          const p = line.split(":")
          if (p.length < 4) continue
          if (p[1] !== "vpn" && p[1] !== "wireguard") continue
          out.push({ uuid: p[0], type: p[1], active: p[2] === "yes",
                     name: p.slice(3).join(":").replace(/\\:/g, ":").replace(/\\\\/g, "\\") })
        }
        root.vpns = out
      }
    }
  }
  Process {
    id: ksState
    command: [root.ksBin, "state"]
    stdout: StdioCollector { onStreamFinished: if (!root.ksBusy) root.ksOn = text.trim() === "on" }
  }
  Process {
    id: vpnToggle
    stderr: StdioCollector { id: vpnErr }
    onExited: code => {
      if (code !== 0) root.error = (vpnErr.text.trim().split("\n").pop() || "Error al conectar").replace(/^Error:\s*/, "")
      root.vpnBusy = ""
      root.refresh()
    }
  }
  Process {
    id: ksProc
    stderr: StdioCollector { id: ksErr }
    onExited: code => {
      if (code !== 0) {
        const e = ksErr.text.trim()
        root.error = /password is required|not found|No such file/.test(e)
          ? "Killswitch sin instalar" : (e.split("\n").pop() || "Error en el killswitch")
      }
      root.ksBusy = false
      root.refresh()
    }
  }
  property bool watching: false   // el panel lo prende al abrirse: refresco rápido
  Timer { interval: root.watching ? 2500 : 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
