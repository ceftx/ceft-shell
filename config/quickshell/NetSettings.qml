import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Configuración de red completa sobre nmcli (reemplaza a nmtui).
// Abrir: PopupState.openNetSettings(tab) · qs ipc call netsettings open
PanelWindow {
  id: win
  readonly property bool open: PopupState.netSettings !== ""
  visible: open
  implicitWidth: 1100
  implicitHeight: 720
  color: "transparent"
  exclusiveZone: 0
  WlrLayershell.namespace: "quickshell-netsettings"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  function ic(cp) { return String.fromCodePoint(cp) }
  readonly property string nmpy: Quickshell.env("HOME") + "/.config/quickshell/scripts/nm.py"

  // ───────── estado ─────────
  property var st: ({ general: {}, devices: [], connections: [] })
  property string tab: "summary"
  property string selConn: ""          // uuid
  property string selDev: ""           // nombre de dispositivo
  property string connView: "basic"    // basic | all | secrets
  property var props: []               // [{key, value, readonly}] de selConn
  property var secrets: []             // [{key, value}]
  property var edits: ({})             // key -> valor nuevo
  property int editCount: 0
  property var wifiNets: []
  property bool scanning: false
  property string connFilter: ""
  property string propFilter: ""
  property bool showVirtual: false
  property string msg: ""
  property bool msgErr: false
  property string confirmText: ""
  property var confirmAction: null
  property var afterRun: null
  property var vpnFiles: []
  property string wifiPick: ""        // BSSID con el formulario abierto

  onOpenChanged: {
    if (open) { tab = PopupState.netSettings; refresh(); if (tab === "wifi") scanWifi(false) }
    else { confirmText = ""; msg = "" }
  }
  Connections {
    target: PopupState
    function onNetSettingsChanged() { if (PopupState.netSettings !== "") win.tab = PopupState.netSettings }
  }
  onTabChanged: {
    if (tab === "wifi") scanWifi(false)
    if (tab === "new") findVpnFiles()
  }

  readonly property var conn: st.connections.find(c => c.uuid === selConn) ?? null
  readonly property var dev: st.devices.find(d => d.device === selDev) ?? null
  function isVirtual(d) { return d.type === "loopback" || d.device.startsWith("veth") || d.type === "bridge" && d.device.startsWith("br-") || d.device === "docker0" }
  function propVal(k) { const p = props.find(x => x.key === k); return p ? p.value : undefined }
  function cur(k) { return k in edits ? edits[k] : (propVal(k) ?? (secrets.find(s => s.key === k) ?? {}).value ?? "") }
  function setEdit(k, v) {
    const e = Object.assign({}, edits)
    const orig = propVal(k) ?? (secrets.find(s => s.key === k) ?? {}).value ?? ""
    if (v === orig) delete e[k]; else e[k] = v
    edits = e; editCount = Object.keys(e).length
  }
  function typeIcon(t) {
    return ic(t === "802-11-wireless" || t === "wifi" ? 0xf05a9
            : t === "802-3-ethernet" || t === "ethernet" ? 0xf0200
            : t === "vpn" || t === "wireguard" ? 0xf0582
            : t === "bridge" ? 0xf0b0f : t === "loopback" ? 0xf0453
            : t === "tun" ? 0xf0318 : 0xf06f3)
  }
  function typeName(t) {
    return ({ "802-11-wireless": "Wi-Fi", "802-3-ethernet": "Ethernet", "vpn": "VPN", "wireguard": "WireGuard",
              "bridge": "Bridge", "tun": "Túnel", "loopback": "Loopback", "dummy": "Dummy", "wifi": "Wi-Fi",
              "ethernet": "Ethernet", "gsm": "Móvil", "bond": "Bond", "vlan": "VLAN" })[t] ?? t
  }
  function say(t, err) { msg = t; msgErr = !!err; msgTimer.restart() }
  function ask(text, action) { confirmText = text; confirmAction = action }

  // ───────── procesos ─────────
  function refresh() { if (!stateProc.running) stateProc.running = true }
  function loadConn() {
    if (!selConn) return
    showProc.command = ["python3", "-I", nmpy, "show", selConn]
    showProc.running = true
  }
  function selectConn(uuid) {
    selConn = uuid; selDev = ""; props = []; secrets = []; edits = ({}); editCount = 0; propFilter = ""
    loadConn()
  }
  function loadSecrets() {
    secretsProc.command = ["python3", "-I", nmpy, "secrets", selConn]
    secretsProc.running = true
  }
  function scanWifi(rescan) {
    if (wifiProc.running) return
    scanning = rescan
    wifiProc.command = ["python3", "-I", nmpy, "wifi"].concat(rescan ? ["rescan"] : [])
    wifiProc.running = true
  }
  // Ejecuta `nmcli args...`; then(res) se llama al terminar bien
  function run(args, okText, then) {
    if (runProc.running) { say("Esperá a que termine la acción anterior", true); return }
    afterRun = { okText: okText, then: then ?? null }
    runProc.command = ["python3", "-I", nmpy, "run"].concat(args)
    runProc.running = true
  }
  function save() {
    if (!selConn || editCount === 0) return
    const args = ["connection", "modify", "uuid", selConn]
    for (const k in edits) args.push(k, edits[k])
    run(args, "Cambios guardados", () => { edits = ({}); editCount = 0; loadConn(); if (secrets.length) loadSecrets() })
  }
  function deleteConn() {
    if (!conn) return
    const u = selConn, n = conn.name
    ask(`¿Eliminar la conexión "${n}"? No se puede deshacer.`,
        () => run(["connection", "delete", "uuid", u], `"${n}" eliminada`, () => { selConn = ""; props = [] }))
  }
  function findVpnFiles() {
    if (!findProc.running) findProc.running = true
  }

  Process {
    id: stateProc
    command: ["python3", "-I", win.nmpy, "state"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { const d = JSON.parse(text); if (d.ok === false) win.say(d.err, true); else win.st = d }
        catch (e) { win.say("No pude leer el estado de NetworkManager", true) }
      }
    }
  }
  Process {
    id: showProc
    stdout: StdioCollector {
      onStreamFinished: {
        try { const d = JSON.parse(text); if (d.ok === false) win.say(d.err, true); else if (d.uuid === win.selConn) win.props = d.props }
        catch (e) { win.say("No pude leer la conexión", true) }
      }
    }
  }
  Process {
    id: secretsProc
    stdout: StdioCollector {
      onStreamFinished: {
        try { const d = JSON.parse(text); if (d.ok === false) win.say(d.err, true); else { win.secrets = d.secrets; if (!d.secrets.length) win.say("Esta conexión no tiene contraseñas guardadas") } }
        catch (e) { win.say("No pude leer las contraseñas", true) }
      }
    }
  }
  Process {
    id: wifiProc
    stdout: StdioCollector {
      onStreamFinished: {
        win.scanning = false
        try { const d = JSON.parse(text); if (d.ok === false) win.say(d.err, true); else win.wifiNets = d.networks }
        catch (e) { win.say("No pude listar las redes Wi-Fi", true) }
      }
    }
  }
  Process {
    id: runProc
    stdout: StdioCollector {
      onStreamFinished: {
        const a = win.afterRun; win.afterRun = null
        let d
        try { d = JSON.parse(text) } catch (e) { win.say("Error ejecutando nmcli", true); return }
        if (d.ok) {
          win.say(a && a.okText ? a.okText : (d.out || "Hecho"))
          if (a && a.then) a.then(d)
        } else win.say((d.err || "Error").replace(/^Error:\s*/, ""), true)
        win.refresh()
      }
    }
  }
  Process {
    id: findProc
    command: ["sh", "-c", "find \"$HOME\" -maxdepth 4 -type f \\( -name '*.ovpn' -o -name '*.conf' -path '*wireguard*' -o -name 'wg*.conf' \\) -not -path '*/.cache/*' -not -path '*/node_modules/*' 2>/dev/null | head -50"]
    stdout: StdioCollector { onStreamFinished: win.vpnFiles = text.split("\n").filter(x => x) }
  }
  // Cambios en vivo: nmcli monitor -> refresco (con antirrebote)
  Process {
    running: win.open
    command: ["nmcli", "monitor"]
    stdout: SplitParser { onRead: _ => debounce.restart() }
  }
  Timer { id: debounce; interval: 400; onTriggered: { win.refresh(); if (win.tab === "wifi") win.scanWifi(false) } }
  Timer { id: msgTimer; interval: 6000; onTriggered: win.msg = "" }

  // ───────── IPC (también usado para pruebas) ─────────
  IpcHandler {
    target: "netsettings"
    function open(): void { PopupState.openNetSettings("summary") }
    function openTab(t: string): void { PopupState.openNetSettings(t) }
    function close(): void { PopupState.closeNetSettings() }
    function selectConn(uuid: string): void { win.tab = "conns"; win.selectConn(uuid) }
    function selectDev(name: string): void { win.tab = "devices"; win.selDev = name }
    function view(v: string): void { win.connView = v; if (v === "secrets") win.loadSecrets() }
    function edit(key: string, value: string): void { win.setEdit(key, value) }
    function save(): void { win.save() }
    function remove(): void { win.deleteConn() }
    function confirm(): void { if (win.confirmAction) win.confirmAction(); win.confirmText = "" }
    function dump(): string {
      return JSON.stringify({ open: win.open, tab: win.tab, selConn: win.selConn, props: win.props.length, secrets: win.secrets.length,
                              edits: win.edits, msg: win.msg, msgErr: win.msgErr, confirm: win.confirmText,
                              conns: win.st.connections.length, devs: win.st.devices.length, wifi: win.wifiNets.length })
    }
  }

  // ───────── componentes ─────────
  component Lbl: Text {
    color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase
    elide: Text.ElideRight
  }
  component Dim: Text {
    color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    wrapMode: Text.Wrap
  }
  component Head: Text {
    color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase; font.bold: true
    Layout.topMargin: 6
  }
  component Btn: Rectangle {
    id: b
    property string text
    property bool primary: false
    property bool danger: false
    signal clicked()
    implicitWidth: bt.implicitWidth + 22; implicitHeight: 28; radius: 5
    opacity: enabled ? 1 : 0.4
    color: primary ? Theme.accent : danger && ba.containsMouse ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2)
         : ba.containsMouse ? Theme.border : Theme.surface
    border.color: danger ? Theme.active : Theme.border
    Text {
      id: bt; anchors.centerIn: parent; text: b.text
      color: b.primary ? Theme.background : b.danger ? Theme.active : Theme.foreground
      font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    }
    MouseArea { id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: b.enabled; onClicked: b.clicked() }
  }
  component Field: TextField {
    id: f
    property bool changed: false
    Layout.fillWidth: true
    implicitHeight: 28
    color: Theme.foreground
    placeholderTextColor: Theme.dim
    selectByMouse: true
    font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    leftPadding: 8; rightPadding: 8; topPadding: 4; bottomPadding: 4
    background: Rectangle {
      radius: 4; color: f.enabled ? Theme.surface : "transparent"
      border.color: f.activeFocus ? Theme.accent : f.changed ? Theme.yellow : Theme.border
    }
  }
  // Selector de opciones en "chips"
  component Chips: Flow {
    id: ch
    property var options: []
    property string value: ""
    property var labels: ({})
    signal picked(string v)
    Layout.fillWidth: true
    spacing: 4
    Repeater {
      model: ch.options
      Rectangle {
        required property string modelData
        readonly property bool on: ch.value === modelData
        implicitWidth: ct.implicitWidth + 16; implicitHeight: 24; radius: 12
        color: on ? Theme.accent : ca.containsMouse ? Theme.border : Theme.surface
        Text {
          id: ct; anchors.centerIn: parent
          text: ch.labels[parent.modelData] ?? parent.modelData
          color: parent.on ? Theme.background : Theme.foreground
          font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
        }
        MouseArea { id: ca; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.picked(parent.modelData) }
      }
    }
  }
  component KV: RowLayout {
    property string k
    property string v
    Layout.fillWidth: true
    visible: v !== ""
    spacing: 10
    Text { text: parent.k; color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize; Layout.preferredWidth: 130 }
    TextEdit {
      text: parent.v; readOnly: true; selectByMouse: true; Layout.fillWidth: true; wrapMode: TextEdit.Wrap
      color: Theme.foreground; selectionColor: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    }
  }
  component Sw: Rectangle {
    id: s
    property bool checked
    signal toggled(bool v)
    implicitWidth: 36; implicitHeight: 20; radius: 10
    color: checked ? Theme.accent : Theme.surface
    border.color: Theme.border
    Rectangle {
      width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter
      x: s.checked ? parent.width - width - 3 : 3
      color: s.checked ? Theme.background : Theme.dim
      Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: s.toggled(!s.checked) }
  }
  component Row2: Rectangle {   // fila de lista seleccionable
    id: r
    property string icon
    property string title
    property string subtitle
    property bool selected
    property bool live
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 42; radius: 6
    color: selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : ra.containsMouse ? Theme.surface : "transparent"
    RowLayout {
      anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
      spacing: 10
      Text { text: r.icon; color: r.live ? Theme.green : Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontBase + 3; Layout.preferredWidth: 20 }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 0
        Text { text: r.title; elide: Text.ElideRight; Layout.fillWidth: true; color: r.selected ? Theme.accent : Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase; font.bold: r.live }
        Text { text: r.subtitle; visible: text !== ""; elide: Text.ElideRight; Layout.fillWidth: true; color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize }
      }
    }
    MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.clicked() }
  }
  // Fila de propiedad editable (clave + campo / chips)
  component PropRow: RowLayout {
    id: pr
    property string k
    property string label
    property string value
    property string orig
    property var options: []
    property bool readonly: false
    property bool secret: false
    signal edited(string v)
    Layout.fillWidth: true
    spacing: 10
    Text {
      text: pr.label || pr.k; color: pr.value !== pr.orig ? Theme.yellow : Theme.dim
      font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
      Layout.preferredWidth: 190; Layout.maximumWidth: 190; elide: Text.ElideMiddle
    }
    Chips {
      visible: pr.options.length > 0
      options: pr.options; value: pr.value
      onPicked: v => pr.edited(v)
    }
    Field {
      id: pf
      visible: pr.options.length === 0
      enabled: !pr.readonly
      text: pr.value
      changed: pr.value !== pr.orig
      echoMode: pr.secret && !eye.on ? TextInput.Password : TextInput.Normal
      placeholderText: pr.readonly ? "" : "(vacío)"
      onTextEdited: pr.edited(text)
    }
    Text {
      id: eye
      property bool on: false
      visible: pr.secret
      text: String.fromCodePoint(on ? 0xf0209 : 0xf0208)
      color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontBase + 2
      MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: eye.on = !eye.on }
    }
  }

  // ───────── fondo oscuro: click fuera cierra ─────────
  PanelWindow {
    screen: win.screen
    visible: win.open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: Qt.rgba(0, 0, 0, 0.35)
    WlrLayershell.namespace: "quickshell-netsettings-scrim"
    WlrLayershell.layer: WlrLayer.Top
    MouseArea { anchors.fill: parent; onPressed: PopupState.closeNetSettings() }
  }

  // ───────── ventana ─────────
  Rectangle {
    anchors.fill: parent
    radius: Theme.radius
    color: Theme.glassPopup
    border.color: Theme.glassEdge
    focus: true
    Keys.onEscapePressed: win.confirmText !== "" ? win.confirmText = "" : PopupState.closeNetSettings()

    RowLayout {
      anchors { fill: parent; margins: 14 }
      spacing: 14

      // ── barra lateral ──
      ColumnLayout {
        Layout.preferredWidth: 190
        Layout.maximumWidth: 190
        Layout.fillHeight: true
        spacing: 4
        Text {
          text: win.ic(0xf06f3) + "  Red"
          color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase + 4; font.bold: true
          Layout.bottomMargin: 10
        }
        Repeater {
          model: [
            { id: "summary", label: "Resumen", icon: 0xf0f3e },
            { id: "devices", label: "Dispositivos", icon: 0xf0318 },
            { id: "conns", label: "Conexiones", icon: 0xf0337 },
            { id: "wifi", label: "Wi-Fi", icon: 0xf05a9 },
            { id: "new", label: "Nueva / importar", icon: 0xf0415 }
          ]
          Row2 {
            required property var modelData
            icon: win.ic(modelData.icon); title: modelData.label
            selected: win.tab === modelData.id
            onClicked: win.tab = modelData.id
          }
        }
        Item { Layout.fillHeight: true }
        Dim {
          Layout.fillWidth: true
          text: (win.st.general.state ?? "…") + " · " + (win.st.general.connectivity ?? "")
        }
        Btn { text: "Cerrar  Esc"; Layout.fillWidth: true; onClicked: PopupState.closeNetSettings() }
      }
      Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }

      // ── contenido ──
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        StackLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          currentIndex: ["summary", "devices", "conns", "wifi", "new"].indexOf(win.tab)

          // ════════ RESUMEN ════════
          Flickable {
            contentHeight: sumCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
              id: sumCol
              width: parent.width
              spacing: 8
              Head { text: "Estado" }
              KV { k: "Estado"; v: win.st.general.state ?? "" }
              KV { k: "Conectividad"; v: win.st.general.connectivity ?? "" }
              KV { k: "Nombre del equipo"; v: win.st.general.hostname ?? "" }

              Head { text: "Interruptores" }
              RowLayout {
                Layout.fillWidth: true
                Lbl { text: "Red (NetworkManager)"; Layout.fillWidth: true }
                Sw {
                  checked: win.st.general.networking === "enabled"
                  onToggled: v => v ? win.run(["networking", "on"], "Red activada")
                    : win.ask("¿Apagar toda la red? Se cortan todas las conexiones.", () => win.run(["networking", "off"], "Red apagada"))
                }
              }
              RowLayout {
                Layout.fillWidth: true
                Lbl { text: "Wi-Fi" + (win.st.general.wifi_hw === "missing" ? " (sin hardware)" : ""); Layout.fillWidth: true }
                Sw { checked: win.st.general.wifi === "enabled"; onToggled: v => win.run(["radio", "wifi", v ? "on" : "off"], v ? "Wi-Fi encendido" : "Wi-Fi apagado") }
              }
              RowLayout {
                visible: win.st.general.wwan_hw !== "missing"
                Layout.fillWidth: true
                Lbl { text: "Datos móviles (WWAN)"; Layout.fillWidth: true }
                Sw { checked: win.st.general.wwan === "enabled"; onToggled: v => win.run(["radio", "wwan", v ? "on" : "off"]) }
              }

              Head { text: "Nombre del equipo" }
              RowLayout {
                Layout.fillWidth: true
                Field { id: hostField; text: win.st.general.hostname ?? ""; placeholderText: "hostname" }
                Btn { text: "Cambiar"; enabled: hostField.text !== "" && hostField.text !== win.st.general.hostname; onClicked: win.run(["general", "hostname", hostField.text], "Nombre cambiado") }
              }

              Head { text: "Conexiones activas" }
              Repeater {
                model: win.st.connections.filter(c => c.active === "yes" && !win.isVirtual({ type: c.type, device: c.device }))
                Row2 {
                  required property var modelData
                  icon: win.typeIcon(modelData.type); live: true
                  title: modelData.name
                  subtitle: win.typeName(modelData.type) + " · " + modelData.device
                  onClicked: { win.tab = "conns"; win.selectConn(modelData.uuid) }
                }
              }

              Head { text: "Herramientas" }
              Flow {
                Layout.fillWidth: true; spacing: 6
                Btn { text: "Comprobar conectividad"; onClicked: win.run(["networking", "connectivity", "check"], "", d => win.say("Conectividad: " + d.out)) }
                Btn { text: "Recargar perfiles del disco"; onClicked: win.run(["connection", "reload"], "Perfiles recargados") }
                Btn { text: "Permisos"; onClicked: win.run(["general", "permissions"], "", d => win.say(d.out.split("\n").filter(l => / no$| auth$/.test(l)).length + " permisos requieren autenticación")) }
              }
            }
          }

          // ════════ DISPOSITIVOS ════════
          RowLayout {
            spacing: 12
            ColumnLayout {
              Layout.preferredWidth: 250; Layout.maximumWidth: 250; Layout.fillHeight: true
              spacing: 2
              RowLayout {
                Lbl { text: "Mostrar virtuales"; color: Theme.dim; font.pixelSize: Theme.fontSize; Layout.fillWidth: true }
                Sw { checked: win.showVirtual; onToggled: v => win.showVirtual = v }
              }
              Flickable {
                Layout.fillWidth: true; Layout.fillHeight: true
                contentHeight: devCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                  id: devCol; width: parent.width; spacing: 2
                  Repeater {
                    model: win.st.devices.filter(d => win.showVirtual || !win.isVirtual(d))
                    Row2 {
                      required property var modelData
                      icon: win.typeIcon(modelData.type)
                      title: modelData.device
                      subtitle: win.typeName(modelData.type) + " · " + modelData.state
                      live: modelData.state.startsWith("connected")
                      selected: win.selDev === modelData.device
                      onClicked: win.selDev = modelData.device
                    }
                  }
                }
              }
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }
            Flickable {
              Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 300
              contentHeight: devDet.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
              ColumnLayout {
                id: devDet; width: parent.width; spacing: 6
                Dim { visible: !win.dev; text: "Elegí un dispositivo"; Layout.fillWidth: true }
                Text {
                  visible: !!win.dev
                  text: win.dev ? win.typeIcon(win.dev.type) + "  " + win.dev.device : ""
                  color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase + 3; font.bold: true
                }
                KV { k: "Tipo"; v: win.dev ? win.typeName(win.dev.type) : "" }
                KV { k: "Estado"; v: win.dev ? (win.dev.state_full ?? win.dev.state) : "" }
                KV { k: "Conexión"; v: win.dev ? win.dev.connection : "" }
                KV { k: "MAC"; v: win.dev ? (win.dev.hwaddr ?? "") : "" }
                KV { k: "MTU"; v: win.dev ? (win.dev.mtu ?? "") : "" }
                KV { k: "Hardware"; v: win.dev ? [win.dev.vendor, win.dev.product].filter(x => x).join(" ") : "" }
                KV { k: "Driver"; v: win.dev ? (win.dev.driver ?? "") : "" }
                KV { k: "Cable"; v: win.dev && win.dev.carrier ? (win.dev.carrier === "on" ? "conectado" : "desconectado") : "" }
                KV { k: "IPv4"; v: win.dev && win.dev.ip4 ? win.dev.ip4.join("\n") : "" }
                KV { k: "Puerta de enlace"; v: win.dev ? (win.dev.gw4 ?? "") : "" }
                KV { k: "DNS"; v: win.dev && win.dev.dns4 ? win.dev.dns4.concat(win.dev.dns6 ?? []).join("\n") : "" }
                KV { k: "IPv6"; v: win.dev && win.dev.ip6 ? win.dev.ip6.join("\n") : "" }
                KV { k: "Gateway IPv6"; v: win.dev ? (win.dev.gw6 ?? "") : "" }
                KV { k: "Rutas IPv4"; v: win.dev && win.dev.routes4 ? win.dev.routes4.join("\n") : "" }
                Flow {
                  visible: !!win.dev
                  Layout.fillWidth: true; Layout.topMargin: 8; spacing: 6
                  Btn { text: "Conectar"; onClicked: win.run(["device", "connect", win.selDev], "Dispositivo conectado") }
                  Btn {
                    text: "Desconectar"; danger: true
                    onClicked: { const d = win.selDev; win.ask(`¿Desconectar ${d}? Puede cortar tu conexión a internet.`, () => win.run(["device", "disconnect", d], "Dispositivo desconectado")) }
                  }
                  Btn { text: "Reaplicar config"; onClicked: win.run(["device", "reapply", win.selDev], "Configuración reaplicada") }
                  Btn {
                    readonly property bool unmanaged: win.dev && win.dev.state === "unmanaged"
                    text: unmanaged ? "Gestionar con NM" : "Dejar de gestionar"
                    onClicked: {
                      const d = win.selDev, u = unmanaged
                      if (u) win.run(["device", "set", d, "managed", "yes"], "Ahora NetworkManager gestiona " + d)
                      else win.ask(`¿Que NetworkManager deje de gestionar ${d}?`, () => win.run(["device", "set", d, "managed", "no"], d + " ya no está gestionado"))
                    }
                  }
                }
              }
            }
          }

          // ════════ CONEXIONES ════════
          RowLayout {
            spacing: 12
            ColumnLayout {
              Layout.preferredWidth: 250; Layout.maximumWidth: 250; Layout.fillHeight: true
              spacing: 4
              Field { placeholderText: "Buscar conexión…"; onTextEdited: win.connFilter = text.toLowerCase() }
              Flickable {
                Layout.fillWidth: true; Layout.fillHeight: true
                contentHeight: connCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                  id: connCol; width: parent.width; spacing: 2
                  Repeater {
                    model: win.st.connections
                      .filter(c => (win.showVirtual || !win.isVirtual({ type: c.type, device: c.name })) && c.name.toLowerCase().includes(win.connFilter))
                      .sort((a, b) => (b.active === "yes") - (a.active === "yes") || a.name.localeCompare(b.name))
                    Row2 {
                      required property var modelData
                      icon: win.typeIcon(modelData.type)
                      title: modelData.name
                      subtitle: win.typeName(modelData.type) + (modelData.active === "yes" ? " · activa en " + modelData.device : modelData.autoconnect === "yes" ? " · auto" : "")
                      live: modelData.active === "yes"
                      selected: win.selConn === modelData.uuid
                      onClicked: win.selectConn(modelData.uuid)
                    }
                  }
                }
              }
              RowLayout {
                Lbl { text: "Mostrar virtuales"; color: Theme.dim; font.pixelSize: Theme.fontSize; Layout.fillWidth: true }
                Sw { checked: win.showVirtual; onToggled: v => win.showVirtual = v }
              }
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }

            ColumnLayout {
              Layout.fillWidth: true; Layout.fillHeight: true
              spacing: 8
              Dim { visible: !win.conn; text: "Elegí una conexión para ver y editar su configuración"; Layout.fillWidth: true }

              // cabecera + acciones
              RowLayout {
                visible: !!win.conn
                Layout.fillWidth: true
                Text {
                  text: win.conn ? win.typeIcon(win.conn.type) + "  " + win.conn.name : ""
                  color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase + 3; font.bold: true
                  elide: Text.ElideRight; Layout.fillWidth: true
                }
                Btn {
                  text: win.conn && win.conn.active === "yes" ? "Desactivar" : "Activar"
                  primary: win.conn && win.conn.active !== "yes"
                  onClicked: {
                    const u = win.selConn, on = win.conn.active === "yes"
                    win.run(["connection", on ? "down" : "up", "uuid", u], on ? "Conexión desactivada" : "Conexión activada")
                  }
                }
              }
              Dim {
                visible: !!win.conn; Layout.fillWidth: true
                text: win.conn ? `${win.typeName(win.conn.type)} · ${win.conn.uuid}\n${win.conn.filename}` : ""
              }
              Flow {
                visible: !!win.conn
                Layout.fillWidth: true; spacing: 6
                Btn { text: "Duplicar"; onClicked: win.run(["connection", "clone", "uuid", win.selConn, win.conn.name + " (copia)"], "Conexión duplicada") }
                Btn {
                  visible: win.conn && (win.conn.type === "vpn" || win.conn.type === "wireguard")
                  text: "Exportar a ~/" ; onClicked: {
                    const f = Quickshell.env("HOME") + "/" + win.conn.name.replace(/[^\w.-]/g, "_") + (win.conn.type === "wireguard" ? ".conf" : ".ovpn")
                    win.run(["connection", "export", "uuid", win.selConn, f], "Exportada a " + f)
                  }
                }
                Btn {
                  text: "Eliminar"; danger: true
                  onClicked: win.deleteConn()
                }
              }

              // vistas
              Chips {
                visible: !!win.conn
                options: ["basic", "all", "secrets"]
                labels: ({ basic: "Básico", all: "Todas las propiedades", secrets: "Contraseñas" })
                value: win.connView
                onPicked: v => { win.connView = v; if (v === "secrets" && !win.secrets.length) win.loadSecrets() }
              }
              Field {
                visible: !!win.conn && win.connView === "all"
                placeholderText: "Filtrar propiedades (ej: ipv4, dns, mtu)…"
                text: win.propFilter
                onTextEdited: win.propFilter = text.toLowerCase()
              }

              Flickable {
                visible: !!win.conn
                Layout.fillWidth: true; Layout.fillHeight: true
                contentHeight: propCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                ColumnLayout {
                  id: propCol; width: parent.width - 12; spacing: 5

                  // Básico: propiedades comunes con nombres amigables
                  Repeater {
                    model: win.connView !== "basic" ? [] : [
                      { k: "connection.id", l: "Nombre" },
                      { k: "connection.autoconnect", l: "Conectar automáticamente", o: ["yes", "no"] },
                      { k: "connection.autoconnect-priority", l: "Prioridad" },
                      { k: "connection.metered", l: "Uso medido", o: ["unknown", "yes", "no"] },
                      { k: "connection.interface-name", l: "Interfaz" },
                      { k: "connection.secondaries", l: "Conexión secundaria (VPN)" },
                      { k: "802-11-wireless.ssid", l: "SSID" },
                      { k: "802-11-wireless.hidden", l: "Red oculta", o: ["yes", "no"] },
                      { k: "802-11-wireless.cloned-mac-address", l: "MAC clonada" },
                      { k: "802-11-wireless.mtu", l: "MTU" },
                      { k: "802-3-ethernet.cloned-mac-address", l: "MAC clonada" },
                      { k: "802-3-ethernet.mtu", l: "MTU" },
                      { k: "vpn.persistent", l: "VPN persistente", o: ["yes", "no"] },
                      { k: "ipv4.method", l: "IPv4 · método", o: ["auto", "manual", "link-local", "shared", "disabled"] },
                      { k: "ipv4.addresses", l: "IPv4 · direcciones" },
                      { k: "ipv4.gateway", l: "IPv4 · puerta de enlace" },
                      { k: "ipv4.dns", l: "IPv4 · DNS" },
                      { k: "ipv4.ignore-auto-dns", l: "IPv4 · ignorar DNS automático", o: ["yes", "no"] },
                      { k: "ipv4.never-default", l: "IPv4 · nunca ruta por defecto", o: ["yes", "no"] },
                      { k: "ipv4.routes", l: "IPv4 · rutas" },
                      { k: "ipv6.method", l: "IPv6 · método", o: ["auto", "dhcp", "manual", "link-local", "shared", "ignore", "disabled"] },
                      { k: "ipv6.addresses", l: "IPv6 · direcciones" },
                      { k: "ipv6.gateway", l: "IPv6 · puerta de enlace" },
                      { k: "ipv6.dns", l: "IPv6 · DNS" },
                      { k: "ipv6.ignore-auto-dns", l: "IPv6 · ignorar DNS automático", o: ["yes", "no"] }
                    ].filter(x => win.propVal(x.k) !== undefined)
                    PropRow {
                      required property var modelData
                      k: modelData.k; label: modelData.l; options: modelData.o ?? []
                      orig: win.propVal(modelData.k) ?? ""
                      value: win.editCount >= 0 ? win.cur(modelData.k) : ""
                      onEdited: v => win.setEdit(modelData.k, v)
                    }
                  }

                  // Todas: editor crudo de cualquier propiedad
                  Repeater {
                    model: win.connView !== "all" ? [] : win.props.filter(p => !win.propFilter || p.key.includes(win.propFilter))
                    PropRow {
                      required property var modelData
                      k: modelData.key; orig: modelData.value; readonly: modelData.readonly
                      options: /^(yes|no)$/.test(modelData.value) ? ["yes", "no"] : []
                      value: win.editCount >= 0 ? win.cur(modelData.key) : ""
                      onEdited: v => win.setEdit(modelData.key, v)
                    }
                  }

                  // Contraseñas
                  Dim { visible: win.connView === "secrets"; Layout.fillWidth: true; text: "Las contraseñas se leen de NetworkManager. Podés cambiarlas y guardar." }
                  Repeater {
                    model: win.connView !== "secrets" ? [] : win.secrets
                    PropRow {
                      required property var modelData
                      k: modelData.key; orig: modelData.value; secret: true
                      value: win.editCount >= 0 ? win.cur(modelData.key) : ""
                      onEdited: v => win.setEdit(modelData.key, v)
                    }
                  }
                  Btn { visible: win.connView === "secrets"; text: "Volver a leer"; onClicked: win.loadSecrets() }
                }
              }

              // guardar
              RowLayout {
                visible: win.editCount > 0
                Layout.fillWidth: true
                Lbl { text: win.editCount + (win.editCount === 1 ? " cambio sin guardar" : " cambios sin guardar"); color: Theme.yellow; Layout.fillWidth: true }
                Btn { text: "Descartar"; onClicked: { win.edits = ({}); win.editCount = 0 } }
                Btn { text: "Guardar"; primary: true; onClicked: win.save() }
                Btn {
                  visible: win.conn && win.conn.active === "yes"
                  text: "Guardar y reaplicar"
                  onClicked: { const u = win.selConn; win.save(); reapplyLater.uuid = u; reapplyLater.start() }
                }
              }
            }
          }

          // ════════ WI-FI ════════
          ColumnLayout {
            spacing: 8
            RowLayout {
              Layout.fillWidth: true
              Lbl { text: "Wi-Fi"; font.bold: true }
              Sw { checked: win.st.general.wifi === "enabled"; onToggled: v => win.run(["radio", "wifi", v ? "on" : "off"]) }
              Item { Layout.fillWidth: true }
              Btn { text: win.scanning ? "Buscando…" : "Buscar redes"; enabled: !win.scanning; onClicked: win.scanWifi(true) }
            }
            Flickable {
              id: wifiFlick
              Layout.fillWidth: true; Layout.fillHeight: true
              contentHeight: wifiCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
              ScrollBar.vertical: ScrollBar {}
              ColumnLayout {
                id: wifiCol; width: parent.width - 12; spacing: 2
                Dim { visible: win.wifiNets.length === 0; text: "Sin redes (¿Wi-Fi apagado?)" }
                Repeater {
                  model: win.wifiNets
                  Rectangle {
                    id: wr
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool open: win.wifiPick === n.bssid
                    readonly property bool known: win.st.connections.some(c => c.type === "802-11-wireless" && c.name === n.ssid)
                    Layout.fillWidth: true
                    implicitHeight: wcol.implicitHeight + 12; radius: 6
                    color: n.in_use ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : wa.containsMouse ? Theme.surface : "transparent"
                    MouseArea {
                      id: wa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: -1
                      onClicked: win.wifiPick = wr.open ? "" : wr.n.bssid
                    }
                    ColumnLayout {
                      id: wcol
                      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6; leftMargin: 8; rightMargin: 8 }
                      spacing: 6
                      RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text { text: win.ic([0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928][Math.min(4, Math.ceil(wr.n.signal / 25))]); color: wr.n.in_use ? Theme.accent : Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontBase + 3 }
                        ColumnLayout {
                          Layout.fillWidth: true; spacing: 0
                          Lbl { text: wr.n.ssid || "(red oculta)"; color: wr.n.in_use ? Theme.accent : wr.n.ssid ? Theme.foreground : Theme.dim; font.bold: wr.n.in_use; Layout.fillWidth: true }
                          Dim { text: `${wr.n.signal}% · ${wr.n.security || "abierta"} · canal ${wr.n.chan} (${wr.n.freq}) · ${wr.n.rate} · ${wr.n.bssid}` + (wr.known ? " · guardada" : ""); wrapMode: Text.NoWrap; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                      }
                      RowLayout {
                        visible: wr.open
                        Layout.fillWidth: true
                        Field {
                          id: wpw
                          visible: !wr.n.in_use && !wr.known && wr.n.security !== ""
                          echoMode: TextInput.Password; placeholderText: "Contraseña"
                          onAccepted: wcon.clicked()
                        }
                        Item { Layout.fillWidth: true; visible: !wpw.visible }
                        Btn {
                          id: wcon
                          text: wr.n.in_use ? "Desconectar" : "Conectar"; primary: !wr.n.in_use
                          onClicked: {
                            const n = wr.n
                            if (n.in_use) win.run(["device", "disconnect", n.device], "Wi-Fi desconectado")
                            else {
                              const a = ["device", "wifi", "connect", n.bssid]
                              if (wpw.visible && wpw.text) a.push("password", wpw.text)
                              win.run(a, "Conectado a " + (n.ssid || n.bssid))
                            }
                            win.wifiPick = ""
                          }
                        }
                        Btn {
                          visible: wr.known
                          text: "Olvidar"; danger: true
                          onClicked: { const s = wr.n.ssid; win.ask(`¿Olvidar la red "${s}"?`, () => win.run(["connection", "delete", "id", s], `"${s}" olvidada`)) }
                        }
                      }
                    }
                  }
                }
              }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
            Head { text: "Red oculta" }
            RowLayout {
              Layout.fillWidth: true
              Field { id: hidSsid; placeholderText: "SSID" }
              Field { id: hidPw; placeholderText: "Contraseña (vacío si es abierta)"; echoMode: TextInput.Password }
              Btn {
                text: "Conectar"; enabled: hidSsid.text !== ""
                onClicked: {
                  const a = ["device", "wifi", "connect", hidSsid.text, "hidden", "yes"]
                  if (hidPw.text) a.push("password", hidPw.text)
                  win.run(a, "Conectado a " + hidSsid.text, () => { hidSsid.text = ""; hidPw.text = "" })
                }
              }
            }
            Head { text: "Punto de acceso (compartir internet)" }
            RowLayout {
              Layout.fillWidth: true
              readonly property var hs: win.st.connections.find(c => c.active === "yes" && c.name.startsWith("Hotspot")) ?? null
              Field { id: hsSsid; visible: !parent.hs; placeholderText: "Nombre de la red"; text: (win.st.general.hostname ?? "extreme") + "-hotspot" }
              Field { id: hsPw; visible: !parent.hs; placeholderText: "Contraseña (mín. 8)"; echoMode: TextInput.Password }
              Lbl { visible: !!parent.hs; text: parent.hs ? "Activo: " + parent.hs.name : ""; color: Theme.green; Layout.fillWidth: true }
              Btn {
                text: parent.hs ? "Detener" : "Iniciar"
                enabled: !!parent.hs || hsPw.text.length >= 8
                onClicked: {
                  const hs = parent.hs
                  if (hs) win.run(["connection", "down", "uuid", hs.uuid], "Punto de acceso detenido")
                  else win.ask("Iniciar el punto de acceso desconecta tu Wi-Fi actual (la placa no puede hacer las dos cosas). ¿Seguir?",
                               () => win.run(["device", "wifi", "hotspot", "ssid", hsSsid.text, "password", hsPw.text], "Punto de acceso iniciado"))
                }
              }
            }
          }

          // ════════ NUEVA / IMPORTAR ════════
          Flickable {
            contentHeight: newCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout {
              id: newCol
              width: parent.width - 12; spacing: 8
              property string kind: "import"

              Chips {
                options: ["import", "ethernet", "wifi"]
                labels: ({ import: "Importar VPN", ethernet: "Ethernet", wifi: "Wi-Fi" })
                value: newCol.kind
                onPicked: v => newCol.kind = v
              }

              // ── Importar VPN ──
              ColumnLayout {
                visible: newCol.kind === "import"
                Layout.fillWidth: true; spacing: 8
                Dim { Layout.fillWidth: true; text: "Importa un archivo .ovpn (OpenVPN) o .conf (WireGuard)." }
                RowLayout {
                  Layout.fillWidth: true
                  Field { id: impPath; placeholderText: "/ruta/al/archivo.ovpn" }
                  Btn {
                    text: "Importar"; primary: true; enabled: impPath.text !== ""
                    onClicked: {
                      const f = impPath.text.replace(/^~/, Quickshell.env("HOME"))
                      const t = /\.conf$/.test(f) ? "wireguard" : "openvpn"
                      win.run(["connection", "import", "type", t, "file", f], "VPN importada", () => impPath.text = "")
                    }
                  }
                }
                Head { text: "Archivos encontrados en tu carpeta personal"; visible: win.vpnFiles.length > 0 }
                Repeater {
                  model: win.vpnFiles
                  Row2 {
                    required property string modelData
                    icon: win.ic(0xf0582)
                    title: modelData.split("/").pop()
                    subtitle: modelData.replace(Quickshell.env("HOME"), "~")
                    selected: impPath.text === modelData
                    onClicked: impPath.text = modelData
                  }
                }
                Btn { text: "Buscar de nuevo"; onClicked: win.findVpnFiles() }
              }

              // ── Ethernet ──
              GridLayout {
                visible: newCol.kind === "ethernet"
                Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 6
                Lbl { text: "Nombre" }
                Field { id: eName; text: "Cableada" }
                Lbl { text: "Interfaz" }
                Field { id: eIf; placeholderText: "(cualquiera)" }
                Lbl { text: "IPv4" }
                Chips { id: eMethod; options: ["auto", "manual"]; labels: ({ auto: "Automática (DHCP)", manual: "Manual" }); value: "auto"; onPicked: v => value = v }
                Lbl { text: "Dirección"; visible: eMethod.value === "manual" }
                Field { id: eAddr; visible: eMethod.value === "manual"; placeholderText: "192.168.1.50/24" }
                Lbl { text: "Puerta de enlace"; visible: eMethod.value === "manual" }
                Field { id: eGw; visible: eMethod.value === "manual"; placeholderText: "192.168.1.1" }
                Lbl { text: "DNS" }
                Field { id: eDns; placeholderText: "1.1.1.1 9.9.9.9 (opcional)" }
                Item {}
                Btn {
                  text: "Crear"; primary: true; enabled: eName.text !== "" && (eMethod.value === "auto" || eAddr.text !== "")
                  onClicked: {
                    const a = ["connection", "add", "type", "ethernet", "con-name", eName.text]
                    if (eIf.text) a.push("ifname", eIf.text)
                    a.push("ipv4.method", eMethod.value)
                    if (eMethod.value === "manual") { a.push("ipv4.addresses", eAddr.text); if (eGw.text) a.push("ipv4.gateway", eGw.text) }
                    if (eDns.text) a.push("ipv4.dns", eDns.text)
                    win.run(a, "Conexión creada")
                  }
                }
              }

              // ── Wi-Fi ──
              GridLayout {
                visible: newCol.kind === "wifi"
                Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 6
                Lbl { text: "SSID" }
                Field { id: wSsid }
                Lbl { text: "Contraseña" }
                Field { id: wPw; echoMode: TextInput.Password; placeholderText: "(vacío si es abierta)" }
                Lbl { text: "Nombre" }
                Field { id: wName; placeholderText: "(igual que el SSID)" }
                Lbl { text: "Red oculta" }
                Chips { id: wHidden; options: ["no", "yes"]; labels: ({ no: "No", yes: "Sí" }); value: "no"; onPicked: v => value = v }
                Item {}
                Btn {
                  text: "Guardar (sin conectar)"; primary: true; enabled: wSsid.text !== "" && (wPw.text === "" || wPw.text.length >= 8)
                  onClicked: {
                    const a = ["connection", "add", "type", "wifi", "con-name", wName.text || wSsid.text, "ssid", wSsid.text, "802-11-wireless.hidden", wHidden.value]
                    if (wPw.text) a.push("wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", wPw.text)
                    win.run(a, "Red guardada")
                  }
                }
              }
            }
          }
        }

        // barra de mensajes
        Rectangle {
          visible: win.msg !== ""
          Layout.fillWidth: true
          implicitHeight: msgText.implicitHeight + 12; radius: 6
          color: Qt.rgba(win.msgErr ? Theme.active.r : Theme.green.r, win.msgErr ? Theme.active.g : Theme.green.g, win.msgErr ? Theme.active.b : Theme.green.b, 0.15)
          Text {
            id: msgText
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
            text: win.msg; wrapMode: Text.Wrap
            color: win.msgErr ? Theme.active : Theme.green
            font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
          }
        }
      }
    }

    // confirmación
    Rectangle {
      visible: win.confirmText !== ""
      anchors.fill: parent; radius: Theme.radius
      color: Qt.alpha(Theme.shadow, 0.55)
      MouseArea { anchors.fill: parent }
      Rectangle {
        anchors.centerIn: parent
        width: 420; height: cc.implicitHeight + 32; radius: 10
        color: Theme.background; border.color: Theme.active
        ColumnLayout {
          id: cc
          anchors { fill: parent; margins: 16 }
          spacing: 14
          Text { text: win.confirmText; wrapMode: Text.Wrap; Layout.fillWidth: true; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase }
          RowLayout {
            Item { Layout.fillWidth: true }
            Btn { text: "Cancelar"; onClicked: win.confirmText = "" }
            Btn { text: "Sí, seguir"; danger: true; onClicked: { const a = win.confirmAction; win.confirmText = ""; if (a) a() } }
          }
        }
      }
    }
  }

  Timer {
    id: reapplyLater
    property string uuid
    interval: 1500
    onTriggered: { const c = win.st.connections.find(x => x.uuid === uuid); if (c && c.device) win.run(["device", "reapply", c.device], "Cambios reaplicados") }
  }
}
