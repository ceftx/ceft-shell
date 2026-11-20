pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.desktop

// ~/.config/ceft-shell/bar.json (lo escribe el Centro de control; se recarga en vivo).
// Claves ausentes o inválidas toman el default = la barra de siempre.
Singleton {
  id: root
  property var c: ({})

  FileView {
    path: Quickshell.env("HOME") + "/.config/ceft-shell/bar.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { const v = JSON.parse(text()); root.c = (v && typeof v === "object" && !Array.isArray(v)) ? v : ({}) }
      catch (e) { console.warn("bar.json inválido:", e) }
    }
    onLoadFailed: root.c = ({})
  }

  // Ids válidos (ver gan-harness/spec-customize.md). Un módulo aparece una sola vez, salvo "divider".
  readonly property var validIds: ["launcher", "activeWindow", "workspaces", "clock", "weather", "resources", "media",
    "tray", "systemIcons", "record", "privacy", "power", "netSpeed", "updates", "keyboardLayout", "utilButtons", "notifications", "divider"]
  readonly property var defaultLeft: ["launcher", "activeWindow"]
  readonly property var defaultCenter: ["resources", "workspaces", "clock"]
  readonly property var defaultRight: ["record", "privacy", "tray", "systemIcons", "notifications", "power"]

  function oneOf(v, list, def) { return list.indexOf(v) >= 0 ? v : def }

  readonly property string position: oneOf(c.position, ["top", "bottom", "left", "right"], "top")
  readonly property bool isBottom: position === "bottom"
  readonly property bool isLeft: position === "left"
  readonly property bool isRight: position === "right"
  readonly property bool vertical: isLeft || isRight
  readonly property int thickness: vertical ? Theme.barW : Theme.barH       // grosor de la barra (alto o ancho)
  readonly property string style: oneOf(c.style, ["hug", "float", "islands"], "float")
  readonly property bool groupBackground: c.groupBackground === true
  readonly property bool showBackground: c.showBackground !== false
  readonly property bool autohide: c.autohide === true
  readonly property string divider: oneOf(c.divider, ["dots", "line", "space"], "dots")

  // Listas limpias: solo ids válidos, sin repetidos (salvo divider) ni en dos zonas a la vez
  readonly property var zones: {
    const seen = {}
    function clean(list, def) {
      const src = Array.isArray(list) ? list : def
      const out = []
      for (const id of src) {
        if (validIds.indexOf(id) < 0) continue
        if (id !== "divider") { if (seen[id]) continue; seen[id] = true }
        out.push(id)
      }
      return out
    }
    return { left: clean(c.left, defaultLeft), center: clean(c.center, defaultCenter), right: clean(c.right, defaultRight) }
  }
  readonly property var left: zones.left
  readonly property var center: zones.center
  readonly property var right: zones.right
  function has(id) { return left.indexOf(id) >= 0 || center.indexOf(id) >= 0 || right.indexOf(id) >= 0 }

  // Tray: "hidden" reemplaza a widgets.json bar.hiddenTray (migración: se usa si bar.json no lo define)
  readonly property var trayCfg: c.tray ?? ({})
  readonly property bool trayTint: trayCfg.tint !== false
  readonly property var trayHidden: Array.isArray(trayCfg.hidden) ? trayCfg.hidden
                                    : ((DeskConfig.c.bar ?? {}).hiddenTray ?? ["nm-applet"])

  readonly property var clockCfg: c.clock ?? ({})
  readonly property bool clockShowWeather: clockCfg.showWeather !== false
  readonly property bool clockShowDate: clockCfg.showDate !== false

  // Extra (fuera del contrato, opcional): resources.showSystem → CPU/RAM junto al uso de IA
  readonly property bool showSystemStats: (c.resources ?? ({})).showSystem === true
}
