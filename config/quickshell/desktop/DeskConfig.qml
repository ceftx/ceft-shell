pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// ~/.config/ceft-shell/widgets.json (se recarga en vivo). Esquema: ver gan-harness/generator-state-widgets.md
Singleton {
  id: root
  property var c: ({})

  FileView {
    path: Quickshell.env("HOME") + "/.config/ceft-shell/widgets.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.c = JSON.parse(text()) } catch (e) { console.warn("widgets.json inválido:", e) }
    }
  }

  readonly property var defaultEnabled: ["profile", "clock", "bigclock", "media", "weather", "calendar", "resources", "converter"]
  readonly property var enabled: c.enabled ?? defaultEnabled
  readonly property var layout: ({
    left:  c.layout?.left  ?? ["profile", "clock", "converter"],
    right: c.layout?.right ?? ["bigclock", "media", "weather", "resources"],
    bottomRight: c.layout?.bottomRight ?? ["calendar"],
    bottomLeft: c.layout?.bottomLeft ?? []
  })
  readonly property var weather: c.weather ?? ({})
  readonly property real lat: weather.latitude ?? 10.4806
  readonly property real lon: weather.longitude ?? -66.9036
  readonly property string city: weather.city ?? ""
  readonly property string units: weather.units ?? "celsius"
  readonly property var worldClocks: c.worldClocks ?? []
  readonly property var profile: c.profile ?? ({})
  readonly property real margin: c.margin ?? 28

  function on(id) { return enabled.indexOf(id) >= 0 }
  function list(side) { return (layout[side] ?? []).filter(id => on(id)) }
}
