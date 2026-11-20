pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Estado persistente del Centro de control.
//   defaults  = settings.lua (se parsea el archivo real, así nunca se desincroniza)
//   over      = ~/.config/ceft-shell/overrides.json (solo las claves que el usuario cambió)
//   w         = ~/.config/ceft-shell/widgets.json
// Cada cambio escribe el JSON de forma atómica (FileView.setText) y, para overrides, corre `hyprctl reload`.
Singleton {
  id: root
  readonly property string home: Quickshell.env("HOME")
  readonly property string cli: home + "/.local/bin/ceft-shell"
  readonly property string cfgDir: home + "/.config/ceft-shell"

  property var defaults: ({})
  property var over: ({})
  property var w: ({})
  property string toast: ""
  property bool toastErr: false
  property int toastSeq: 0

  // ── settings.lua → defaults ──
  function parseLua(text) {
    const out = {}
    let block = null
    for (const raw of text.split("\n")) {
      const line = raw.replace(/\s--.*$/, "").replace(/^\s*--.*$/, "").trim()
      if (line === "") continue
      let m
      if ((m = line.match(/^(\w+)\s*=\s*\{\s*$/))) { block = m[1]; out[block] = out[block] ?? ({}); continue }
      if (/^\},?$/.test(line)) { block = null; continue }
      // tabla en una línea con pares clave = valor: { preserve_split = true, force_split = 0 }
      if ((m = line.match(/^(\w+)\s*=\s*\{(.*\w\s*=.*)\},?$/)) && !/^\s*"/.test(m[2])) {
        const obj = {}
        const pr = /(\w+)\s*=\s*("[^"]*"|[^,\s}]+)/g
        let kv
        while ((kv = pr.exec(m[2])) !== null) {
          let v = kv[2]
          if (v === "true") v = true
          else if (v === "false") v = false
          else if (/^-?[\d.]+$/.test(v)) v = Number(v)
          else if (/^".*"$/.test(v)) v = v.slice(1, -1)
          obj[kv[1]] = v
        }
        if (block) out[block][m[1]] = obj; else out[m[1]] = obj
        continue
      }
      if ((m = line.match(/^(\w+)\s*=\s*\{(.*)\},?$/))) {
        const items = []
        const re = /"([^"]*)"/g
        let s
        while ((s = re.exec(m[2])) !== null) items.push(s[1])
        if (block) out[block][m[1]] = items; else out[m[1]] = items
        continue
      }
      if ((m = line.match(/^(\w+)\s*=\s*(.+?),?$/))) {
        let v = m[2].trim()
        if (v === "true") v = true
        else if (v === "false") v = false
        else if (/^-?[\d.]+$/.test(v)) v = Number(v)
        else if (/^".*"$/.test(v)) v = v.slice(1, -1)
        if (block) out[block][m[1]] = v; else out[m[1]] = v
      }
    }
    return out
  }

  FileView {
    path: root.home + "/.config/hypr/settings.lua"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.defaults = root.parseLua(text())
  }

  FileView {
    id: overFile
    path: root.cfgDir + "/overrides.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { const o = JSON.parse(text()); root.over = (o && typeof o === "object") ? o : ({}) }
      catch (e) { console.warn("overrides.json inválido:", e) }
    }
    onLoadFailed: root.over = ({})
  }

  FileView {
    id: widFile
    path: root.cfgDir + "/widgets.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.w = JSON.parse(text()) } catch (e) { console.warn("widgets.json inválido:", e) }
    }
  }

  // ── acceso por ruta "look.gaps_in" ──
  function getIn(obj, path) {
    let cur = obj
    for (const k of path.split(".")) { if (cur === undefined || cur === null) return undefined; cur = cur[k] }
    return cur
  }
  function def(path) { return getIn(defaults, path) }
  function eff(path) { const o = getIn(over, path); return o !== undefined ? o : getIn(defaults, path) }
  function isSet(path) { return getIn(over, path) !== undefined }
  function anySet(paths) { return paths.some(p => isSet(p)) }

  function prune(o) {
    for (const k of Object.keys(o)) {
      const v = o[k]
      if (v && typeof v === "object" && !Array.isArray(v)) { prune(v); if (Object.keys(v).length === 0) delete o[k] }
    }
  }
  function setPath(o, path, v) {
    const ks = path.split(".")
    let cur = o
    for (let i = 0; i < ks.length - 1; i++) {
      if (typeof cur[ks[i]] !== "object" || cur[ks[i]] === null) cur[ks[i]] = ({})
      cur = cur[ks[i]]
    }
    const last = ks[ks.length - 1]
    if (v === undefined) delete cur[last]; else cur[last] = v
  }

  // Cambia un valor; si coincide con settings.lua se quita (solo se guardan las diferencias).
  function setOver(path, value) {
    const copy = JSON.parse(JSON.stringify(over))
    const same = JSON.stringify(value) === JSON.stringify(getIn(defaults, path))
    setPath(copy, path, same ? undefined : value)
    commitOver(copy)
  }
  function resetOver(paths) {
    const copy = JSON.parse(JSON.stringify(over))
    for (const p of paths) setPath(copy, p, undefined)
    commitOver(copy)
  }
  // Atajos: ids con puntos, por eso van aparte de setOver (que parte la ruta por ".").
  function bindOf(id) { const b = over.binds; return b && (id in b) ? b[id] : undefined }
  function setBind(id, value, defKeys) {
    const copy = JSON.parse(JSON.stringify(over))
    const b = copy.binds ?? ({})
    if (value === defKeys) delete b[id]; else b[id] = value
    if (Object.keys(b).length === 0) delete copy.binds; else copy.binds = b
    commitOver(copy)
  }
  function commitOver(copy) {
    prune(copy)
    over = copy
    if (Object.keys(copy).length === 0) rmProc.running = true
    else overFile.setText(JSON.stringify(copy, null, 2) + "\n")
    reloadTimer.restart()
  }

  Timer { id: reloadTimer; interval: 350; onTriggered: { reloadProc.running = true } }
  Process { id: rmProc; command: ["rm", "-f", root.cfgDir + "/overrides.json"] }
  Process {
    id: reloadProc
    command: ["hyprctl", "reload"]
    onExited: (code) => root.notify(code === 0 ? "Aplicado · Hyprland recargado" : "hyprctl reload falló (código " + code + ")", code !== 0)
  }

  // ── widgets.json ──
  function setWidgets(mutator) {
    const copy = JSON.parse(JSON.stringify(w))
    mutator(copy)
    w = copy
    widFile.setText(JSON.stringify(copy, null, 2) + "\n")
    notify("Guardado en widgets.json", false)
  }

  // Avatar del perfil (solo se carga si el archivo existe: evita warnings de Image)
  readonly property string avatarPath: ((w.profile?.avatar ?? "") !== "" ? String(w.profile.avatar).replace(/^~/, home) : home + "/.face")
  property bool avatarOk: false
  property int avatarRev: 0          // sube al cambiar ~/.face (rompe la caché de Image)
  onAvatarPathChanged: avatarCheck.running = true
  Process {
    id: avatarCheck
    command: ["test", "-f", root.avatarPath]
    running: true
    onExited: (code) => root.avatarOk = code === 0
  }

  function notify(msg, err) { toast = msg; toastErr = err; toastSeq++ }
}
