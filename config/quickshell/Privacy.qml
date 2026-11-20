pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Qué recursos de privacidad están en uso ahora mismo, y qué app los usa.
// Se mira el grafo de Pipewire: un enlace (link group) cuyo origen es un nodo de captura y cuyo destino es el stream de una app.
//   micrófono  → origen Audio/Source (no monitores de salida) hacia Stream/Input/Audio
//   cámara     → origen Video/Source (v4l2/libcamera)
//   pantalla   → origen Stream/Output/Video (screencast del portal) o cualquier otro stream de video
Singleton {
  id: root

  function cls(n) { return n && n.properties ? (n.properties["media.class"] || "") : "" }
  function appName(n) {
    if (!n) return "?"
    const p = n.properties || ({})
    return p["application.name"] || p["node.nick"] || n.nickname || n.description || n.name || "?"
  }

  // Cada entrada: { kind: "mic"|"camera"|"screen", app: string }
  readonly property var uses: {
    const out = [], seen = {}
    for (const lg of Pipewire.linkGroups.values) {
      const s = lg.source, t = lg.target
      if (!s || !t) continue
      let kind = ""
      const sc = cls(s)
      // Se mira el tipo y también media.class (las fuentes virtuales no siempre llegan como AudioSource)
      if ((s.type === PwNodeType.AudioSource || sc.startsWith("Audio/Source")) && t.type === PwNodeType.AudioInStream) kind = "mic"
      else if (s.type === PwNodeType.VideoSource || sc.startsWith("Video/Source") || sc === "Stream/Output/Video") kind = sc.startsWith("Video/Source") ? "camera" : "screen"
      if (kind === "") continue
      const app = appName(t)
      const key = kind + "|" + app
      if (seen[key]) continue
      seen[key] = true
      out.push({ kind: kind, app: app })
    }
    return out
  }
  function appsOf(kind) { return uses.filter(u => u.kind === kind).map(u => u.app) }
  readonly property var micApps: appsOf("mic")
  readonly property var cameraApps: appsOf("camera")
  readonly property var screenApps: appsOf("screen")
  readonly property bool mic: micApps.length > 0
  readonly property bool camera: cameraApps.length > 0
  readonly property bool screen: screenApps.length > 0
  readonly property bool any: mic || camera || screen

  // Los nodos enlazados tienen que estar "bound" para exponer propiedades (application.name, media.class…)
  PwObjectTracker {
    objects: {
      const o = []
      for (const lg of Pipewire.linkGroups.values) { if (lg.source) o.push(lg.source); if (lg.target) o.push(lg.target) }
      return o
    }
  }
}
