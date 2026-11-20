pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// Servidor de notificaciones (org.freedesktop.Notifications) en Quickshell: reemplaza a dunst.
//   list     historial (el más nuevo primero, máx. 200): { id, appName, appIcon, image, summary, body, time, urgency, actions[], read, live }
//            id = propio y estable entre reinicios; urgency = "low" | "normal" | "critical"; live = aún se puede invocar acciones
//   unread   cuántas siguen sin leer · dnd  no molestar (solo se muestran las críticas; persiste junto al historial)
//   popups   ListModel { nid } con los popups visibles (los dibuja NotifPopups.qml)
//   dismiss(id) · clearAll() · markAllRead() · invoke(id, actionId)
//   qs ipc call notifs toggleDnd | setDnd true|false | getDnd | clear | count | markRead
// Al arrancar, si dunst sigue vivo se le pide que salga para poder registrar el nombre en D-Bus. Si Quickshell se cae,
// dunst (activación D-Bus) vuelve a atender las notificaciones hasta que Quickshell reinicie (y lo desplaza otra vez).
Singleton {
  id: root

  readonly property int maxHistory: 200
  readonly property int maxPopups: 5
  property var list: []
  property bool dnd: false
  readonly property int unread: list.reduce((n, e) => n + (e.read ? 0 : 1), 0)
  property bool ready: false       // el servidor ya registró el nombre en D-Bus
  readonly property ListModel popups: ListModel {}

  // Hora relativa ("ahora", "hace 5 min", "14:32", "ayer", "12/11"); `now` se refresca cada 30 s
  property real now: Date.now()
  Timer { interval: 30000; running: root.list.length > 0; repeat: true; onTriggered: root.now = Date.now() }
  function ago(t) {
    const d = Math.max(0, root.now - t), min = Math.floor(d / 60000)
    if (min < 1) return "ahora"
    if (min < 60) return "hace " + min + " min"
    const dt = new Date(t), today = new Date(root.now)
    const pad = n => String(n).padStart(2, "0")
    if (dt.toDateString() === today.toDateString()) return pad(dt.getHours()) + ":" + pad(dt.getMinutes())
    if (today.getTime() - t < 172800000 && today.getDate() !== dt.getDate()) return "ayer"
    return pad(dt.getDate()) + "/" + pad(dt.getMonth() + 1)
  }

  // ── interno ──
  property int nextId: 1
  property var liveById: ({})      // id propio -> Notification (para invocar acciones / cerrar al emisor)
  property var serverIds: ({})     // id del servidor -> id propio (notificaciones que se reemplazan)
  property bool loaded: false

  function byId(id) { return list.find(e => e.id === id) ?? null }
  function mutate(id, fn) {
    const i = list.findIndex(e => e.id === id)
    if (i < 0) return
    const e = Object.assign({}, list[i]); fn(e)
    const l = list.slice(); l[i] = e; list = l
    save()
  }

  function popupIndex(id) { for (let i = 0; i < popups.count; i++) if (popups.get(i).nid === id) return i; return -1 }
  function showPopup(id) {
    if (popupIndex(id) >= 0) return
    popups.insert(0, { nid: id })
    while (popups.count > maxPopups) popups.remove(popups.count - 1)
  }
  function hidePopup(id) { const i = popupIndex(id); if (i >= 0) popups.remove(i) }

  function toEntry(n, id) {
    const u = n.urgency === NotificationUrgency.Critical ? "critical" : n.urgency === NotificationUrgency.Low ? "low" : "normal"
    return {
      id: id, sid: n.id, appName: n.appName || n.desktopEntry || "Sistema", appIcon: n.appIcon || "", image: n.image || "",
      summary: n.summary || "", body: n.body || "", time: Date.now(), urgency: u,
      expire: n.expireTimeout > 0 ? n.expireTimeout : 0,
      actions: n.actions.filter(a => a.identifier !== "").map(a => ({ id: a.identifier, text: a.text })),
      read: false, live: true
    }
  }

  function receive(n) {
    n.tracked = true
    // Recarga de Quickshell: el servidor reentrega las notificaciones vivas de la generación anterior.
    // No son nuevas: se vuelven a enlazar con su entrada del historial (por id del servidor), sin popup.
    if (n.lastGeneration) {
      const old = list.find(e => e.sid === n.id && !e.live && e.summary === (n.summary || ""))
      if (old) {
        liveById[old.id] = n; serverIds[n.id] = old.id
        n.closed.connect(() => root.onServerClosed(old.id, n))
        mutate(old.id, e => { e.live = true; e.actions = n.actions.filter(a => a.identifier !== "").map(a => ({ id: a.identifier, text: a.text })) })
        return
      }
    }
    let id = serverIds[n.id]
    const replacing = id !== undefined && byId(id) !== null
    if (!replacing) id = nextId++
    serverIds[n.id] = id
    liveById[id] = n
    const e = toEntry(n, id)
    let l = list.filter(x => x.id !== id)
    l.unshift(e)
    while (l.length > maxHistory) { const old = l.pop(); forget(old.id, true) }
    list = l
    n.closed.connect(() => root.onServerClosed(id, n))
    if (!n.lastGeneration && (!dnd || e.urgency === "critical")) { hidePopup(id); showPopup(id) }
    save()
  }

  // El emisor cerró la notificación (CloseNotification o reemplazo): el popup se va, el historial queda
  function onServerClosed(id, n) {
    if (liveById[id] === n) { delete liveById[id]; mutate(id, e => { e.live = false }) }
    hidePopup(id)
  }
  function forget(id, dismissLive) {
    const n = liveById[id]
    delete liveById[id]
    for (const k of Object.keys(serverIds)) if (serverIds[k] === id) delete serverIds[k]
    if (n && dismissLive) n.dismiss()
  }

  function dismiss(id) {
    hidePopup(id)
    forget(id, true)
    list = list.filter(e => e.id !== id)
    save()
  }
  function clearAll() {
    popups.clear()
    for (const e of list) forget(e.id, true)
    list = []
    save()
  }
  function markAllRead() {
    if (unread === 0) return
    list = list.map(e => e.read ? e : Object.assign({}, e, { read: true }))
    save()
  }
  function markRead(id) { const e = byId(id); if (e && !e.read) mutate(id, x => { x.read = true }) }
  function invoke(id, actionId) {
    const n = liveById[id]
    if (n) {
      const a = n.actions.find(x => x.identifier === actionId)
      if (a) a.invoke()
    }
    hidePopup(id)
    // una acción resuelve la notificación (salvo las residentes, que Quickshell mantiene)
    dismiss(id)
  }
  function setDnd(on) { if (dnd === on) return; dnd = on; if (on) popups.clear(); save() }

  // ── persistencia ──
  readonly property string dir: Quickshell.env("HOME") + "/.local/state/ceft-shell"
  function save() { if (loaded) saveTimer.restart() }
  Timer {
    id: saveTimer
    interval: 500
    onTriggered: {
      const out = root.list.map(e => Object.assign({}, e, { live: false, image: e.image.startsWith("image://qsimage") ? "" : e.image }))
      store.setText(JSON.stringify({ dnd: root.dnd, list: out }))
    }
  }
  FileView {
    id: store
    path: ""            // se asigna tras crear el directorio (ver `prep`)
    printErrors: false
    onLoaded: {
      try {
        const v = JSON.parse(text())
        if (typeof v.dnd === "boolean" && !root.loaded) root.dnd = v.dnd
        if (Array.isArray(v.list)) {
          const old = v.list.filter(e => e && typeof e.id === "number" && typeof e.summary === "string").slice(0, root.maxHistory).map(e => ({
            id: e.id, sid: typeof e.sid === "number" ? e.sid : -1, appName: String(e.appName ?? ""), appIcon: String(e.appIcon ?? ""), image: String(e.image ?? ""),
            summary: e.summary, body: String(e.body ?? ""), time: Number(e.time) || 0, urgency: e.urgency ?? "normal",
            expire: 0, actions: [], read: e.read === true, live: false
          }))
          root.list = old
          root.nextId = old.reduce((m, e) => Math.max(m, e.id), 0) + 1
        }
      } catch (e) { console.warn("notifs.json inválido:", e) }
      root.loaded = true
      serverLoader.active = true
    }
    onLoadFailed: { root.loaded = true; serverLoader.active = true }
  }

  // ── servidor ──
  // 1) mkdir del estado + si dunst está vivo se le pide que salga  2) se carga el historial  3) recién entonces se registra el nombre
  Process {
    id: prep
    running: true
    command: ["sh", "-c", "mkdir -p \"$HOME/.local/state/ceft-shell\"; pkill -x dunst 2>/dev/null; for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do pgrep -x dunst >/dev/null || break; sleep 0.1; done; true"]
    onExited: store.path = root.dir + "/notifs.json"
  }
  Loader {
    id: serverLoader
    active: false
    sourceComponent: NotificationServer {
      keepOnReload: true
      actionsSupported: true
      actionIconsSupported: false
      bodySupported: true
      bodyMarkupSupported: true
      bodyHyperlinksSupported: true
      bodyImagesSupported: false
      imageSupported: true
      persistenceSupported: true
      inlineReplySupported: false
      onNotification: n => root.receive(n)
      Component.onCompleted: root.ready = true
    }
  }

  IpcHandler {
    target: "notifs"
    function toggleDnd(): void { root.setDnd(!root.dnd) }
    function setDnd(on: bool): void { root.setDnd(on) }
    function getDnd(): bool { return root.dnd }
    function clear(): void { root.clearAll() }
    function count(): int { return root.list.length }
    function unread(): int { return root.unread }
    function markRead(): void { root.markAllRead() }
    function invoke(id: int, action: string): void { root.invoke(id, action) }
    function dismiss(id: int): void { root.dismiss(id) }
    function latest(): int { return root.list.length ? root.list[0].id : -1 }
  }
}
