import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.desktop

Item {
  id: page

  readonly property string mod: String(CCStore.def("mod") ?? "SUPER")
  property var entries: []          // [{ id, cat, desc, def, editable }]
  property string filter: ""
  property string editingId: ""
  property string captured: ""
  property string conflictId: ""
  property string captureError: ""

  readonly property var descs: ({
    "focus.left": "Foco a la izquierda", "focus.down": "Foco abajo", "focus.up": "Foco arriba", "focus.right": "Foco a la derecha",
    "focus.left.arrow": "Foco a la izquierda (flecha)", "focus.right.arrow": "Foco a la derecha (flecha)",
    "focus.up.arrow": "Foco arriba (flecha)", "focus.down.arrow": "Foco abajo (flecha)",
    "layout.grow": "Agrandar la ventana principal", "layout.shrink": "Achicar la ventana principal",
    "layout.swap.next": "Intercambiar con la siguiente", "layout.swap.prev": "Intercambiar con la anterior",
    "layout.next": "Siguiente layout", "layout.prev": "Layout anterior",
    "window.float": "Flotante / mosaico", "window.close": "Cerrar ventana", "window.fullscreen": "Pantalla completa",
    "monitor.next": "Siguiente monitor", "monitor.prev": "Monitor anterior",
    "session.reload": "Recargar el entorno", "session.exit": "Salir de Hyprland",
    "apps.launcher": "Lanzador de apps", "apps.runner": "Ejecutar comando", "apps.browser": "Navegador",
    "apps.files": "Archivos", "apps.terminal": "Terminal", "apps.controlcenter": "Centro de control",
    "nightlight.on": "Luz nocturna: activar", "nightlight.off": "Luz nocturna: apagar",
    "wall.next": "Siguiente wallpaper", "wall.random": "Wallpaper aleatorio",
    "shot.region.edit": "Captura de región y editar", "shot.region.copy": "Captura de región al portapapeles",
    "shot.output.copy": "Captura de pantalla completa", "rec.region": "Grabar región",
    "rec.region.audio": "Grabar región con audio", "rec.output": "Grabar pantalla", "colorpicker": "Selector de color",
    "shot.qtile.output": "Captura de pantalla (estilo qtile)", "shot.qtile.region": "Captura de región (estilo qtile)",
    "scratch.toggle": "Mostrar / ocultar scratchpad", "scratch.move": "Mover ventana al scratchpad",
    "mouse.ws.next": "Siguiente grupo (rueda)", "mouse.ws.prev": "Grupo anterior (rueda)",
    "mouse.drag": "Mover ventana con el ratón", "mouse.resize": "Redimensionar con el ratón",
    "media.vol.up": "Subir volumen", "media.vol.down": "Bajar volumen", "media.mute": "Silenciar", "media.micmute": "Silenciar micrófono",
    "media.bright.up": "Más brillo", "media.bright.down": "Menos brillo",
    "clipboard.history": "Historial del portapapeles", "clipboard.copy": "Copiar (portapapeles)", "clipboard.cut": "Cortar (portapapeles)",
    "gamemode.toggle": "Modo juego: activar / desactivar", "dropterm.toggle": "Terminal desplegable",
    "media.next": "Pista siguiente", "media.pause": "Pausa", "media.play": "Reproducir / pausa", "media.prev": "Pista anterior"
  })
  function catOf(id) {
    const p = id.split(".")[0]
    return ({ focus: "Foco", layout: "Layouts", window: "Ventanas", monitor: "Monitores", session: "Sesión", apps: "Aplicaciones",
              nightlight: "Aplicaciones", wall: "Wallpaper", shot: "Capturas y grabación", rec: "Capturas y grabación", colorpicker: "Capturas y grabación",
              scratch: "Scratchpad", mouse: "Ratón", media: "Multimedia", ws: "Grupos de trabajo (1-9)",
              clipboard: "Portapapeles", gamemode: "Modo juego", dropterm: "Aplicaciones" })[p] ?? "Otros"
  }
  function descOf(id) {
    let m = id.match(/^ws\.focus\.(\d)$/); if (m) return "Ir al grupo " + m[1]
    m = id.match(/^ws\.move\.(\d)$/); if (m) return "Mover ventana al grupo " + m[1]
    if (descs[id] !== undefined) return descs[id]
    // id nuevo sin traducción: "foo.bar_baz" -> "Foo: bar baz" (legible, se actualiza solo al aparecer atajos nuevos)
    const parts = id.split(".").map(x => x.replace(/[_-]/g, " "))
    const head = parts[0].charAt(0).toUpperCase() + parts[0].slice(1)
    return parts.length > 1 ? head + ": " + parts.slice(1).join(" ") : head
  }

  CCRun {
    id: listRun
    onFinished: (c, out) => {
      const list = []
      for (const line of out.split("\n")) {
        const m = line.match(/^([a-z0-9.]+)\s+(.+?)\s*$/)
        if (!m) continue
        list.push({ id: m[1], def: m[2] })
      }
      for (let i = 1; i <= 9; i++) {
        list.push({ id: "ws.focus." + i, def: "$mod + " + i })
        list.push({ id: "ws.move." + i, def: "$mod + SHIFT + " + i })
      }
      page.entries = list.map(e => ({ id: e.id, def: e.def, cat: page.catOf(e.id), desc: page.descOf(e.id), editable: e.def.indexOf("mouse:") < 0 && e.def.indexOf("mouse_") < 0 }))
    }
  }
  Component.onCompleted: listRun.run(CCStore.cli + " binds")

  function effKeys(e) { const o = CCStore.bindOf(e.id); return o === undefined ? e.def : o }
  function norm(keys) {
    if (keys === false || keys === "") return ""
    const toks = String(keys).split("+").map(s => s.trim().replace("$mod", mod).toUpperCase())
    const mods = toks.filter(t => ["SUPER", "SHIFT", "CTRL", "ALT"].indexOf(t) >= 0).sort()
    const key = toks.filter(t => ["SUPER", "SHIFT", "CTRL", "ALT"].indexOf(t) < 0)
    return mods.concat(key).join("+")
  }
  function findConflict(id, keys) {
    const n = norm(keys)
    if (n === "") return null
    return entries.find(e => e.id !== id && norm(effKeys(e)) === n) ?? null
  }

  readonly property var shown: {
    const q = filter.trim().toLowerCase()
    if (q === "") return entries
    return entries.filter(e => e.desc.toLowerCase().includes(q) || e.id.toLowerCase().includes(q) || e.cat.toLowerCase().includes(q)
                               || String(effKeys(e)).toLowerCase().includes(q))
  }

  // ── captura de teclas ──
  CCRun { id: submapRun }
  Timer { id: captureTimeout; interval: 25000; onTriggered: page.cancelEdit() }
  function startEdit(id) {
    cancelEdit()
    editingId = id; captured = ""; conflictId = ""; captureError = ""
    // Sin atajos activos mientras se captura (si no, SUPER+W cerraría una ventana en vez de registrarse)
    submapRun.run("hyprctl dispatch 'hl.dsp.submap(\"cc-capture\")'")
    captureTimeout.restart()
  }
  function cancelEdit() {
    if (editingId === "") return
    editingId = ""; captured = ""; conflictId = ""; captureError = ""
    captureTimeout.stop()
    resetSubmap.run("hyprctl dispatch 'hl.dsp.submap(\"reset\")'")
  }
  CCRun { id: resetSubmap }
  function commit(e, keys) {
    CCStore.setBind(e.id, keys, e.def)
    cancelEdit()
  }
  Connections {
    target: CCState
    function onOpenChanged() { if (!CCState.open) page.cancelEdit() }
  }

  function keyName(k, text) {
    if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
    if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
    if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1)
    const shifted = "!@#$%^&*()"
    if (text && text.length === 1 && shifted.indexOf(text) >= 0) return String((shifted.indexOf(text) + 1) % 10)
    const m = {}
    m[Qt.Key_Return] = "Return"; m[Qt.Key_Enter] = "Return"; m[Qt.Key_Tab] = "Tab"; m[Qt.Key_Backtab] = "Tab"
    m[Qt.Key_Space] = "space"; m[Qt.Key_QuoteLeft] = "grave"; m[Qt.Key_AsciiTilde] = "grave"
    m[Qt.Key_Comma] = "comma"; m[Qt.Key_Period] = "period"; m[Qt.Key_Minus] = "minus"; m[Qt.Key_Equal] = "equal"
    m[Qt.Key_Slash] = "slash"; m[Qt.Key_Backslash] = "backslash"; m[Qt.Key_Semicolon] = "semicolon"
    m[Qt.Key_Apostrophe] = "apostrophe"; m[Qt.Key_BracketLeft] = "bracketleft"; m[Qt.Key_BracketRight] = "bracketright"
    m[Qt.Key_Left] = "left"; m[Qt.Key_Right] = "right"; m[Qt.Key_Up] = "up"; m[Qt.Key_Down] = "down"
    m[Qt.Key_Print] = "Print"; m[Qt.Key_Backspace] = "BackSpace"; m[Qt.Key_Delete] = "Delete"
    m[Qt.Key_Home] = "Home"; m[Qt.Key_End] = "End"; m[Qt.Key_PageUp] = "Prior"; m[Qt.Key_PageDown] = "Next"
    m[Qt.Key_Insert] = "Insert"; m[Qt.Key_Pause] = "Pause"
    return m[k] ?? ""
  }
  function captureKey(event, e) {
    if (event.key === Qt.Key_Escape) { cancelEdit(); event.accepted = true; return }
    if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr].indexOf(event.key) >= 0) { event.accepted = true; return }
    const name = keyName(event.key, event.text)
    event.accepted = true
    if (name === "") { captureError = "Esa tecla no se puede usar acá. Podés escribirla en settings.lua."; return }
    const mods = []
    if (event.modifiers & Qt.MetaModifier) mods.push("$mod")
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
    if (event.modifiers & Qt.AltModifier) mods.push("ALT")
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")
    const typing = /^[A-Z0-9]$/.test(name) || name === "space" || name === "Return" || name === "BackSpace" || name === "Tab"
    if (mods.length === 0 && typing) { captureError = "Sumá un modificador (Super, Ctrl, Alt o Shift)."; return }
    captureError = ""
    // "$mod" solo cuando la tecla Super es la principal configurada
    const keys = mods.concat([name]).join(" + ")
    captured = keys
    const c = findConflict(e.id, keys)
    conflictId = c ? c.id : ""
    if (!c) commit(e, keys)
  }

  // ── UI ──
  ColumnLayout {
    anchors.fill: parent
    spacing: 14

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 3
      Text {
        text: "Atajos"
        color: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: 28
        font.weight: Font.DemiBold
        font.letterSpacing: -0.4
      }
      Text {
        text: "Cambiá una combinación o desactivala · se aplica al instante"
        color: DeskTheme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: 13
      }
    }
    RowLayout {
      Layout.fillWidth: true
      Layout.rightMargin: 22
      spacing: 10
      CCField {
        id: search
        Layout.fillWidth: true
        icon: "search"
        placeholder: "Buscar por acción, tecla o categoría…"
        onEdited: page.filter = text
      }
      Text {
        text: page.shown.length + " de " + page.entries.length
        color: DeskTheme.textFaint
        font.family: Theme.fontSans
        font.pixelSize: 12
      }
      CCButton {
        compact: true; icon: "restart_alt"; label: "Restablecer todos"
        visible: Object.keys(CCStore.over.binds ?? ({})).length > 0
        onClicked: { page.cancelEdit(); CCStore.resetOver(["binds"]) }
      }
    }

    ListView {
      id: list
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      model: page.shown
      boundsBehavior: Flickable.StopAtBounds
      cacheBuffer: 600
      rightMargin: 22
      ScrollBar.vertical: ScrollBar {
        id: sb
        policy: ScrollBar.AsNeeded
        width: 8
        contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Qt.alpha(Theme.foreground, sb.pressed ? 0.45 : 0.25) }
        background: Item {}
      }
      section.property: "cat"
      section.criteria: ViewSection.FullString
      section.delegate: Item {
        required property string section
        width: list.width - 22
        height: 44
        Text {
          anchors { left: parent.left; leftMargin: 4; bottom: parent.bottom; bottomMargin: 6 }
          text: section
          color: Theme.accent
          font.family: Theme.fontSans
          font.pixelSize: 13
          font.weight: Font.DemiBold
          font.letterSpacing: 0.3
        }
      }

      delegate: Rectangle {
        id: row
        required property var modelData
        required property int index
        readonly property var e: modelData
        readonly property var cur: page.effKeys(e)
        readonly property bool disabled: cur === false
        readonly property bool custom: CCStore.bindOf(e.id) !== undefined
        readonly property bool editing: page.editingId === e.id

        width: list.width - 22
        height: editing ? 52 + panel.height + 8 : 52
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        radius: 14
        clip: true
        color: editing ? Qt.alpha(Theme.accent, 0.10) : (rowMa.containsMouse ? Qt.alpha(Theme.foreground, 0.05) : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

        Item {
          id: top
          anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14 }
          height: 52

          CCSwitch {
            id: sw
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            checked: !row.disabled
            onToggled: v => { page.cancelEdit(); CCStore.setBind(row.e.id, v ? row.e.def : false, row.e.def) }
          }
          Row {
            id: actions
            anchors { right: sw.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
            CCButton {
              compact: true
              icon: "undo"
              visible: row.custom && !row.disabled && !row.editing
              onClicked: CCStore.setBind(row.e.id, row.e.def, row.e.def)
            }
            CCButton {
              compact: true
              icon: row.editing ? "close" : "edit"
              label: row.editing ? "Cancelar" : "Cambiar"
              visible: row.e.editable && !row.disabled
              onClicked: row.editing ? page.cancelEdit() : page.startEdit(row.e.id)
            }
          }
          KeyCaps {
            id: caps
            visible: !row.disabled
            keys: String(row.cur)
            mod: page.mod
            anchors { right: actions.left; rightMargin: 18; verticalCenter: parent.verticalCenter }
          }
          Text {
            visible: row.disabled
            text: "Desactivado"
            anchors { right: actions.left; rightMargin: 18; verticalCenter: parent.verticalCenter }
            color: DeskTheme.textFaint
            font.family: Theme.fontSans
            font.pixelSize: 13
          }
          Column {
            anchors { left: parent.left; right: caps.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 0
            Row {
              spacing: 8
              Text {
                text: row.e.desc
                color: row.disabled ? DeskTheme.textFaint : Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 14
                font.weight: Font.Medium
                font.strikeout: row.disabled
              }
              Rectangle { visible: row.custom; width: 7; height: 7; radius: 4; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
              text: row.e.id
              color: DeskTheme.textFaint
              font.family: Theme.font
              font.pixelSize: 11
            }
          }
        }

        // panel de captura
        Item {
          id: panel
          visible: row.editing
          anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 52; leftMargin: 14; rightMargin: 14 }
          height: capCol.implicitHeight
          focus: row.editing
          onVisibleChanged: if (visible) forceActiveFocus()
          Keys.onPressed: event => page.captureKey(event, row.e)

          ColumnLayout {
            id: capCol
            width: parent.width
            spacing: 8
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 52
              radius: 12
              color: Qt.alpha(Theme.background, 0.5)
              border.width: 1
              border.color: page.conflictId !== "" ? Theme.yellow : Qt.alpha(Theme.accent, 0.6)
              RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 12
                Icon {
                  name: "keyboard"
                  font.pixelSize: 22
                  color: Theme.accent
                  SequentialAnimation on opacity {
                    running: row.editing && page.captured === ""
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                  }
                }
                Text {
                  visible: page.captured === ""
                  text: "Presioná la nueva combinación…   (Esc cancela)"
                  color: DeskTheme.textMuted
                  font.family: Theme.fontSans
                  font.pixelSize: 13
                  Layout.fillWidth: true
                }
                KeyCaps { visible: page.captured !== ""; keys: page.captured; mod: page.mod }
                Item { visible: page.captured !== ""; Layout.fillWidth: true }
              }
            }
            Text {
              visible: page.captureError !== ""
              text: page.captureError
              color: Theme.yellow
              font.family: Theme.fontSans
              font.pixelSize: 13
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
            }
            RowLayout {
              visible: page.conflictId !== ""
              Layout.fillWidth: true
              spacing: 10
              Icon { name: "warning"; fill: 1; font.pixelSize: 20; color: Theme.yellow }
              Text {
                text: "Ya la usa \"" + page.descOf(page.conflictId) + "\"."
                color: Theme.yellow
                font.family: Theme.fontSans
                font.pixelSize: 13
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
              }
              CCButton { compact: true; label: "Probar otra"; onClicked: { page.captured = ""; page.conflictId = "" } }
              CCButton { compact: true; danger: true; label: "Usar igual"; onClicked: page.commit(row.e, page.captured) }
            }
          }
        }
      }

      // vacío
      Text {
        visible: list.count === 0
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: page.entries.length === 0 ? "Cargando atajos…" : "Ningún atajo coincide con \"" + page.filter + "\""
        color: DeskTheme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: 14
      }
    }
  }
}
