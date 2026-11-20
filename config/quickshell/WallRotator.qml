import Quickshell
import Quickshell.Io
import QtQuick

// Rotación automática del wallpaper: overrides.json → wallpaper.interval_min (> 0) y wallpaper.transition.
// Cada N minutos ejecuta `ceft-shell wall next` (con CEFT_WALL_TRANSITION). Se recarga en vivo.
Scope {
  id: root
  property var o: ({})
  readonly property var w: o.wallpaper ?? ({})
  readonly property real minutes: Number(w.interval_min ?? 0) || 0
  readonly property bool active: w.enabled !== false && minutes > 0
  readonly property string transition: typeof w.transition === "string" && w.transition !== "" ? w.transition : "grow"

  FileView {
    path: Quickshell.env("HOME") + "/.config/ceft-shell/overrides.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.o = JSON.parse(text()) } catch (e) { console.warn("overrides.json inválido:", e) } }
    onLoadFailed: root.o = ({})
  }

  Timer {
    interval: Math.max(1, root.minutes) * 60000
    running: root.active
    repeat: true
    onTriggered: Quickshell.execDetached(["env", "CEFT_WALL_TRANSITION=" + root.transition,
      Quickshell.env("HOME") + "/.local/bin/ceft-shell", "wall", "next"])
  }
}
