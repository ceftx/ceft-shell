import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs
import qs.desktop

// Overview de workspaces: grilla con miniaturas en vivo de cada ventana (ScreencopyView solo mientras está abierto).
//   qs ipc call overview toggle | open | close | query <texto> | go <ws> | accept | movewin <addr> <ws> | dump
// Grilla configurable en ui.json: "overview": { "rows": 2, "cols": 5 }  (por defecto 2x5 = workspaces 1-10)
Scope {
  id: root

  property bool open: false
  property real shown: open ? 1 : 0
  Behavior on shown { NumberAnimation { duration: root.open ? 240 : 150; easing.type: Easing.OutCubic } }
  readonly property bool mapped: open || shown > 0.001
  readonly property var targetScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

  readonly property var cfg: Theme.u.overview ?? ({})
  readonly property int cols: Math.max(1, Math.min(6, Math.round(cfg.cols ?? 5)))
  readonly property int baseRows: Math.max(1, Math.min(4, Math.round(cfg.rows ?? 2)))

  // todas las ventanas normales (workspace > 0)
  readonly property var windows: Hyprland.toplevels.values.filter(t => (t.lastIpcObject?.workspace?.id ?? -1) > 0 && t.lastIpcObject?.mapped !== false)
  readonly property int maxWs: windows.reduce((a, t) => Math.max(a, t.lastIpcObject.workspace.id), 0)
  readonly property int count: Math.min(30, Math.max(baseRows * cols, Math.ceil(maxWs / cols) * cols))
  readonly property int rows: Math.ceil(count / cols)
  readonly property int activeWs: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1

  property int selected: 1       // workspace con el cursor de teclado
  property string query: ""
  property string confirmAddr: ""   // ventana marcada para cerrar (clic medio)
  property int dropWs: -1           // workspace bajo la ventana arrastrada
  property bool dragging: false

  function norm(s) { return (s ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "") }
  function matches(t) {
    const q = norm(root.query.trim())
    if (q === "") return true
    const o = t.lastIpcObject
    return norm(o.title).includes(q) || norm(o.class).includes(q) || norm(o.initialClass).includes(q)
  }
  readonly property var matched: root.windows.filter(t => matches(t)).sort((a, b) => a.lastIpcObject.workspace.id - b.lastIpcObject.workspace.id)

  function show(): void {
    field.text = ""
    root.query = ""
    root.confirmAddr = ""
    root.selected = root.activeWs
    Hyprland.refreshToplevels()
    Hyprland.refreshWorkspaces()
    live = true
    liveOff.interval = 700
    liveOff.restart()
    open = true
    focusTimer.restart()
  }
  function goWs(n: int): void {
    Hyprland.dispatch(`hl.dsp.focus({ workspace = ${n} })`)
    root.open = false
  }
  function focusWin(t): void {
    const o = t.lastIpcObject
    Hyprland.dispatch(`hl.dsp.focus({ workspace = ${o.workspace.id} })`)
    Hyprland.dispatch(`hl.dsp.focus({ window = "address:${o.address}" })`)
    root.open = false
  }
  function moveWin(addr: string, ws: int): void {
    Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws}, follow = false, window = "address:${addr}" })`)
    refresh.restart()
  }
  function closeWin(addr: string): void {
    Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${addr}" })`)
    root.confirmAddr = ""
    refresh.restart()
  }
  function step(dx: int, dy: int): void {
    let i = root.selected - 1
    let c = i % root.cols, r = Math.floor(i / root.cols)
    c = (c + dx + root.cols) % root.cols
    r = Math.max(0, Math.min(root.rows - 1, r + dy))
    root.selected = Math.min(root.count, r * root.cols + c + 1)
  }
  function accept(): void {
    if (root.query.trim() !== "") { if (root.matched.length > 0) root.focusWin(root.matched[0]) }
    else root.goWs(root.selected)
  }

  IpcHandler {
    target: "overview"
    function open(): void { root.show() }
    function close(): void { root.open = false }
    function toggle(): void { if (root.open) root.open = false; else root.show() }
    function query(text: string): void { if (!root.open) root.show(); field.text = text }
    function go(n: int): void { root.selected = Math.max(1, Math.min(root.count, n)) }
    function accept(): void { root.accept() }
    function movewin(addr: string, ws: int): void { root.moveWin(addr, ws) }
    function closewin(addr: string): void { root.closeWin(addr) }
    function dump(): string {
      return `open=${root.open} ws=${root.count} rows=${root.rows} cols=${root.cols} sel=${root.selected} q=[${root.query}]\n`
        + root.windows.map(t => `${t.lastIpcObject.address} ws${t.lastIpcObject.workspace.id} ${t.lastIpcObject.class} | ${t.lastIpcObject.title} ${root.matches(t) ? "*" : ""} wl=${t.wayland !== null}`).join("\n")
    }
  }

  Timer { id: focusTimer; interval: 30; onTriggered: field.forceActiveFocus() }
  Timer { id: refresh; interval: 90; onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces() } }
  // miniaturas a baja frecuencia; solo corre abierto
  // captura en ráfagas: vivo ~0.7 s al abrir y luego 0.35 s cada 2 s; cerrado no existe ningún ScreencopyView
  property bool live: false
  Timer { id: liveOff; interval: 650; onTriggered: root.live = false }
  Timer { interval: 2000; repeat: true; running: root.open; onTriggered: { root.live = true; liveOff.interval = 350; liveOff.restart() } }
  Connections {
    target: Hyprland
    enabled: root.open
    function onRawEvent(ev) {
      const n = ev.name
      if (n.startsWith("openwindow") || n.startsWith("closewindow") || n.startsWith("movewindow") || n.startsWith("workspace") || n === "windowtitlev2" || n === "changefloatingmode") refresh.restart()
    }
  }

  FileView {
    id: wallFile
    path: Quickshell.env("HOME") + "/.local/state/ceft-shell/wallpaper"
    watchChanges: true
    onFileChanged: reload()
  }
  readonly property string wallpaper: { const t = wallFile.text(); return t ? t.trim() : "" }

  // ── velo ──
  PanelWindow {
    screen: root.targetScreen
    visible: root.mapped
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Qt.rgba(0, 0, 0, 0.62 * root.shown)
    WlrLayershell.namespace: "quickshell-overview-scrim"
    WlrLayershell.layer: WlrLayer.Top
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.open = false }
  }

  // ── overview ──
  PanelWindow {
    id: win
    screen: root.targetScreen
    visible: root.mapped
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
      anchors.fill: parent
      onPressed: root.open = false
      onWheel: wheel => root.step(wheel.angleDelta.y > 0 ? -1 : 1, 0)
    }

    FocusScope {
      id: lay
      anchors.fill: parent
      focus: true

      readonly property real scr: root.targetScreen?.width ?? 1920
      readonly property real scrH: root.targetScreen?.height ?? 1080
      readonly property real aspect: scr / scrH
      readonly property int gap: 16
      readonly property real cellW: Math.floor(Math.min((scr * 0.92 - (root.cols - 1) * gap) / root.cols,
                                       ((scrH - 220 - (root.rows - 1) * gap) / root.rows) * aspect))
      readonly property real cellH: Math.floor(cellW / aspect)
      readonly property real gridW: root.cols * cellW + (root.cols - 1) * gap
      readonly property real gridH: root.rows * cellH + (root.rows - 1) * gap
      readonly property real padX: 8
      readonly property real padTop: 36
      readonly property real padBot: 8
      readonly property real k: Math.min((cellW - 2 * padX) / scr, (cellH - padTop - padBot) / scrH)
      readonly property real offX: (cellW - scr * k) / 2
      readonly property real offY: padTop + ((cellH - padTop - padBot) - scrH * k) / 2

      // ── búsqueda ──
      Rectangle {
        id: pill
        width: 560; height: 56; radius: 28
        x: (parent.width - width) / 2
        y: (parent.height - (lay.gridH + 56 + 36)) / 2 - 8 - (1 - root.shown) * 24
        opacity: root.shown
        color: Qt.alpha(Theme.background, 0.86)
        border.width: 1
        border.color: field.activeFocus ? Qt.alpha(Theme.accent, 0.7) : Theme.glassEdge
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        Icon {
          id: sIcon
          name: "search"
          anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
          font.pixelSize: 24
          color: root.query !== "" ? Theme.accent : DeskTheme.textMuted
        }
        TextInput {
          id: field
          anchors { left: sIcon.right; leftMargin: 12; right: hint.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
          color: Theme.foreground
          selectionColor: Qt.alpha(Theme.accent, 0.45)
          selectedTextColor: Theme.foreground
          font.family: Theme.fontSans
          font.pixelSize: 20
          clip: true
          focus: true
          selectByMouse: true
          onTextChanged: root.query = text
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Escape) { root.open = false; event.accepted = true }
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) { root.accept(); event.accepted = true }
            else if (k === Qt.Key_Down) { root.step(0, 1); event.accepted = true }
            else if (k === Qt.Key_Up) { root.step(0, -1); event.accepted = true }
            else if (k === Qt.Key_Tab) { root.step(1, 0); event.accepted = true }
            else if (k === Qt.Key_Backtab) { root.step(-1, 0); event.accepted = true }
            else if (k === Qt.Key_Right && field.text === "") { root.step(1, 0); event.accepted = true }
            else if (k === Qt.Key_Left && field.text === "") { root.step(-1, 0); event.accepted = true }
            else if (k >= Qt.Key_1 && k <= Qt.Key_9 && (event.modifiers & Qt.AltModifier)) { root.goWs(k - Qt.Key_0); event.accepted = true }
          }
          Text {
            visible: field.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: "Filtrar ventanas por título o clase"
            color: DeskTheme.textFaint
            font: field.font
          }
        }
        Text {
          id: hint
          anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
          text: root.query === "" ? "" : (root.matched.length === 0 ? "sin resultados" : root.matched.length + (root.matched.length === 1 ? " ventana" : " ventanas"))
          color: root.matched.length === 0 && root.query !== "" ? Theme.active : Theme.accent
          font.family: Theme.fontSans
          font.pixelSize: 13
          font.weight: Font.DemiBold
        }
      }

      // ── grilla ──
      Item {
        id: grid
        width: lay.gridW; height: lay.gridH
        x: (parent.width - width) / 2
        y: pill.y + pill.height + 36 + (1 - root.shown) * 30
        opacity: root.shown
        scale: 0.94 + 0.06 * root.shown
        transformOrigin: Item.Center

        Repeater {
          model: root.count
          OvWorkspace {
            required property int index
            wsId: index + 1
            width: lay.cellW; height: lay.cellH
            x: (index % root.cols) * (lay.cellW + lay.gap)
            y: Math.floor(index / root.cols) * (lay.cellH + lay.gap)
            wallpaper: root.wallpaper
            active: root.activeWs === wsId
            selected: root.selected === wsId
            dropTarget: root.dragging && root.dropWs === wsId
            winCount: root.windows.filter(t => t.lastIpcObject.workspace.id === wsId).length
            onChosen: root.goWs(wsId)
            onHovered: root.selected = wsId
            onDropEntered: root.dropWs = wsId
            onDropExited: if (root.dropWs === wsId) root.dropWs = -1
          }
        }

        Item {
          id: winLayer
          anchors.fill: parent
          Repeater {
            model: root.windows
            OvWindow {
              required property var modelData
              tl: modelData
              ov: root
              cols: root.cols
              cellW: lay.cellW; cellH: lay.cellH; gap: lay.gap; k: lay.k; offX: lay.offX; offY: lay.offY; scrW: lay.scr; scrH: lay.scrH
              originX: root.targetScreen?.x ?? 0
              originY: root.targetScreen?.y ?? 0
              dimmed: !root.matches(modelData)
              isFirst: root.query.trim() !== "" && root.matched[0] === modelData
              confirming: root.confirmAddr === (modelData.lastIpcObject.address ?? "")
              onFocusRequested: root.focusWin(modelData)
              onMoveRequested: ws => root.moveWin(modelData.lastIpcObject.address, ws)
              onCloseRequested: {
                const a = modelData.lastIpcObject.address
                if (root.confirmAddr === a) root.closeWin(a); else { root.confirmAddr = a; confirmTimer.restart() }
              }
            }
          }
        }
      }

      // ── pie ──
      Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; top: grid.bottom; topMargin: 20 }
        width: foot.implicitWidth + 36; height: 32; radius: 16
        color: Qt.alpha(Theme.background, 0.78)
        opacity: root.shown
      Text {
        id: foot
        anchors.centerIn: parent
        text: "clic: ir   ·   arrastrar: mover ventana   ·   clic medio: cerrar   ·   flechas / rueda: navegar   ·   esc: salir"
        color: DeskTheme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: 13
      }
      }
    }
  }
  Timer { id: confirmTimer; interval: 2600; onTriggered: root.confirmAddr = "" }
}
