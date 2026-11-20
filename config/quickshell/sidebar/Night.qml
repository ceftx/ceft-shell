pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Luz nocturna con horario (hyprsunset). Config: ~/.config/ceft-shell/nightlight.json
//   {"enabled":bool,"temp":2400,"auto":bool,"from":"20:00","to":"07:00"}
// Con auto, `enabled` lo decide el horario (cada 30 s); sin auto, lo decide el interruptor.
// Solo se actúa en las transiciones del estado deseado (así SUPER+R / SUPER+SHIFT+R siguen funcionando).
// `running` refleja el proceso real de hyprsunset.
Singleton {
  id: root
  readonly property string path: Quickshell.env("HOME") + "/.config/ceft-shell/nightlight.json"

  property bool enabled: false
  property int temp: 2400
  property bool auto: false
  property string from: "20:00"
  property string to: "07:00"
  property bool running: false
  property bool loaded: false
  property int tick: 0                  // fuerza reevaluar el horario

  readonly property bool inWindow: { tick; return withinWindow(from, to, new Date()) }
  readonly property bool want: auto ? inWindow : enabled
  property bool lastWant: false
  property bool guard: false
  readonly property bool active: running

  function minutes(hhmm) {
    const m = /^(\d{1,2}):(\d{2})$/.exec(String(hhmm))
    if (!m) return -1
    const h = Number(m[1]), mi = Number(m[2])
    return h > 23 || mi > 59 ? -1 : h * 60 + mi
  }
  function withinWindow(f, t, d) {
    const a = minutes(f), b = minutes(t)
    if (a < 0 || b < 0 || a === b) return false
    const n = d.getHours() * 60 + d.getMinutes()
    return a < b ? (n >= a && n < b) : (n >= a || n < b)
  }
  function fmt(h, m) { return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") }

  // ── persistencia ──
  FileView {
    id: file
    path: root.path
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        const j = JSON.parse(text())
        root.enabled = j.enabled === true
        root.temp = Math.max(1000, Math.min(6500, Math.round(Number(j.temp) || 2400)))
        root.auto = j.auto === true
        root.from = root.minutes(j.from) >= 0 ? j.from : "20:00"
        root.to = root.minutes(j.to) >= 0 ? j.to : "07:00"
      } catch (e) { console.warn("nightlight.json inválido:", e) }
      if (!root.loaded) { root.loaded = true; root.lastWant = root.want; if (root.want) root.apply(true) }
    }
    onLoadFailed: root.loaded = true
  }
  function save() {
    file.setText(JSON.stringify({ enabled: enabled, temp: temp, auto: auto, from: from, to: to }, null, 2) + "\n")
  }
  function set(key, v) { root[key] = v; save() }

  // ── hyprsunset ──
  Process { id: runner }
  Process { id: check; command: ["pgrep", "-x", "hyprsunset"]; onExited: c => root.running = c === 0 }
  function refresh() { if (!check.running) check.running = true }
  function apply(on) {
    runner.command = ["sh", "-c", on
      ? "pkill -x hyprsunset; sleep 0.15; setsid -f hyprsunset -t " + temp + " >/dev/null 2>&1; true"
      : "pkill -x hyprsunset; true"]
    runner.running = true
    running = on
    recheck.restart()
  }
  Timer { id: recheck; interval: 1200; onTriggered: root.refresh() }
  Timer { id: tempDebounce; interval: 350; onTriggered: if (root.running) root.apply(true) }

  // El interruptor de la grilla: apaga el horario si estaba (el usuario toma el control a mano).
  function toggle() {
    const on = !running
    guard = true
    if (auto) auto = false
    enabled = on
    lastWant = on
    guard = false
    save()
    apply(on)
  }
  function setTemp(k) { temp = Math.round(k / 50) * 50; save(); tempDebounce.restart() }

  onWantChanged: {
    if (!loaded || guard || want === lastWant) return
    lastWant = want
    apply(want)
  }

  Timer { interval: 30000; running: true; repeat: true; onTriggered: { root.tick++; root.refresh() } }
  Component.onCompleted: refresh()

  // qs ipc call nightlight toggle|on|off
  IpcHandler {
    target: "nightlight"
    function toggle(): void { root.toggle() }
    function on(): void { if (!root.running) root.toggle() }
    function off(): void { if (root.running) root.toggle() }
  }
}
