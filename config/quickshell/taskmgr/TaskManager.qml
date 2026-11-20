import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs

// Administrador de tareas (estilo Windows): procesos agrupados, finalizar tarea y rendimiento en vivo.
//   qs ipc call taskmgr open | close | toggle
// Datos: scripts/taskmgr.py (psutil), solo corre mientras la ventana está abierta.
Scope {
  id: root
  property bool open: false
  IpcHandler {
    target: "taskmgr"
    function open(): void { root.open = true }
    function close(): void { root.open = false }
    function toggle(): void { root.open = !root.open }
    function tab(t: string): void { root.tab = t === "perf" ? "perf" : "procs"; root.open = true }
    function perf(sel: string): void { root.perfSel = sel; root.tab = "perf"; root.open = true }
  }

  // ───────── estado ─────────
  property string tab: "procs"           // procs | perf
  property string perfSel: "cpu"
  property string search: ""
  property string sortKey: "cpu"
  property bool sortDesc: true
  property bool grouped: true
  property var expanded: ({})
  property string selKey: ""
  property var data: null
  property var rows: []
  property var hist: ({ cpu: [], mem: [], diskR: [], diskW: [], rx: [], tx: [], gpu: [] })
  readonly property string py: Quickshell.env("HOME") + "/.config/quickshell/scripts/taskmgr.py"

  function fmtB(b) {
    b = b || 0
    const u = ["B", "KB", "MB", "GB", "TB"]
    let i = 0
    while (b >= 1024 && i < 4) { b /= 1024; i++ }
    return (i === 0 || b >= 100 ? Math.round(b) : b >= 10 ? b.toFixed(1) : b.toFixed(2)) + " " + u[i]
  }
  function fmtRate(b) { return fmtB(b) + "/s" }
  function fmtUp(s) {
    s = Math.floor(s)
    const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return (d > 0 ? d + "d " : "") + h + "h " + m + "m"
  }
  function push(arr, v) { const a = arr.concat([v]); return a.length > 60 ? a.slice(a.length - 60) : a }

  function ingest(d) {
    data = d
    const h = hist
    hist = {
      cpu: push(h.cpu, d.cpu.total), mem: push(h.mem, d.mem.used / d.mem.total * 100),
      diskR: push(h.diskR, d.disk.read), diskW: push(h.diskW, d.disk.write),
      rx: push(h.rx, d.net.rx), tx: push(h.tx, d.net.tx), gpu: push(h.gpu, d.gpu ? d.gpu.util : 0)
    }
    rebuild()
  }

  function cmp(a, b) {
    const k = sortKey
    let r
    if (k === "name" || k === "user" || k === "state") r = String(a[k]).localeCompare(String(b[k]))
    else r = (a[k] ?? 0) - (b[k] ?? 0)
    if (r !== 0) return sortDesc ? -r : r
    return String(a.name).localeCompare(String(b.name))
  }

  function rebuild(reset) {
    if (!data) return
    const keep = reset ? 0 : plist.contentY
    const q = search.trim().toLowerCase()
    let ps = data.procs
    if (q !== "") ps = ps.filter(p => p.name.toLowerCase().includes(q) || String(p.pid) === q || p.cmd.toLowerCase().includes(q))
    const out = []
    if (!grouped) {
      for (const p of ps.slice().sort(cmp)) out.push({ key: "p:" + p.pid, level: 0, name: p.name, pid: p.pid, user: p.user, cpu: p.cpu, mem: p.mem, state: p.state, threads: p.threads, pids: [p.pid], mine: p.mine, count: 1, cmd: p.cmd })
    } else {
      const g = {}
      for (const p of ps) {
        const e = g[p.name] ?? (g[p.name] = { key: "g:" + p.name, level: 0, name: p.name, pid: p.pid, user: p.user, cpu: 0, mem: 0, state: p.state, threads: 0, pids: [], mine: true, count: 0, kids: [], cmd: p.cmd })
        e.cpu += p.cpu; e.mem += p.mem; e.threads += p.threads; e.count++; e.pids.push(p.pid); e.kids.push(p)
        e.mine = e.mine && p.mine
        if (p.state === "running") e.state = "running"
      }
      for (const e of Object.values(g).sort(cmp)) {
        e.cpu = Math.round(e.cpu * 10) / 10
        if (e.count === 1) { e.key = "p:" + e.pid; out.push(e); continue }
        e.user = e.kids.every(k => k.user === e.kids[0].user) ? e.kids[0].user : "varios"
        out.push(e)
        if (expanded[e.name]) {
          for (const k of e.kids.slice().sort(cmp)) out.push({ key: "p:" + k.pid, level: 1, name: k.name, pid: k.pid, user: k.user, cpu: k.cpu, mem: k.mem, state: k.state, threads: k.threads, pids: [k.pid], mine: k.mine, count: 1, cmd: k.cmd })
        }
      }
    }
    rows = out
    Qt.callLater(() => { plist.contentY = Math.max(0, Math.min(keep, plist.contentHeight - plist.height)) })
  }
  onSearchChanged: rebuild(true)
  onSortKeyChanged: rebuild(true)
  onSortDescChanged: rebuild(true)
  onGroupedChanged: rebuild(true)
  function toggleGroup(name) { const e = Object.assign({}, expanded); if (e[name]) delete e[name]; else e[name] = true; expanded = e; rebuild() }
  function setSort(k) { if (sortKey === k) sortDesc = !sortDesc; else { sortKey = k; sortDesc = (k !== "name" && k !== "user" && k !== "state") } }

  readonly property var selRow: rows.find(r => r.key === selKey) ?? null
  function endTask(force) {
    const r = selRow
    if (!r) return
    const pids = (r.kids ? r.kids.filter(k => k.mine).map(k => k.pid) : (r.mine ? r.pids : [])).map(String)
    if (pids.length === 0) return
    Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM"].concat(pids))
  }

  Process {
    id: collector
    command: ["python3", root.py, "1.5"]
    running: root.open
    stdout: SplitParser {
      onRead: line => { try { root.ingest(JSON.parse(line)) } catch (e) { console.log("taskmgr ingest: " + e) } }
    }
    onRunningChanged: if (!running && root.open) restart.restart()
  }
  Timer { id: restart; interval: 1500; onTriggered: if (root.open) collector.running = true }

  // ───────── ventana ─────────
  FloatingWindow {
    id: win
    visible: root.open
    title: "Administrador de tareas"
    color: Theme.background
    implicitWidth: 1040
    implicitHeight: 700
    minimumSize: Qt.size(780, 480)
    onVisibleChanged: if (!visible) root.open = false

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.open = false
      Keys.onDeletePressed: if (root.tab === "procs") root.endTask(false)
      Keys.onPressed: e => {
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_F) { searchField.forceActiveFocus(); e.accepted = true }
      }

      ColumnLayout {
        anchors { fill: parent; margins: 14 }
        spacing: 10

        // barra superior
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Repeater {
            model: [{ id: "procs", t: "Procesos", i: "lists" }, { id: "perf", t: "Rendimiento", i: "monitor_heart" }]
            Rectangle {
              required property var modelData
              readonly property bool on: root.tab === modelData.id
              implicitWidth: lbl.implicitWidth + 40; implicitHeight: 34; radius: 17
              color: on ? Theme.accentContainer : (ma.containsMouse ? Theme.hover : "transparent")
              Row {
                anchors.centerIn: parent; spacing: 8
                Text { text: modelData.i; font.family: Theme.iconFont; font.pixelSize: 18; color: on ? Theme.accent : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                Text { id: lbl; text: modelData.t; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; color: on ? Theme.accent : Theme.foreground; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = modelData.id }
            }
          }
          Item { Layout.fillWidth: true }

          Rectangle {
            visible: root.tab === "procs"
            Layout.preferredWidth: 240; implicitHeight: 34; radius: 17
            color: Qt.alpha(Theme.foreground, 0.07)
            border.width: 1; border.color: searchField.activeFocus ? Theme.accent : Theme.hairline
            Row {
              anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 8
              Text { text: "search"; font.family: Theme.iconFont; font.pixelSize: 18; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
              TextInput {
                id: searchField
                width: parent.width - 30; anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground; selectionColor: Qt.alpha(Theme.accent, 0.45)
                font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1
                clip: true
                onTextChanged: root.search = text
                Keys.onEscapePressed: { text = ""; parent.parent.parent.parent.forceActiveFocus() }
                Text { visible: parent.text === ""; text: "Buscar proceso (Ctrl+F)"; color: Theme.dim; font: parent.font }
              }
            }
          }
          Btn { visible: root.tab === "procs"; text: root.grouped ? "Agrupado" : "Lista plana"; icon: root.grouped ? "account_tree" : "format_list_bulleted"; onClicked: root.grouped = !root.grouped }
          Btn { visible: root.tab === "procs"; text: "Finalizar tarea"; icon: "close"; danger: true; enabled: root.selRow !== null && (root.selRow.mine || (root.selRow.kids ?? []).some(k => k.mine)); onClicked: root.endTask(false) }
          Btn { visible: root.tab === "procs"; text: "Forzar"; icon: "bolt"; danger: true; enabled: root.selRow !== null && (root.selRow.mine || (root.selRow.kids ?? []).some(k => k.mine)); onClicked: root.endTask(true) }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.hairline }

        // ───────── PROCESOS ─────────
        ColumnLayout {
          visible: root.tab === "procs"
          Layout.fillWidth: true; Layout.fillHeight: true
          spacing: 0

          // cabecera de columnas (con totales como en Windows)
          RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: false; Layout.preferredHeight: 52
            spacing: 0
            ColHead { Layout.fillWidth: true; key: "name"; label: "Nombre"; align: Text.AlignLeft; leftPad: 40 }
            ColHead { Layout.preferredWidth: 70; key: "pid"; label: "PID" }
            ColHead { Layout.preferredWidth: 110; key: "user"; label: "Usuario"; align: Text.AlignLeft }
            ColHead { Layout.preferredWidth: 90; key: "state"; label: "Estado"; align: Text.AlignLeft }
            ColHead { Layout.preferredWidth: 70; key: "threads"; label: "Hilos" }
            ColHead { Layout.preferredWidth: 90; key: "cpu"; label: "CPU"; total: root.data ? Math.round(root.data.cpu.total) + "%" : "" }
            ColHead { Layout.preferredWidth: 110; key: "mem"; label: "Memoria"; total: root.data ? Math.round(root.data.mem.used / root.data.mem.total * 100) + "%" : "" }
          }
          Rectangle { Layout.fillWidth: true; height: 1; color: Theme.hairline }

          ListView {
            id: plist
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds
            delegate: PRow { }
            Text {
              anchors.centerIn: parent; visible: root.rows.length === 0
              text: root.data ? "Sin resultados" : "Cargando procesos…"
              color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 2
            }
          }
          Text {
            Layout.topMargin: 6
            text: root.data ? root.data.procs.length + " procesos · " + root.data.procs.reduce((a, p) => a + p.threads, 0) + " hilos · encendido hace " + root.fmtUp(root.data.uptime) + (root.selRow && !root.selRow.mine && !(root.selRow.kids ?? []).some(k => k.mine) ? "  ·  proceso del sistema (no se puede finalizar sin root)" : "") : ""
            color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
          }
        }

        // ───────── RENDIMIENTO ─────────
        RowLayout {
          visible: root.tab === "perf"
          Layout.fillWidth: true; Layout.fillHeight: true
          spacing: 14

          ColumnLayout {
            Layout.preferredWidth: 230; Layout.fillWidth: false; Layout.fillHeight: true
            spacing: 8
            Repeater {
              model: {
                const d = root.data
                if (!d) return []
                const l = [
                  { id: "cpu", t: "CPU", s: Math.round(d.cpu.total) + "%" + (d.cpu.freq ? "  " + (d.cpu.freq / 1000).toFixed(2) + " GHz" : ""), v: root.hist.cpu, c: Theme.accent },
                  { id: "mem", t: "Memoria", s: root.fmtB(d.mem.used) + " / " + root.fmtB(d.mem.total), v: root.hist.mem, c: Theme.green },
                  { id: "disk", t: "Disco", s: "L " + root.fmtRate(d.disk.read) + "  E " + root.fmtRate(d.disk.write), v: root.hist.diskR, v2: root.hist.diskW, c: Theme.yellow, max: 0 },
                  { id: "net", t: "Red", s: "↓ " + root.fmtRate(d.net.rx) + "  ↑ " + root.fmtRate(d.net.tx), v: root.hist.rx, v2: root.hist.tx, c: Theme.accent2, max: 0 }
                ]
                if (d.gpu) l.push({ id: "gpu", t: "GPU", s: Math.round(d.gpu.util) + "%  " + d.gpu.temp + " °C", v: root.hist.gpu, c: Theme.active })
                return l
              }
              Rectangle {
                required property var modelData
                readonly property bool on: root.perfSel === modelData.id
                Layout.fillWidth: true; implicitHeight: 76; radius: Theme.radiusSmall
                color: on ? Theme.accentContainer : (cma.containsMouse ? Theme.hover : Qt.alpha(Theme.foreground, 0.05))
                border.width: 1; border.color: on ? Qt.alpha(Theme.accent, 0.5) : Theme.hairline
                Row {
                  anchors { fill: parent; margins: 8 } spacing: 10
                  Spark { width: 70; height: parent.height; values: modelData.v; values2: modelData.v2 ?? []; max: modelData.max ?? 100; color: modelData.c; color2: Theme.green; grid: false }
                  Column {
                    anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; spacing: 3
                    Text { text: modelData.t; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 2; font.bold: true }
                    Text { text: modelData.s; width: parent.width; elide: Text.ElideRight; color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize - 1 }
                  }
                }
                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.perfSel = modelData.id }
              }
            }
            Item { Layout.fillHeight: true }
          }

          PerfPane { Layout.fillWidth: true; Layout.fillHeight: true }
        }
      }
    }
  }

  // ───────── componentes ─────────
  component Btn: Rectangle {
    id: b
    property string text: ""
    property string icon: ""
    property bool danger: false
    signal clicked()
    implicitWidth: row.implicitWidth + 28; implicitHeight: 34; radius: 17
    opacity: enabled ? 1 : 0.4
    color: danger ? Qt.alpha(Theme.active, bma.containsMouse ? 0.30 : 0.18) : (bma.containsMouse ? Theme.hover : Qt.alpha(Theme.foreground, 0.07))
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Row {
      id: row; anchors.centerIn: parent; spacing: 6
      Text { text: b.icon; visible: b.icon !== ""; font.family: Theme.iconFont; font.pixelSize: 17; color: b.danger ? Theme.active : Theme.foreground; anchors.verticalCenter: parent.verticalCenter }
      Text { text: b.text; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; color: b.danger ? Theme.active : Theme.foreground; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: bma; anchors.fill: parent; enabled: b.enabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
  }

  component ColHead: Item {
    id: h
    property string key: ""
    property string label: ""
    property string total: ""
    property int align: Text.AlignRight
    property int leftPad: 0
    Layout.fillHeight: true
    readonly property bool on: root.sortKey === key
    Rectangle { anchors.fill: parent; color: hma.containsMouse ? Theme.hover : "transparent" }
    Column {
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10 + h.leftPad; rightMargin: 10 }
      spacing: 1
      Text {
        width: parent.width; horizontalAlignment: h.align
        visible: h.total !== ""; text: h.total
        color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 6; font.weight: Font.Medium
      }
      Text {
        width: parent.width; horizontalAlignment: h.align
        text: h.label + (h.on ? (root.sortDesc ? "  ↓" : "  ↑") : "")
        color: h.on ? Theme.accent : Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize; font.weight: h.on ? Font.DemiBold : Font.Normal
      }
    }
    MouseArea { id: hma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setSort(h.key) }
  }

  component PRow: Item {
    id: r
    required property var modelData
    readonly property bool sel: root.selKey === modelData.key
    readonly property bool isGroup: modelData.count > 1 && modelData.level === 0 && root.grouped
    readonly property var entry: DesktopEntries.heuristicLookup(modelData.name)
    readonly property string iconPath: entry ? Quickshell.iconPath(entry.icon ?? "", true) : ""
    width: ListView.view.width; height: 34

    Rectangle {
      anchors.fill: parent
      color: r.sel ? Theme.accentContainer : (rma.containsMouse ? Theme.hover : "transparent")
    }
    function heat(v, scale) { return Qt.alpha(Theme.yellow, Math.min(0.42, v / scale * 0.42)) }

    RowLayout {
      anchors.fill: parent
      spacing: 0
      Item {
        Layout.fillWidth: true; Layout.fillHeight: true
        Text {
          visible: r.isGroup
          x: 8; anchors.verticalCenter: parent.verticalCenter
          text: root.expanded[r.modelData.name] ? "expand_more" : "chevron_right"
          font.family: Theme.iconFont; font.pixelSize: 20; color: Theme.muted
        }
        Image {
          x: 28 + r.modelData.level * 22; anchors.verticalCenter: parent.verticalCenter
          width: 20; height: 20; sourceSize: Qt.size(40, 40); source: r.iconPath
          visible: r.iconPath !== ""; asynchronous: true
        }
        Text {
          visible: r.iconPath === ""
          x: 28 + r.modelData.level * 22; anchors.verticalCenter: parent.verticalCenter
          text: "terminal"; font.family: Theme.iconFont; font.pixelSize: 20; color: Theme.dim
        }
        Text {
          x: 58 + r.modelData.level * 22; width: parent.width - x - 6; anchors.verticalCenter: parent.verticalCenter
          text: r.modelData.name + (r.isGroup ? "  (" + r.modelData.count + ")" : "")
          elide: Text.ElideRight; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1
          font.weight: r.isGroup ? Font.DemiBold : Font.Normal
        }
      }
      Cell { Layout.preferredWidth: 70; text: r.isGroup ? "" : r.modelData.pid; muted: true; mono: true }
      Cell { Layout.preferredWidth: 110; text: r.modelData.user; align: Text.AlignLeft; muted: true }
      Cell { Layout.preferredWidth: 90; text: ({ running: "Activo", sleeping: "En espera", "disk-sleep": "E/S", zombie: "Zombi", stopped: "Detenido", idle: "Inactivo" })[r.modelData.state] ?? r.modelData.state; align: Text.AlignLeft; muted: true }
      Cell { Layout.preferredWidth: 70; text: r.modelData.threads; muted: true; mono: true }
      Cell { Layout.preferredWidth: 90; text: r.modelData.cpu.toFixed(1) + "%"; bg: r.heat(r.modelData.cpu, 40); mono: true }
      Cell { Layout.preferredWidth: 110; text: root.fmtB(r.modelData.mem); bg: r.heat(root.data ? r.modelData.mem / root.data.mem.total * 100 : 0, 12); mono: true }
    }
    MouseArea {
      id: rma; anchors.fill: parent; hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: m => { root.selKey = r.modelData.key; if (m.button === Qt.LeftButton && r.isGroup && m.x < 36) root.toggleGroup(r.modelData.name) }
      onDoubleClicked: if (r.isGroup) root.toggleGroup(r.modelData.name)
    }
  }

  component Cell: Rectangle {
    property string text: ""
    property int align: Text.AlignRight
    property bool muted: false
    property bool mono: false
    property color bg: "transparent"
    Layout.fillHeight: true
    color: bg
    Text {
      anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
      text: parent.text; horizontalAlignment: parent.align; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
      color: parent.muted ? Theme.muted : Theme.foreground
      font.family: parent.mono ? Theme.font : Theme.fontSans; font.pixelSize: Theme.fontSize
    }
  }

  component PerfPane: Rectangle {
    id: pp
    radius: Theme.radius - 4
    color: Qt.alpha(Theme.foreground, 0.04)
    border.width: 1; border.color: Theme.hairline
    readonly property var d: root.data
    readonly property string sel: root.perfSel

    function stats() {
      if (!d) return []
      if (sel === "cpu") return [
        ["Uso", Math.round(d.cpu.total) + "%"], ["Velocidad", d.cpu.freq ? (d.cpu.freq / 1000).toFixed(2) + " GHz" : "—"],
        ["Procesos", d.procs.length], ["Hilos", d.procs.reduce((a, p) => a + p.threads, 0)],
        ["Carga 1/5/15", d.cpu.load.map(x => x.toFixed(2)).join("  ")], ["Temperatura", d.cpu.temp != null ? Math.round(d.cpu.temp) + " °C" : "—"],
        ["Núcleos lógicos", d.cpu.n], ["Tiempo activo", root.fmtUp(d.uptime)]]
      if (sel === "mem") return [
        ["En uso", root.fmtB(d.mem.used)], ["Total", root.fmtB(d.mem.total)],
        ["Disponible", root.fmtB(d.mem.total - d.mem.used)], ["En caché", root.fmtB(d.mem.cached)],
        ["Swap en uso", root.fmtB(d.mem.swapUsed)], ["Swap total", root.fmtB(d.mem.swapTotal)]]
      if (sel === "disk") return [
        ["Lectura", root.fmtRate(d.disk.read)], ["Escritura", root.fmtRate(d.disk.write)],
        ["Raíz (/) usado", root.fmtB(d.disk.root.used)], ["Raíz (/) total", root.fmtB(d.disk.root.total)]]
      if (sel === "net") return [["Descarga", root.fmtRate(d.net.rx)], ["Subida", root.fmtRate(d.net.tx)]]
      if (sel === "gpu" && d.gpu) return [
        ["Uso", Math.round(d.gpu.util) + "%"], ["Memoria", root.fmtB(d.gpu.memUsed) + " / " + root.fmtB(d.gpu.memTotal)],
        ["Temperatura", d.gpu.temp + " °C"], ["Consumo", d.gpu.power.toFixed(0) + " W"]]
      return []
    }
    readonly property var meta: ({
      cpu:  { t: "CPU",     sub: d ? d.cpu.name : "", c: Theme.accent,   v: root.hist.cpu,   max: 100 },
      mem:  { t: "Memoria", sub: d ? root.fmtB(d.mem.total) + " de RAM" : "", c: Theme.green, v: root.hist.mem, max: 100 },
      disk: { t: "Disco",   sub: "Lectura (amarillo) · Escritura (verde)", c: Theme.yellow, v: root.hist.diskR, v2: root.hist.diskW, max: 0 },
      net:  { t: "Red",     sub: "Descarga · Subida (verde)", c: Theme.accent2, v: root.hist.rx, v2: root.hist.tx, max: 0 },
      gpu:  { t: "GPU",     sub: d && d.gpu ? d.gpu.name : "", c: Theme.active, v: root.hist.gpu, max: 100 }
    })
    readonly property var m: meta[sel] ?? meta.cpu

    ColumnLayout {
      anchors { fill: parent; margins: 18 }
      spacing: 12
      RowLayout {
        Layout.fillWidth: true
        Text { text: pp.m.t; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 26; font.weight: Font.DemiBold }
        Item { Layout.fillWidth: true }
        Text { text: pp.m.sub; color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1; elide: Text.ElideRight; Layout.maximumWidth: 460 }
      }
      Spark {
        Layout.fillWidth: true; Layout.preferredHeight: 230
        values: pp.m.v; values2: pp.m.v2 ?? []; max: pp.m.max; color: pp.m.c; color2: Theme.green
      }
      Text { text: "60 segundos"; color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize - 1 }

      GridLayout {
        Layout.fillWidth: true
        columns: 4; columnSpacing: 22; rowSpacing: 12
        Repeater {
          model: pp.stats()
          Column {
            required property var modelData
            Layout.preferredWidth: 150
            spacing: 2
            Text { text: modelData[0]; color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize - 1 }
            Text { text: modelData[1]; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 6; font.weight: Font.Medium }
          }
        }
      }

      // CPU: un medidor por núcleo
      Flow {
        visible: pp.sel === "cpu" && pp.d !== null
        Layout.fillWidth: true; spacing: 8
        Repeater {
          model: pp.d ? pp.d.cpu.cores : []
          Rectangle {
            required property var modelData
            required property int index
            width: 86; height: 38; radius: 8
            color: Qt.alpha(Theme.foreground, 0.06)
            Rectangle { anchors { left: parent.left; bottom: parent.bottom; top: parent.top; margins: 0 } width: parent.width * Math.min(1, modelData / 100); radius: 8; color: Qt.alpha(Theme.accent, 0.35) }
            Column {
              anchors.centerIn: parent; spacing: 0
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData) + "%"; color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "núcleo " + index; color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize - 2 }
            }
          }
        }
      }
      Item { Layout.fillHeight: true }
    }
  }
}
