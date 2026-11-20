pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Personalización: bar.json y ui.json (contrato en gan-harness/spec-customize.md) + acciones compartidas
// entre Rápido / Barra / Interfaz / Servicios (así ningún control duplica la lógica de escritura).
// Solo se guardan las diferencias con los defaults del contrato; se preservan las claves desconocidas.
Singleton {
  id: root

  readonly property var barDef: ({
    position: "top", style: "float", groupBackground: false, showBackground: true, autohide: false, divider: "dots",
    left: ["launcher", "activeWindow"],
    center: ["resources", "workspaces", "clock"],
    right: ["record", "privacy", "tray", "systemIcons", "notifications", "power"],
    tray: { tint: true, hidden: ["nm-applet"] },
    clock: { showWeather: true, showDate: true }
  })
  readonly property var uiDef: ({
    glassAlpha: 0.74, barAlpha: 0.55, popupAlpha: 0.84,
    radius: 20, radiusSmall: 12, borderWidth: 1,
    fontSans: "Inter", fontMono: "JetBrainsMono Nerd Font", fontSize: 13,
    clock24h: true, clockSeconds: false, dateFormat: "ddd, dd/MM",
    animations: true
  })

  // Módulos de la barra: id, nombre legible e ícono (Material Symbols)
  readonly property var modules: [
    { id: "launcher",       name: "Lanzador",            icon: "apps" },
    { id: "activeWindow",   name: "Ventana activa",      icon: "web_asset" },
    { id: "workspaces",     name: "Espacios de trabajo", icon: "grid_view" },
    { id: "clock",          name: "Reloj",               icon: "schedule" },
    { id: "weather",        name: "Clima",               icon: "partly_cloudy_day" },
    { id: "resources",      name: "Recursos y uso de IA", icon: "memory" },
    { id: "media",          name: "Multimedia",          icon: "music_note" },
    { id: "tray",           name: "Bandeja",             icon: "inbox" },
    { id: "systemIcons",    name: "Íconos del sistema",  icon: "tune" },
    { id: "record",         name: "Grabación",           icon: "fiber_manual_record" },
    { id: "privacy",        name: "Privacidad (mic, cámara, pantalla)", icon: "shield" },
    { id: "power",          name: "Apagado",             icon: "power_settings_new" },
    { id: "netSpeed",       name: "Velocidad de red",    icon: "swap_vert" },
    { id: "updates",        name: "Actualizaciones",     icon: "system_update_alt" },
    { id: "keyboardLayout", name: "Distribución de teclado", icon: "keyboard" },
    { id: "utilButtons",    name: "Utilidades",          icon: "construction" },
    { id: "notifications",  name: "Notificaciones",      icon: "notifications" },
    { id: "divider",        name: "Divisor",             icon: "more_vert" }
  ]
  function moduleInfo(id) { return modules.find(m => m.id === id) ?? { id: id, name: id, icon: "extension" } }
  // Módulos que se pueden agregar: los que no están en ninguna zona (el divisor siempre)
  readonly property var available: modules.filter(m => m.id === "divider" || zoneOf(m.id) === "")

  property var bar: ({})      // contenido real de bar.json
  property var ui: ({})       // contenido real de ui.json

  FileView {
    id: barFile
    path: CCStore.cfgDir + "/bar.json"
    watchChanges: true
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: { try { const o = JSON.parse(text()); root.bar = (o && typeof o === "object") ? o : ({}) } catch (e) { console.warn("bar.json inválido:", e) } root.flush("bar") }
    onLoadFailed: { root.bar = ({}); root.flush("bar") }
  }
  FileView {
    id: uiFile
    path: CCStore.cfgDir + "/ui.json"
    watchChanges: true
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: { try { const o = JSON.parse(text()); root.ui = (o && typeof o === "object") ? o : ({}) } catch (e) { console.warn("ui.json inválido:", e) } root.flush("ui") }
    onLoadFailed: { root.ui = ({}); root.flush("ui") }
  }

  // Singleton perezoso: si alguien escribe antes de que termine la primera lectura, la escritura espera
  // (si no, se pisaría el archivo con un estado vacío).
  property var loadedFiles: ({})
  property var queue: ({})
  function flush(file) {
    loadedFiles[file] = true
    const q = queue[file] ?? []
    queue[file] = []
    for (const fn of q) fn()
  }
  function whenLoaded(file, fn) {
    if (loadedFiles[file]) { fn(); return }
    (queue[file] = queue[file] ?? []).push(fn)
  }

  // ── lectura ──
  function barGet(path) { const v = CCStore.getIn(bar, path); return v !== undefined ? v : CCStore.getIn(barDef, path) }
  function uiGet(path) { const v = CCStore.getIn(ui, path); return v !== undefined ? v : CCStore.getIn(uiDef, path) }
  // "Modificado" = distinto del default (el archivo puede traer las claves con sus valores de fábrica)
  function barIsSet(path) { const v = CCStore.getIn(bar, path); return v !== undefined && JSON.stringify(v) !== JSON.stringify(CCStore.getIn(barDef, path)) }
  function uiIsSet(path) { const v = CCStore.getIn(ui, path); return v !== undefined && JSON.stringify(v) !== JSON.stringify(CCStore.getIn(uiDef, path)) }

  // ── escritura ──
  function save(file, obj) {
    CCStore.prune(obj)
    const text = JSON.stringify(obj, null, 2) + "\n"
    if (file === "bar") { bar = obj; barFile.setText(text) } else { ui = obj; uiFile.setText(text) }
  }
  function setIn(file, path, value) {
    if (!loadedFiles[file]) { whenLoaded(file, () => setIn(file, path, value)); return }
    const copy = JSON.parse(JSON.stringify(file === "bar" ? bar : ui))
    const def = CCStore.getIn(file === "bar" ? barDef : uiDef, path)
    CCStore.setPath(copy, path, JSON.stringify(value) === JSON.stringify(def) ? undefined : value)
    save(file, copy)
  }
  function setBar(path, value) { setIn("bar", path, value); CCStore.notify("Barra actualizada", false) }
  function setUi(path, value) { setIn("ui", path, value); CCStore.notify("Interfaz actualizada", false) }
  function resetUi(paths) {
    if (!loadedFiles["ui"]) { whenLoaded("ui", () => resetUi(paths)); return }
    const copy = JSON.parse(JSON.stringify(ui))
    for (const p of paths) CCStore.setPath(copy, p, undefined)
    save("ui", copy)
  }
  function resetBar(paths) {
    if (!loadedFiles["bar"]) { whenLoaded("bar", () => resetBar(paths)); return }
    const copy = JSON.parse(JSON.stringify(bar))
    for (const p of paths) CCStore.setPath(copy, p, undefined)
    save("bar", copy)
  }

  // ── zonas de la barra ──
  readonly property var zoneNames: ["left", "center", "right"]
  function zone(name) { const z = barGet(name); return Array.isArray(z) ? z : [] }
  // Si las tres zonas vuelven a ser las de fábrica se borran las tres claves; si no, se guardan las tres juntas.
  function setZone(name, list) {
    const z = { left: zone("left"), center: zone("center"), right: zone("right") }
    z[name] = list
    const copy = JSON.parse(JSON.stringify(bar))
    const same = zoneNames.every(n => JSON.stringify(z[n]) === JSON.stringify(barDef[n]))
    for (const n of zoneNames) { if (same) delete copy[n]; else copy[n] = z[n] }
    save("bar", copy)
    CCStore.notify("Barra actualizada", false)
  }
  function zoneOf(id) { return zoneNames.find(n => zone(n).indexOf(id) >= 0) ?? "" }
  function addModule(name, id) {
    if (!loadedFiles["bar"]) { whenLoaded("bar", () => addModule(name, id)); return }
    const cur = zone(name)
    if (id !== "divider" && zoneOf(id) !== "") return
    setZone(name, cur.concat([id]))
  }
  function removeAt(name, i) {
    if (!loadedFiles["bar"]) { whenLoaded("bar", () => removeAt(name, i)); return } setZone(name, zone(name).filter((_, k) => k !== i)) }
  function moveAt(name, i, d) {
    if (!loadedFiles["bar"]) { whenLoaded("bar", () => moveAt(name, i, d)); return }
    const l = zone(name).slice(); const j = i + d
    if (j < 0 || j >= l.length) return
    const t = l[i]; l[i] = l[j]; l[j] = t
    setZone(name, l)
  }

  // Lista de la bandeja oculta: bar.json > widgets.json bar.hiddenTray (migración) > ["nm-applet"]
  readonly property var trayHidden: {
    const b = CCStore.getIn(bar, "tray.hidden")
    if (Array.isArray(b)) return b
    const w = CCStore.w.bar?.hiddenTray
    return Array.isArray(w) ? w : barDef.tray.hidden
  }
  // Se guarda siempre explícita: así no depende de widgets.json
  function setTrayHidden(list) {
    if (!loadedFiles["bar"]) { whenLoaded("bar", () => setTrayHidden(list)); return }
    const copy = JSON.parse(JSON.stringify(bar))
    if (typeof copy.tray !== "object" || copy.tray === null) copy.tray = ({})
    copy.tray.hidden = list
    save("bar", copy)
    CCStore.notify("Bandeja actualizada", false)
  }

  // ── acciones compartidas ──
  // Animaciones: las de Hyprland (overrides.json) y las de la UI de Quickshell (ui.json) van juntas.
  function setAnimations(on) { CCStore.setOver("look.animations", on); setUi("animations", on) }
  readonly property bool animationsOn: CCStore.eff("look.animations") === true && uiGet("animations") === true

  // Actualizaciones = que el módulo "updates" esté en la barra
  readonly property bool updatesOn: zoneOf("updates") !== ""
  function setUpdates(on) {
    if (!loadedFiles["bar"]) { whenLoaded("bar", () => setUpdates(on)); return }
    if (on) {
      const r = zone("right")
      const at = r.indexOf("power")
      const l = r.slice(); l.splice(at >= 0 ? at : l.length, 0, "updates")
      setZone("right", l)
    } else {
      const n = zoneOf("updates")
      if (n !== "") setZone(n, zone(n).filter(x => x !== "updates"))
    }
  }

  // ── wallpaper y tema (Rápido) ──
  readonly property string home: CCStore.home
  property string currentWall: ""
  property string currentTheme: ""
  property var recentWalls: []        // los más recientes primero
  property int wallCount: 0
  property var themeNames: []
  property string pending: ""
  readonly property bool applying: applyProc.running
  property string applyLast: ""

  FileView {
    path: root.home + "/.local/state/ceft-shell/wallpaper"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.currentWall = text().trim()
  }
  FileView {
    path: CCStore.cfgDir + "/theme.name"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.currentTheme = text().trim()
  }
  function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
  Process {
    id: applyProc
    stdout: SplitParser { onRead: line => { const l = line.replace(/^\s*[✓✗!]\s*/, "").trim(); if (l !== "") root.applyLast = l } }
    stderr: SplitParser { onRead: line => { const l = line.replace(/^\s*[✓✗!]\s*/, "").trim(); if (l !== "") root.applyLast = l } }
    onExited: (code) => { CCStore.notify(code === 0 ? (root.applyLast || "Aplicado") : "Falló: " + root.applyLast, code !== 0); root.pending = "" }
  }
  function runApply(id, cmd) {
    if (applyProc.running) return
    pending = id; applyLast = ""
    applyProc.command = ["sh", "-c", cmd]
    applyProc.running = true
  }
  function setWall(path) { runApply(path, CCStore.cli + " wall " + shq(path)) }
  function setTheme(name) { runApply("theme:" + name, CCStore.cli + " theme " + shq(name)) }

  Process {
    id: recentProc
    stdout: StdioCollector {
      onStreamFinished: {
        const l = text.split("\n").map(x => x.trim()).filter(x => x.startsWith("/"))
        root.wallCount = l.length
        root.recentWalls = l.slice(0, 8)
      }
    }
  }
  Process {
    id: themeProc
    stdout: StdioCollector {
      onStreamFinished: root.themeNames = text.split("\n").map(s => s.replace(/^\s*\*?\s*/, "").trim()).filter(s => s !== "" && !s.includes(" "))
    }
  }
  // Wallpapers por fecha de modificación (más nuevos primero)
  function refreshWalls() {
    recentProc.command = ["sh", "-c", CCStore.cli + " wall list | tr '\\n' '\\0' | xargs -0 -r ls -t 2>/dev/null"]
    recentProc.running = true
    themeProc.command = [CCStore.cli, "theme", "list"]
    themeProc.running = true
  }

  // ── luz nocturna (hyprsunset) ──
  property bool nightOn: false
  Process { id: nightCheck; command: ["pgrep", "-x", "hyprsunset"]; onExited: (c) => root.nightOn = c === 0 }
  Process { id: nightRun }
  function refreshNight() { nightCheck.running = true }
  function setNight(on) {
    const k = Math.round(Number(CCStore.eff("nightlight") ?? 3500))
    nightRun.command = ["sh", "-c", on ? "pkill -x hyprsunset; setsid -f hyprsunset -t " + k + " >/dev/null 2>&1; true" : "pkill -x hyprsunset; true"]
    nightRun.running = true
    nightOn = on
    nightRecheck.restart()
  }
  Timer { id: nightRecheck; interval: 1200; onTriggered: root.refreshNight() }
}
