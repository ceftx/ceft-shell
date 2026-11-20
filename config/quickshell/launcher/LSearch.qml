import Quickshell
import Quickshell.Io
import QtQuick
import qs
import "Fuzzy.js" as Fuzzy
import "Calc.js" as Calc

// Lógica del launcher: índice de apps, búsqueda difusa, prefijos, uso persistente y ejecución.
//   (sin prefijo) apps · "=" calculadora · ">" comando · ":" acciones de ceft-shell · "$" historial del portapapeles · "." emojis (".g " glifos Nerd)
Item {
  id: s
  visible: false
  width: 0; height: 0

  property string query: ""
  function modeOf(q) { return q.startsWith("=") ? "calc" : q.startsWith(">") ? "cmd" : q.startsWith(":") ? "act" : q.startsWith("$") ? "clip" : q.startsWith(".") ? "emoji" : "apps" }
  function isGlyphQ(q) { return /^\.g(\s|$)/i.test(q) }
  readonly property bool glyphMode: mode === "emoji" && isGlyphQ(query)
  readonly property string mode: modeOf(query)
  property var results: []
  property string pending: ""          // acción esperando confirmación (apagar, reiniciar...)
  property var usage: ({})
  property var index: []
  property var themes: []
  signal closeRequested()

  readonly property string home: Quickshell.env("HOME")
  readonly property string cli: home + "/.local/bin/ceft-shell"
  readonly property string statePath: home + "/.local/state/ceft-shell/launcher.json"

  readonly property var baseActions: [
    { id: "wall-next",   title: "Wallpaper siguiente", sub: "Cambia el fondo y los colores", icon: "wallpaper", kw: "fondo wall papel next", cmd: cli + " wall next" },
    { id: "wall-random", title: "Wallpaper aleatorio", sub: "Elige uno al azar", icon: "shuffle", kw: "fondo wall random azar", cmd: cli + " wall random" },
    { id: "cc",          title: "Centro de control", sub: "Apariencia, escritorio, ventanas, atajos", icon: "tune", kw: "ajustes configuracion settings", cmd: "qs ipc call controlcenter open" },
    { id: "edit",        title: "Editar settings.lua", sub: "Abre tus preferencias en kitty", icon: "edit_document", kw: "config editar", cmd: "setsid -f kitty --title ceft-settings -e " + cli + " edit settings >/dev/null 2>&1" },
    { id: "lock",        title: "Bloquear", sub: "Bloquea la sesión", icon: "lock", kw: "lock pantalla", cmd: "if command -v hyprlock >/dev/null; then hyprlock; else loginctl lock-session; fi" },
    { id: "gamemode",    title: GameMode.on ? "Modo juego: desactivar" : "Modo juego", sub: GameMode.on ? "Vuelve a las animaciones, el blur y los avisos" : "Sin animaciones ni blur, no molestar activado", icon: "sports_esports", kw: "juego game gaming gamemode rendimiento fps", gamemode: true },
    { id: "reload",      title: "Recargar", sub: "Recarga Hyprland y reinicia la barra", icon: "refresh", kw: "reload reiniciar barra quickshell", cmd: cli + " reload" },
    { id: "suspend",     title: "Suspender", sub: "Pone el equipo a dormir", icon: "bedtime", kw: "dormir sleep", power: "suspend", confirm: true },
    { id: "logout",      title: "Cerrar sesión", sub: "Sale de Hyprland", icon: "logout", kw: "salir logout exit", power: "logout", confirm: true },
    { id: "reboot",      title: "Reiniciar el equipo", sub: "Reinicia el sistema", icon: "restart_alt", kw: "reboot", power: "reboot", confirm: true },
    { id: "poweroff",    title: "Apagar", sub: "Apaga el equipo", icon: "power_settings_new", kw: "shutdown poweroff", power: "poweroff", confirm: true }
  ]
  readonly property var clipActions: [
    { id: "clip-pause", title: clipPaused ? "Reanudar historial del portapapeles" : "Pausar historial del portapapeles", sub: clipPaused ? "Vuelve a guardar lo que copies" : "Deja de guardar lo que copies", icon: clipPaused ? "play_arrow" : "pause", kw: "clipboard portapapeles historial", cmd: clipCmdLine(["pause", "toggle"]) },
    { id: "clip-wipe", title: "Borrar historial del portapapeles", sub: "Elimina todo menos los fijados", icon: "delete_sweep", kw: "clipboard portapapeles historial vaciar limpiar", cmd: clipCmdLine(["wipe"]), confirm: true }
  ]
  readonly property var allActions: {
    const t = themes.map(n => ({ id: "theme-" + n, title: "Tema: " + n, sub: n === "wallpaper" ? "Colores sacados del fondo" : "Paleta fija", icon: "palette", kw: "tema theme colores " + n, cmd: cli + " theme " + n }))
    return baseActions.slice(0, 3).concat(t, clipActions, baseActions.slice(3))
  }

  property string prevMode: "apps"
  onQueryChanged: {
    pending = ""; wipePending = false
    const m = modeOf(query)
    if (m === "clip" && prevMode !== "clip") clipRefresh()
    prevMode = m
    recompute()
  }

  // ── índice de aplicaciones ──
  function rebuild() {
    const out = []
    for (const e of DesktopEntries.applications.values) {
      if (e.noDisplay) continue
      const cmd = (e.command ?? []).join(" ")
      out.push({
        e: e, id: e.id, name: e.name,
        n: Fuzzy.norm(e.name), g: Fuzzy.norm(e.genericName),
        k: Fuzzy.norm((e.keywords ?? []).join(" ")),
        c: Fuzzy.norm(cmd.split(" ")[0].split("/").pop() + " " + e.id),
        d: Fuzzy.norm(e.comment)
      })
    }
    index = out
    recompute()
  }
  Connections { target: DesktopEntries.applications; function onValuesChanged() { s.rebuild() } }
  Component.onCompleted: { rebuild(); refreshStatus(); Quickshell.execDetached(["mkdir", "-p", home + "/.local/state/ceft-shell"]); themeList.running = true }

  // ── uso persistente ──
  FileView {
    id: store
    path: s.statePath
    blockLoading: true
    printErrors: false
    onLoaded: { try { s.usage = JSON.parse(text()) } catch (e) { s.usage = ({}) } s.recompute() }
  }
  function bump(id) {
    const u = Object.assign({}, usage)
    u[id] = (u[id] ?? 0) + 1
    usage = u
    store.setText(JSON.stringify(u))
  }
  function useBonus(id) { return Math.min(80, Math.log2(1 + (usage[id] ?? 0)) * 22) }

  // ── lista de temas (una vez) ──
  Process {
    id: themeList
    command: [s.cli, "theme", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        const names = text.split("\n").map(l => l.replace(/^[\s*]+/, "").trim()).filter(l => l !== "")
        s.themes = names.concat(["wallpaper"])
        s.recompute()
      }
    }
  }


  // ── historial del portapapeles ──
  // Todo pasa por hypr/scripts/clip-store (privacidad, cliphist, pegado). clipEnv solo lo usan las pruebas.
  property var clipEnv: ({})
  property var clipItems: []            // { id, ts, text, n, isImage, meta }
  property var pins: []                 // { id, text, ts }
  property bool clipHave: true          // cliphist instalado
  property bool clipPaused: false
  property bool clipWatching: true
  property bool clipLoading: false
  property bool wipePending: false
  property string notice: ""
  property int holdIndex: -1
  property var thumbOk: ({})
  property var sel: null                // fila seleccionada (la pone Launcher)
  property string previewText: ""
  property string previewId: ""
  property double lastClipRefresh: 0
  readonly property string clipScript: home + "/.config/hypr/scripts/clip-store"
  readonly property string stateDir: clipEnv.CLIP_STATE_DIR ?? (home + "/.local/state/ceft-shell")
  readonly property string cacheDir: clipEnv.CLIP_CACHE_DIR ?? (home + "/.cache/ceft-shell/clip")
  function clipCmdLine(args) { return shq(clipScript) + " " + args.map(shq).join(" ") }
  function clipExec(args) { Quickshell.execDetached({ command: [clipScript].concat(args), environment: clipEnv }) }
  function say(t) { notice = t; noticeTimer.restart() }
  Timer { id: noticeTimer; interval: 2200; onTriggered: s.notice = "" }
  Timer { id: wipeTimer; interval: 3000; onTriggered: s.wipePending = false }

  FileView {
    id: pinStore
    path: s.stateDir + "/clip-pinned.json"
    blockLoading: true
    printErrors: false
    onLoaded: { try { s.pins = JSON.parse(text()).items ?? [] } catch (e) { s.pins = [] } s.recompute() }
  }
  function savePins(list) { pins = list; pinStore.setText(JSON.stringify({ items: list })); recompute() }

  function refreshStatus() { if (statusProc.running) return; statusProc.loadList = false; statusProc.running = true }
  function clipRefresh() {
    const now = Date.now()
    if (now - lastClipRefresh < 150) return
    lastClipRefresh = now
    clipLoading = true
    statusProc.loadList = true
    statusProc.running = true
  }
  Process {
    id: statusProc
    property bool loadList: false
    command: [s.clipScript, "status"]
    environment: s.clipEnv
    stdout: StdioCollector {
      onStreamFinished: {
        const m = {}
        for (const kv of text.trim().split(/\s+/)) { const p = kv.split("="); m[p[0]] = p[1] }
        s.clipHave = m.cliphist === "1"
        s.clipPaused = m.paused === "1"
        s.clipWatching = m.watching === "1"
        if (!statusProc.loadList) return
        if (!s.clipHave) { s.clipItems = []; s.clipLoading = false; s.recompute(); return }
        if (!s.clipWatching) s.clipExec(["watch"])   // instalaron cliphist con la sesion abierta: arrancar los vigilantes
        listProc.running = true
      }
    }
  }
  Process {
    id: listProc
    command: [s.clipScript, "list"]
    environment: s.clipEnv
    stdout: StdioCollector {
      onStreamFinished: {
        const out = []
        for (const line of text.split("\n")) {
          if (line === "") continue
          const a = line.split("\t")
          const pv = a.slice(2).join("\t")
          const bm = /^\[\[ binary data (.*) \]\]$/.exec(pv)
          let meta = ""
          if (bm) {
            const t = bm[1].split(" ")   // "12 KiB png 800x600"
            meta = (t.slice(2).join(" ") + " · " + t.slice(0, 2).join(" ")).replace(/^ · /, "")
          }
          out.push({ id: a[0], ts: Number(a[1]) || 0, text: bm ? "" : pv.trim(), n: bm ? "imagen " + meta.toLowerCase() : Fuzzy.norm(pv), isImage: !!bm, meta: meta })
        }
        s.clipItems = out
        s.clipLoading = false
        s.recompute()
        s.makeThumbs()
      }
    }
  }
  Process {
    id: thumbProc
    environment: s.clipEnv
    onExited: { const o = Object.assign({}, s.thumbOk); for (const id of thumbProc.ids) o[id] = true; s.thumbOk = o; s.recompute() }
    property var ids: []
  }
  function makeThumbs() {
    const ids = clipItems.filter(c => c.isImage && !thumbOk[c.id]).slice(0, 40).map(c => c.id)
    if (ids.length === 0) return
    thumbProc.ids = ids
    thumbProc.command = ["sh", "-c",
      'c="${CLIP_CACHE_DIR:-$HOME/.cache/ceft-shell/clip}"; mkdir -p "$c"; for id; do [ -s "$c/$id.png" ] || "${CLIPHIST:-cliphist}" decode "$id" >"$c/$id.png" 2>/dev/null; done', "sh"].concat(ids)
    thumbProc.running = true
  }

  // vista previa del elemento seleccionado (texto completo, recortado)
  onSelChanged: { previewText = ""; previewId = ""; previewTimer.restart() }
  Timer {
    id: previewTimer
    interval: 90
    onTriggered: {
      const r = s.sel
      if (!r || r.kind !== "clip") return
      if (r.pinned || r.isImage) { s.previewId = r.id; s.previewText = r.text ?? ""; return }
      prevProc.rid = r.id
      prevProc.command = ["sh", "-c", 'exec "${CLIPHIST:-cliphist}" decode "$1" | head -c 20000', "sh", r.cid]
      prevProc.running = true
    }
  }
  Process {
    id: prevProc
    property string rid: ""
    environment: s.clipEnv
    stdout: StdioCollector {
      onStreamFinished: { s.previewId = prevProc.rid; s.previewText = text }
    }
  }

  function ago(ts) {
    if (!ts) return ""
    const d = Math.max(0, Math.floor(Date.now() / 1000 - ts))
    if (d < 45) return "hace un momento"
    if (d < 3600) { const m = Math.max(1, Math.round(d / 60)); return "hace " + m + " min" }
    if (d < 86400) { const h = Math.round(d / 3600); return "hace " + h + (h === 1 ? " hora" : " h") }
    if (d < 172800) return "ayer"
    if (d < 86400 * 30) return "hace " + Math.floor(d / 86400) + " días"
    return Qt.formatDate(new Date(ts * 1000), "d MMM yyyy")
  }
  function oneLine(t) { return t.replace(/\s+/g, " ").trim() }

  function clipResults(q) {
    const tk = Fuzzy.norm(q.slice(1).trim()).split(/\s+/).filter(x => x !== "")
    if (!clipHave) return [{ kind: "hint", title: "Instalá cliphist para guardar el historial", sub: "sudo pacman -S cliphist   ·   después SUPER+V muestra todo lo que copies", icon: "download" }]
    const pinLines = {}
    const pr = pins.map(p => { const l = oneLine(p.text).slice(0, 400); pinLines[l] = true; return { cid: p.id, id: "p" + p.id, title: oneLine(p.text), text: p.text, sub: "Fijado" + (p.ts ? " · " + ago(p.ts) : "") + " · " + p.text.length + " caracteres", icon: "push_pin", pinned: true, n: Fuzzy.norm(p.text) } })
    const hist = clipItems.filter(c => c.isImage || !pinLines[oneLine(c.text).slice(0, 400)]).map(c => ({
      cid: c.id, id: "c" + c.id, isImage: c.isImage,
      title: c.isImage ? "Imagen" : c.text,
      sub: [ago(c.ts), c.isImage ? c.meta : (c.text.length >= 400 ? "400+ caracteres" : c.text.length + " caracteres")].filter(x => x !== "").join(" · "),
      icon: c.isImage ? "image" : "content_paste", thumb: c.isImage && thumbOk[c.id] ? "file://" + cacheDir + "/" + c.id + ".png" : "", n: c.n, ts: c.ts }))
    let all = pr.concat(hist).map(r => Object.assign({ kind: "clip" }, r))
    if (tk.length === 0) {
      if (all.length === 0) return [{ kind: "hint", title: clipPaused ? "El historial está en pausa" : "Todavía no copiaste nada", sub: clipPaused ? "Reanudalo con el botón de abajo para guardar lo que copies" : "Lo que copies aparece acá, lo más reciente primero", icon: clipPaused ? "pause_circle" : "content_paste_off" }]
      return all
    }
    const sc = []
    for (let i = 0; i < all.length; i++) {
      const v = Fuzzy.scoreText(tk, all[i].n)
      if (v > 0) sc.push({ r: all[i], v: v + (all[i].pinned ? 150 : 0), i: i })
    }
    sc.sort((a, b) => (b.v - a.v) || (a.i - b.i))
    if (sc.length === 0) return [{ kind: "hint", title: "Nada en el historial coincide", sub: "Probá con otra palabra de lo que copiaste", icon: "search_off" }]
    return sc.slice(0, 200).map(x => x.r)
  }

  function clipActivate(r, shift) {
    if (r.pinned) {
      if (shift) Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", r.text])
      else clipExec(["paste", "-text", r.text])
    } else clipExec([shift ? "copy" : "paste", r.cid])
    closeRequested()
    return true
  }
  function clipDelete(r, idx) {
    if (!r || r.kind !== "clip") return
    holdIndex = idx
    if (r.pinned) { savePins(pins.filter(p => "p" + p.id !== r.id)); say("Fijado quitado"); return }
    clipItems = clipItems.filter(c => c.id !== r.cid)
    clipExec(["delete", r.cid])
    recompute()
    say("Borrado del historial")
  }
  function clipPin(r, idx) {
    if (!r || r.kind !== "clip") return
    holdIndex = idx
    if (r.pinned) { savePins(pins.filter(p => "p" + p.id !== r.id)); say("Desfijado"); return }
    if (r.isImage) { say("Las imágenes no se pueden fijar"); return }
    pinGrab.rid = r.cid
    pinGrab.command = ["sh", "-c", 'exec "${CLIPHIST:-cliphist}" decode "$1" | head -c 20000', "sh", r.cid]
    pinGrab.running = true
  }
  Process {
    id: pinGrab
    property string rid: ""
    environment: s.clipEnv
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() === "") return
        s.savePins([{ id: Date.now().toString(36), text: text, ts: Math.floor(Date.now() / 1000) }].concat(s.pins))
        s.say("Fijado arriba")
      }
    }
  }
  function clipTogglePause() {
    clipPaused = !clipPaused
    clipExec(["pause", clipPaused ? "on" : "off"])
    say(clipPaused ? "Historial en pausa" : "Historial reanudado")
    recompute()
  }
  function clipWipeClick() {
    if (!wipePending) { wipePending = true; wipeTimer.restart(); return }
    wipePending = false
    clipExec(["wipe"])
    clipItems = []
    recompute()
    say("Historial borrado (los fijados se conservan)")
  }

  // ── emojis y glifos ──
  // Datos locales y versionados: data/emoji.json (Unicode emoji-test + CLDR es/en) y data/glyphs.json (Nerd Fonts glyphnames).
  // Se generan con data/gen-data.py. Estado: ~/.local/state/ceft-shell/emoji-recent.json { recent, glyphs, tone }.
  property var emojiIdx: []
  property var glyphIdx: []
  property var recentEmoji: []
  property var recentGlyph: []
  property int tone: 0                  // 0 = amarillo, 1..5 = claro..oscuro
  property bool emojiReady: false
  property bool glyphReady: false
  readonly property string dataDir: Qt.resolvedUrl("data").toString().replace("file://", "")
  readonly property string recentPath: home + "/.local/state/ceft-shell/emoji-recent.json"
  readonly property var toneNames: ["Sin tono", "Tono claro", "Tono medio claro", "Tono medio", "Tono medio oscuro", "Tono oscuro"]

  FileView {
    id: emojiFile
    path: s.dataDir + "/emoji.json"
    blockLoading: true
    printErrors: false
    onLoaded: {
      try {
        s.emojiIdx = JSON.parse(text()).map(a => ({ kind: "emoji", id: a[0], base: a[0], tones: a[5] ?? null, title: a[1], sub: a[2], kw: a[3].split("|").join(" "), group: a[4],
          n: Fuzzy.norm(a[1]), e: Fuzzy.norm(a[2]), k: Fuzzy.norm(a[3].split("|").join(" ")) }))
        s.emojiReady = true
      } catch (e) { s.emojiIdx = [] }
      s.recompute()
    }
  }
  FileView {
    id: glyphFile
    path: s.dataDir + "/glyphs.json"
    blockLoading: true
    printErrors: false
    onLoaded: {
      try {
        s.glyphIdx = JSON.parse(text()).map(a => {
          const set = a[0].split("-")[0]
          const nm = a[0].slice(set.length + 1).replace(/_/g, " ")
          return { kind: "emoji", glyph: true, id: a[1], base: a[1], tones: null, title: nm, sub: "nf-" + a[0], group: set, kw: "", n: Fuzzy.norm(nm), e: Fuzzy.norm(set + " " + a[0].replace(/[-_]/g, " ")), k: "" }
        })
        s.glyphReady = true
      } catch (e) { s.glyphIdx = [] }
      s.recompute()
    }
  }
  FileView {
    id: recentFile
    path: s.recentPath
    blockLoading: true
    printErrors: false
    onLoaded: {
      try { const j = JSON.parse(text()); s.recentEmoji = j.recent ?? []; s.recentGlyph = j.glyphs ?? []; s.tone = Math.max(0, Math.min(5, j.tone ?? 0)) } catch (e) {}
      s.recompute()
    }
  }
  function saveEmojiState() { recentFile.setText(JSON.stringify({ recent: recentEmoji, glyphs: recentGlyph, tone: tone })) }
  function emojiLoad() {
    if (!emojiReady) emojiFile.reload()
    if (glyphMode && !glyphReady) glyphFile.reload()
  }
  function setTone(t) { tone = t; saveEmojiState(); say(toneNames[t]); recompute() }
  function cycleTone() { setTone((tone + 1) % 6) }
  function shown(it) { return tone > 0 && it.tones ? it.tones[tone - 1] : it.base }
  function emojiRow(it) { return Object.assign({}, it, { char: shown(it), id: it.base }) }

  function emojiResults(q) {
    emojiLoad()
    const gl = isGlyphQ(q)
    const idx = gl ? glyphIdx : emojiIdx
    const rec = gl ? recentGlyph : recentEmoji
    if (!(gl ? glyphReady : emojiReady)) return []
    const qn = Fuzzy.norm(q.slice(gl ? 2 : 1).trim())
    const byId = {}
    const out = []
    if (qn === "") {
      for (const c of rec) { const it = idx.find(x => x.base === c); if (it) { out.push(emojiRow(it)); byId[c] = true } }
      const lim = gl ? 600 : idx.length
      for (let i = 0; i < idx.length && out.length < lim; i++) if (!byId[idx[i].base]) out.push(emojiRow(idx[i]))
      return out
    }
    const tk = qn.split(/\s+/)
    const sc = []
    for (let i = 0; i < idx.length; i++) {
      const it = idx[i]
      let tot = 0
      for (let j = 0; j < tk.length; j++) {
        const t = tk[j]
        const b = Math.max(Fuzzy.field(t, it.n, !gl), Fuzzy.field(t, it.e, false) * 0.9, it.k === "" ? 0 : Fuzzy.field(t, it.k, false) * 0.55)
        if (b <= 0) { tot = 0; break }
        tot += b
      }
      if (tot > 0) {
        const ri = rec.indexOf(it.base)
        sc.push({ it: it, v: tot + (ri >= 0 ? 160 - ri * 4 : 0), i: i })
      }
    }
    sc.sort((a, b) => (b.v - a.v) || (a.i - b.i))
    return sc.slice(0, 600).map(x => emojiRow(x.it))
  }
  function emojiActivate(r, shift) {
    const isG = !!r.glyph
    const key = isG ? "recentGlyph" : "recentEmoji"
    s[key] = [r.base].concat(s[key].filter(c => c !== r.base)).slice(0, 40)
    saveEmojiState()
    if (shift) Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", r.char ?? r.base])
    else clipExec(["paste", "-text", r.char ?? r.base])
    closeRequested()
    return true
  }

  // ── resultados ──
  function appResult(it) {
    const e = it.e
    return { kind: "app", id: e.id, title: e.name, sub: e.genericName || e.comment || "", icon: e.icon, entry: e }
  }

  function recompute() {
    const q = query
    const m = modeOf(q)   // no usar `mode`: aún no se reevaluó cuando salta onQueryChanged
    let list = []
    if (m === "calc") {
      const src = q.slice(1).trim()
      const v = src === "" ? null : Calc.evaluate(src)
      if (src === "") list = [{ kind: "hint", title: "Calculadora", sub: "Escribí una cuenta: 2*(3+4), sqrt(81), 15%, usá pi, e, sin, ln", icon: "calculate" }]
      else if (v === null) list = [{ kind: "hint", title: "Esa cuenta todavía no cierra", sub: src, icon: "calculate", warn: true }]
      else list = [{ kind: "calc", title: Calc.format(v), expr: src, sub: "Enter copia el resultado", icon: "calculate", value: Calc.format(v) }]
    } else if (m === "cmd") {
      const c = q.slice(1).trim()
      if (c === "") list = [{ kind: "hint", title: "Comando de shell", sub: "Enter lo abre en la terminal · Shift+Enter lo ejecuta en segundo plano", icon: "terminal" }]
      else list = [{ kind: "cmd", title: c, sub: "Enter abre en la terminal · Shift+Enter en segundo plano", icon: "terminal", cmd: c }]
    } else if (m === "clip") {
      list = clipResults(q)
    } else if (m === "emoji") {
      list = emojiResults(q)
    } else if (m === "act") {
      const qn = Fuzzy.norm(q.slice(1).trim())
      if (qn === "") list = allActions.map(a => Object.assign({ kind: "action" }, a))
      else {
        const tk = qn.split(/\s+/)
        list = allActions.map(a => ({ a: a, sc: Fuzzy.scoreText(tk, Fuzzy.norm(a.title)) + Fuzzy.scoreText(tk, Fuzzy.norm(a.kw)) * 0.5 }))
          .filter(x => x.sc > 0).sort((x, y) => y.sc - x.sc).map(x => Object.assign({ kind: "action" }, x.a))
      }
    } else {
      const qn = Fuzzy.norm(q.trim())
      if (qn === "") {
        list = index.slice().sort((a, b) => ((usage[b.id] ?? 0) - (usage[a.id] ?? 0)) || a.n.localeCompare(b.n)).slice(0, 40).map(appResult)
      } else {
        const tk = qn.split(/\s+/)
        const sc = []
        for (const it of index) {
          const v = Fuzzy.scoreApp(tk, it)
          if (v > 0) sc.push({ it: it, v: v + useBonus(it.id) })
        }
        sc.sort((a, b) => (b.v - a.v) || a.it.n.localeCompare(b.it.n))
        list = sc.slice(0, 30).map(x => appResult(x.it))
        if (Calc.looksLikeMath(q)) {
          const v = Calc.evaluate(q)
          if (v !== null) list.unshift({ kind: "calc", title: Calc.format(v), expr: q.trim(), sub: "Enter copia el resultado", icon: "calculate", value: Calc.format(v) })
        }
      }
    }
    results = list
  }

  // ── ejecución ──
  function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
  function shq(x) { return "'" + String(x).replace(/'/g, "'\\''") + "'" }

  // true si se ejecutó (y se pidió cerrar)
  function activate(r, shift) {
    if (!r) return false
    switch (r.kind) {
    case "app":
      bump(r.id)
      if (r.entry.runInTerminal) Quickshell.execDetached([Theme.terminal, "-e"].concat(r.entry.command))
      else r.entry.execute()
      closeRequested(); return true
    case "clip":
      return clipActivate(r, shift)
    case "emoji":
      return emojiActivate(r, shift)
    case "calc":
      Quickshell.execDetached(["wl-copy", r.value]); closeRequested(); return true
    case "cmd":
      // Enter: terminal con el comando (queda abierta e interactiva) · Shift+Enter: en segundo plano
      // Shell de la cuenta (getent), no $SHELL: la sesión puede heredar /bin/bash.
      // fish -C: corre el comando y deja la terminal interactiva (con tus funciones de fish).
      if (!shift) Quickshell.execDetached(["sh", "-c",
        's=$(getent passwd "$(id -un)" | cut -d: -f7); s=${s:-/bin/sh}; ' +
        'case "$s" in *fish) exec "$0" "$s" -C "$1" ;; *) exec "$0" --hold "$s" -c "$1" ;; esac',
        Theme.terminal, r.cmd])
      else sh("setsid -f sh -c " + shq(r.cmd) + " >/dev/null 2>&1")
      closeRequested(); return true
    case "action":
      if (r.confirm && pending !== r.id) { pending = r.id; return false }
      pending = ""
      if (r.power) PowerGuard.request(r.power)
      else if (r.gamemode) GameMode.toggle()
      else sh(r.cmd)
      closeRequested(); return true
    }
    return false
  }
}
