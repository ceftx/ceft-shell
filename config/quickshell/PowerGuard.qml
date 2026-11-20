pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Punto único para apagar / reiniciar / suspender / cerrar sesión.
// Antes de ejecutar llama a `ceft-shell session-check --json`; si hay bloqueos (pacman corriendo, descargas a medias,
// grabación activa...) abre el diálogo (PowerDialog) con la lista y "Cancelar" / "Igual ...".
// Si el comando no existe o falla, NO se bloquea el apagado (falla con gracia).
//
// Hooks de prueba (variables de entorno de Quickshell): CEFT_SESSION_CHECK=<ruta del check> reemplaza al CLI;
// CEFT_POWER_DRYRUN=1 escribe la acción en $XDG_RUNTIME_DIR/ceft-power-dryrun en vez de ejecutarla.
Singleton {
  id: root
  readonly property string cli: Quickshell.env("HOME") + "/.local/bin/ceft-shell"
  readonly property string checkOverride: Quickshell.env("CEFT_SESSION_CHECK") || ""
  readonly property bool dryRun: (Quickshell.env("CEFT_POWER_DRYRUN") || "") === "1"

  readonly property var actions: ({
    suspend:  { label: "Suspender",     force: "Igual suspender",      cmd: "systemctl suspend" },
    reboot:   { label: "Reiniciar",     force: "Igual reiniciar",      cmd: "systemctl reboot" },
    poweroff: { label: "Apagar",        force: "Igual apagar",         cmd: "systemctl poweroff" },
    logout:   { label: "Cerrar sesión", force: "Igual cerrar sesión",  cmd: "hyprctl dispatch 'hl.dsp.exit()'" }
  })

  property string kind: ""            // acción en espera de decisión (dialogo abierto)
  property var blockers: []           // [{kind, detail}]
  property string pendingKind: ""     // acción cuyo chequeo está corriendo
  readonly property bool dialogOpen: kind !== ""

  readonly property var kindText: ({
    pacman: "Instalación o actualización de paquetes",
    download: "Descarga a medias",
    recording: "Grabación de pantalla activa"
  })
  function describe(b) {
    const k = b.kind || ""
    return { title: kindText[k] ?? (k !== "" ? k : "Algo sigue en curso"), detail: b.detail || "" }
  }

  function request(k) {
    if (!actions[k] || checker.running || dialogOpen) return
    pendingKind = k
    checker.command = checkOverride !== "" ? ["sh", "-c", checkOverride]
                                           : [cli, "session-check", "--json"]
    checkOut = ""
    checker.running = true
    watchdog.restart()
  }
  function cancel() { kind = ""; blockers = [] }

  // Menú de sesión temático (PowerMenu)
  property bool menuOpen: false
  function openMenu() { if (!dialogOpen) menuOpen = true }
  function closeMenu() { menuOpen = false }
  function lock() { Quickshell.execDetached(["sh", "-c", "if command -v hyprlock >/dev/null; then pidof hyprlock || hyprlock; else loginctl lock-session; fi"]) }
  function confirm() { const k = kind; cancel(); run(k) }

  function run(k) {
    const a = actions[k]
    if (!a) return
    if (dryRun) Quickshell.execDetached(["sh", "-c", "echo " + k + " >> \"${XDG_RUNTIME_DIR:-/tmp}/ceft-power-dryrun\""])
    else Quickshell.execDetached(["sh", "-c", a.cmd])
  }

  property string checkOut: ""
  function finishCheck() {
    watchdog.stop()
    const k = pendingKind
    if (k === "") return
    pendingKind = ""
    let list = []
    try {
      const j = JSON.parse(checkOut)
      list = Array.isArray(j.blockers) ? j.blockers : []
    } catch (e) { list = [] }     // sin JSON utilizable (comando ausente o roto): no se bloquea
    if (list.length === 0) run(k)
    else { blockers = list; kind = k }
  }
  Process {
    id: checker
    stdout: SplitParser { splitMarker: ""; onRead: data => root.checkOut += data }
    onExited: root.finishCheck()
  }
  // Si el proceso ni siquiera arranca (no hay exited) o se cuelga, no se deja al usuario sin poder apagar.
  Timer { id: watchdog; interval: 6000; onTriggered: { checker.running = false; root.finishCheck() } }

  // qs ipc call power request poweroff|reboot|suspend|logout
  IpcHandler {
    target: "power"
    function request(kind: string): void { root.request(kind) }
    function cancel(): void { root.cancel() }
    function menu(): void { root.menuOpen ? root.closeMenu() : root.openMenu() }
    function confirm(): void { if (root.dialogOpen) root.confirm() }
  }
}
