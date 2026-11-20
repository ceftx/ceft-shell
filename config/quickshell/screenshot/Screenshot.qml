import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs

// Capturas unificadas (Print). Congela cada monitor con grim, selección por zona / ventana / monitor,
// barra de opciones (copiar, guardar, satty, OCR, QR, grabar). Las acciones las hacen scripts/shot-do y screenrecord.
//   qs ipc call screenshot open <region|output> <edit|copy> | close | toggle
Scope {
  id: root

  // ── estado ──
  property bool open: false
  property string phase: "idle"          // idle | capturing | ready
  readonly property bool showing: open && phase === "ready"
  property string mode: "edit"           // edit: barra de opciones (Enter edita) · copy: copia al soltar
  readonly property string defAction: mode === "copy" ? "copy" : "edit"
  property string stage: "pick"          // pick | adjust
  property var files: ({})               // monitor -> .ppm congelado
  property string dir: ""
  property var windows: []               // ventanas visibles (coords globales)
  property string focusName: ""          // monitor con el foco de teclado
  property string cursorScreen: ""
  property string selScreen: ""
  property real selX: 0
  property real selY: 0
  property real selW: 0
  property real selH: 0
  readonly property bool hasSel: selW >= 1 && selH >= 1
  property string drag: ""               // "" | new | move | resize
  property var dragStart: ({})
  property string dragEdges: ""          // l r t b combinados

  // disponibilidad de programas
  property bool hasOcr: false
  property bool hasQr: false
  property bool hasSatty: true
  property string ocrMissing: "OCR no disponible: instalá tesseract, tesseract-data-spa y tesseract-data-eng"

  property string saveDir: ""            // pruebas: carpeta de guardado (vacío = SCREENSHOT_DIR / ~/Pictures/Screenshots)
  readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"
  readonly property string rtDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

  function screenByName(n) { return Quickshell.screens.find(s => s.name === n) ?? null }
  function touch() { idle.restart() }

  // ── IPC ──
  IpcHandler {
    target: "screenshot"
    function open(kind: string, how: string): void { root.start(kind, how) }
    function toggle(): void { if (root.open) root.close(false); else root.start("region", "edit") }
    function close(): void { root.close(false) }
    function status(): string { return (root.open ? root.phase : "closed") + " " + root.stage + " " + root.selScreen + " " + Math.round(root.selX) + "," + Math.round(root.selY) + " " + Math.round(root.selW) + "x" + Math.round(root.selH) + " ocr=" + root.hasOcr + " qr=" + root.hasQr }
    // pruebas sin ratón
    function savedir(path: string): void { root.saveDir = path }
    function select(x: int, y: int, w: int, h: int): void { root.setSel(root.cursorScreen !== "" ? root.cursorScreen : root.focusName, x, y, w, h) }
    function click(x: int, y: int): void { const n = root.focusName; root.cursorScreen = n; const r = root.windowAt(n, x, y); if (r) root.setSel(n, r.x, r.y, r.w, r.h) }
    function act(name: string): void { root.act(name) }
  }

  // ── ciclo de vida ──
  function start(kind: string, how: string): void {
    if (open) { close(false); return }
    const target = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""
    if (kind === "output" ) {            // monitor enfocado entero, sin selector
      Quickshell.execDetached({ command: [scripts + "shot-do", how === "edit" ? "edit" : "copy", "live:" + target, "1", "0", "0", "0", "0"], environment: shotEnv() })
      return
    }
    mode = how === "copy" ? "copy" : "edit"
    stage = "pick"; drag = ""
    selScreen = ""; selW = 0; selH = 0
    focusName = target; cursorScreen = target
    windows = []; files = ({})
    dir = rtDir + "/ceft-shot-" + Date.now()
    phase = "capturing"
    open = true
    deps.running = false; deps.running = true
    capture.command = ["sh", "-c", 'd=$1; shift; mkdir -p "$d" && for n in "$@"; do grim -o "$n" -t ppm "$d/$n.ppm" & done; wait', "sh", dir].concat(Quickshell.screens.map(s => s.name))
    capture.running = true
    winProc.running = false; winProc.running = true
    guard.restart(); idle.restart()
  }

  function close(acting: bool): void {
    if (!open && phase === "idle") return
    open = false
    phase = "idle"
    drag = ""
    capture.running = false
    guard.stop(); idle.stop()
    if (!acting && dir !== "") Quickshell.execDetached(["rm", "-rf", dir])
    files = ({})
  }

  Process {
    id: capture
    onExited: (code) => {
      if (!root.open) return
      if (code !== 0) { root.close(false); Quickshell.execDetached(["notify-send", "-a", "Captura", "-u", "critical", "No se pudo capturar la pantalla", "grim falló"]); return }
      const f = {}
      for (const s of Quickshell.screens) f[s.name] = root.dir + "/" + s.name + ".ppm"
      root.files = f
      root.phase = "ready"
      guard.stop()
    }
  }
  Process {
    id: winProc
    command: [root.scripts + "shot-windows"]
    stdout: StdioCollector { onStreamFinished: { try { root.windows = JSON.parse(text) } catch (e) { root.windows = [] } } }
  }
  Process {
    id: deps
    command: ["sh", "-c", 'command -v tesseract >/dev/null && { echo tess; tesseract --list-langs 2>/dev/null | tail -n +2 | grep -x "spa\\|eng"; }; command -v ZXingReader >/dev/null && echo zx; command -v satty >/dev/null && echo satty']
    stdout: StdioCollector {
      onStreamFinished: {
        const t = text.split("\n").map(l => l.trim())
        const tess = t.includes("tess"), spa = t.includes("spa"), eng = t.includes("eng")
        root.hasOcr = tess && (spa || eng)
        root.hasQr = t.includes("zx")
        root.hasSatty = t.includes("satty")
        root.ocrMissing = !tess ? "OCR no disponible: instalá tesseract, tesseract-data-spa y tesseract-data-eng"
                        : "OCR sin idiomas: instalá tesseract-data-spa y tesseract-data-eng"
      }
    }
  }
  // Salvaguardas: la pantalla congelada nunca debe quedar trabada.
  Timer { id: guard; interval: 6000; onTriggered: if (root.open && root.phase !== "ready") root.close(false) }
  Timer { id: idle; interval: 120000; onTriggered: root.close(false) }

  // ── geometría ──
  function windowAt(name: string, x: real, y: real): var {
    const s = screenByName(name)
    if (!s) return null
    const gx = x + s.x, gy = y + s.y
    for (const w of windows) {
      if (gx >= w.x && gx < w.x + w.w && gy >= w.y && gy < w.y + w.h) {
        const lx = Math.max(0, w.x - s.x), ly = Math.max(0, w.y - s.y)
        return { x: lx, y: ly, w: Math.min(s.width, w.x - s.x + w.w) - lx, h: Math.min(s.height, w.y - s.y + w.h) - ly, class: w.class }
      }
    }
    return null
  }

  function setSel(name: string, x: real, y: real, w: real, h: real): void {
    selScreen = name; selX = Math.round(x); selY = Math.round(y); selW = Math.round(w); selH = Math.round(h)
    stage = "adjust"
    if (mode === "copy") act("copy")
  }

  // asas: 0..7 = esquinas y bordes (nw n ne e se s sw w)
  readonly property var handleTable: [
    { fx: 0, fy: 0, e: "lt" }, { fx: 0.5, fy: 0, e: "t" }, { fx: 1, fy: 0, e: "rt" }, { fx: 1, fy: 0.5, e: "r" },
    { fx: 1, fy: 1, e: "rb" }, { fx: 0.5, fy: 1, e: "b" }, { fx: 0, fy: 1, e: "lb" }, { fx: 0, fy: 0.5, e: "l" } ]
  function handlePos(i: int): var { return handleTable[i] }
  function hitHandle(x: real, y: real): string {
    for (const h of handleTable) {
      if (Math.abs(x - (selX + h.fx * selW)) <= 9 && Math.abs(y - (selY + h.fy * selH)) <= 9) return h.e
    }
    return ""
  }
  function cursorFor(x: real, y: real): int {
    const e = hitHandle(x, y)
    if (e === "lt" || e === "rb") return Qt.SizeFDiagCursor
    if (e === "rt" || e === "lb") return Qt.SizeBDiagCursor
    if (e === "l" || e === "r") return Qt.SizeHorCursor
    if (e === "t" || e === "b") return Qt.SizeVerCursor
    if (x >= selX && x <= selX + selW && y >= selY && y <= selY + selH) return Qt.SizeAllCursor
    return Qt.CrossCursor
  }

  function beginDrag(name: string, x: real, y: real): void {
    if (stage === "adjust" && selScreen === name) {
      const e = hitHandle(x, y)
      if (e !== "") { drag = "resize"; dragEdges = e; dragStart = { x: selX, y: selY, w: selW, h: selH }; return }
      if (x >= selX && x <= selX + selW && y >= selY && y <= selY + selH) { drag = "move"; dragStart = { x: selX, y: selY, w: selW, h: selH }; return }
    }
    drag = "new"
    selScreen = name; selW = 0; selH = 0
    stage = "pick"
  }

  function dragTo(name: string, sw: real, sh: real, px: real, py: real, x: real, y: real): void {
    if (name !== selScreen && drag !== "new") return
    const cl = (v, lo, hi) => Math.max(lo, Math.min(hi, v))
    if (drag === "new") {
      const x0 = cl(px, 0, sw), y0 = cl(py, 0, sh), x1 = cl(x, 0, sw), y1 = cl(y, 0, sh)
      selX = Math.min(x0, x1); selY = Math.min(y0, y1); selW = Math.abs(x1 - x0); selH = Math.abs(y1 - y0)
    } else if (drag === "move") {
      selX = cl(dragStart.x + x - px, 0, sw - dragStart.w)
      selY = cl(dragStart.y + y - py, 0, sh - dragStart.h)
    } else if (drag === "resize") {
      let l = dragStart.x, r = dragStart.x + dragStart.w, t = dragStart.y, b = dragStart.y + dragStart.h
      if (dragEdges.includes("l")) l += x - px
      if (dragEdges.includes("r")) r += x - px
      if (dragEdges.includes("t")) t += y - py
      if (dragEdges.includes("b")) b += y - py
      l = cl(l, 0, sw); r = cl(r, 0, sw); t = cl(t, 0, sh); b = cl(b, 0, sh)
      selX = Math.min(l, r); selW = Math.abs(r - l); selY = Math.min(t, b); selH = Math.abs(b - t)
    }
  }

  function endDrag(name: string, moved: bool, hover: var): void {
    const d = drag
    drag = ""
    if (d === "new") {
      if (moved && selW >= 4 && selH >= 4) { setSel(name, selX, selY, selW, selH) }
      else if (hover) { setSel(name, hover.x, hover.y, hover.w, hover.h) }
      else { selW = 0; selH = 0; stage = "pick" }
    } else if (d === "move" || d === "resize") {
      if (selW < 4 || selH < 4) { selW = 0; selH = 0; stage = "pick" }
    }
  }

  function back(): void {          // clic derecho: deshacer la selección o salir
    if (stage === "adjust") { selW = 0; selH = 0; stage = "pick"; drag = "" }
    else close(false)
  }

  // ── teclas ──
  function key(e): void {
    touch()
    const shift = (e.modifiers & Qt.ShiftModifier) !== 0
    switch (e.key) {
    case Qt.Key_Escape: close(false); break
    case Qt.Key_Return: case Qt.Key_Enter: act(defAction); break
    case Qt.Key_C: act("copy"); break
    case Qt.Key_S: act("save"); break
    case Qt.Key_E: act("edit"); break
    case Qt.Key_O: act("ocr"); break
    case Qt.Key_Q: act("qr"); break
    case Qt.Key_R: act(shift ? "recaudio" : "rec"); break
    case Qt.Key_F: act("full"); break
    }
  }

  function shotEnv(): var { return saveDir !== "" ? ({ SCREENSHOT_DIR: saveDir }) : ({}) }

  // rect objetivo de una acción: selección, o la ventana bajo el cursor
  function targetRect(): var {
    if (hasSel && selScreen !== "") return { name: selScreen, x: selX, y: selY, w: selW, h: selH }
    const n = cursorScreen !== "" ? cursorScreen : focusName
    const hv = windowAt(n, hoverX, hoverY)
    return hv ? { name: n, x: hv.x, y: hv.y, w: hv.w, h: hv.h } : null
  }
  property real hoverX: -1
  property real hoverY: -1

  function act(name: string): void {
    if (!showing) return
    if (name === "cancel") { close(false); return }
    if (name === "full") {
      const n = cursorScreen !== "" ? cursorScreen : focusName
      const s = screenByName(n)
      if (!s) return
      setSelNoAct(n, 0, 0, s.width, s.height)
      if (mode === "copy") doAct("copy", targetRect())
      return
    }
    const r = targetRect()
    if (!r) return
    doAct(name, r)
  }
  function setSelNoAct(n: string, x: real, y: real, w: real, h: real): void {
    selScreen = n; selX = x; selY = y; selW = w; selH = h; stage = "adjust"
  }

  function ratio(name: string): real {
    const s = screenByName(name)
    // La relación px de la captura / px lógicos: grim guarda a escala nativa; se lee del monitor
    const m = Hyprland.monitors.values.find(m => m.name === name)
    return m ? (m.scale ?? 1) : (s ? s.devicePixelRatio : 1)
  }

  function doAct(name: string, r: var): void {
    const s = screenByName(r.name)
    if (!s) return
    const file = files[r.name]
    if (name === "rec" || name === "recaudio") {
      const gx = Math.round(r.x + s.x), gy = Math.round(r.y + s.y), gw = Math.round(r.w), gh = Math.round(r.h)
      close(false)
      Quickshell.execDetached({ command: ["sh", "-c", 'sleep 0.45; exec "$1" region --geom "$2" ${3:+--audio}', "sh", scripts + "screenrecord", gx + "," + gy + " " + gw + "x" + gh, name === "recaudio" ? "1" : ""], environment: shotEnv() })
      return
    }
    if (name === "ocr" && !hasOcr) { notifyMissing(ocrMissing); return }
    if (name === "qr" && !hasQr) { notifyMissing("QR no disponible: instalá zxing-cpp"); return }
    if (name === "edit" && !hasSatty) { notifyMissing("Instalá satty para anotar capturas"); return }
    close(true)
    Quickshell.execDetached({ command: [scripts + "shot-do", name, file, String(ratio(r.name)), String(r.x), String(r.y), String(r.w), String(r.h)], environment: shotEnv() })
  }
  function notifyMissing(msg: string): void {
    Quickshell.execDetached(["notify-send", "-a", "Captura", "-u", "low", "Opción no disponible", msg])
  }

  Variants {
    model: Quickshell.screens
    ShotWindow { shot: root }
  }
}
