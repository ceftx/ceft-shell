import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

CCPage {
  id: page
  title: "Hyprland"
  subtitle: "Monitores, ventanas, layouts y teclado · se guarda en overrides.json y se aplica al instante"

  // ── teclado: validación contra xkeyboard-config ──
  property var xkbLayouts: []
  property var xkbVariants: ({})       // layout -> [variantes]
  property string kbError: ""
  CCRun {
    id: xkb
    onFinished: (c, out) => {
      const lays = [], vars = {}
      let sec = ""
      for (const l of out.split("\n")) {
        if (l.startsWith("!")) { sec = l.slice(1).trim(); continue }
        const m = l.match(/^\s+(\S+)\s+(.*)$/)
        if (!m) continue
        if (sec === "layout") lays.push(m[1])
        else if (sec === "variant") {
          const mm = m[2].match(/^(\S+):/)
          if (mm) { (vars[mm[1]] = vars[mm[1]] ?? []).push(m[1]) }
        }
      }
      page.xkbLayouts = lays; page.xkbVariants = vars
    }
  }
  Component.onCompleted: xkb.run("sed -n '/^! layout/,/^! option/p' /usr/share/X11/xkb/rules/evdev.lst")

  function applyKb() {
    const lay = layField.text.trim(), vr = varField.text.trim()
    const parts = lay.split(",").map(s => s.trim())
    if (lay === "" || parts.some(p => p === "")) { kbError = "Poné al menos una distribución (ej. us o us,es)"; return }
    if (xkbLayouts.length > 0) {
      const bad = parts.find(p => xkbLayouts.indexOf(p) < 0)
      if (bad) { kbError = "\"" + bad + "\" no es una distribución válida (ej. us, es, latam, gb, de)"; return }
      if (vr !== "") {
        const vs = vr.split(",").map(s => s.trim())
        const ok = vs.every((v, i) => v === "" || (xkbVariants[parts[Math.min(i, parts.length - 1)]] ?? []).indexOf(v) >= 0)
        if (!ok) { kbError = "Esa variante no existe para \"" + lay + "\""; return }
      }
    }
    kbError = ""
    if (lay !== CCStore.eff("input.kb_layout")) CCStore.setOver("input.kb_layout", lay)
    if (vr !== CCStore.eff("input.kb_variant")) CCStore.setOver("input.kb_variant", vr)
  }

  readonly property var layoutOptions: [
    { id: "master", name: "Master", desc: "Una ventana grande + pila (MonadTall)", icon: "view_sidebar" },
    { id: "dwindle", name: "Dwindle", desc: "Divide el espacio en espiral", icon: "grid_view" },
    { id: "scrolling", name: "Scrolling", desc: "Columnas que se desplazan", icon: "view_column" }
  ]
  readonly property var curLayouts: CCStore.eff("layouts") ?? ["master"]
  function setLayouts(list) { CCStore.setOver("layouts", list) }
  function moveLayout(i, d) {
    const l = curLayouts.slice(); const j = i + d
    if (j < 0 || j >= l.length) return
    const t = l[i]; l[i] = l[j]; l[j] = t; setLayouts(l)
  }
  function layoutInfo(id) { return layoutOptions.find(o => o.id === id) ?? { name: id, desc: "", icon: "dashboard" } }

  MonitorsGroup { id: mon }
  property alias monitorsGroup: mon

  // ── Huecos y bordes ──
  CCGroup {
    title: "Huecos y bordes"
    icon: "crop_free"
    resettable: CCStore.anySet(["look.gaps_in", "look.gaps_out", "look.border_size", "look.rounding", "look.smart_gaps"])
    onResetClicked: CCStore.resetOver(["look.gaps_in", "look.gaps_out", "look.border_size", "look.rounding", "look.smart_gaps"])
    SettingSlider { label: "Huecos internos"; desc: "Espacio entre ventanas"; key: "look.gaps_in"; from: 0; to: 30; unit: " px" }
    SettingSlider { label: "Huecos externos"; desc: "Espacio entre ventanas y el borde de la pantalla"; key: "look.gaps_out"; from: 0; to: 60; unit: " px" }
    SettingSlider { label: "Grosor del borde"; key: "look.border_size"; from: 0; to: 8; unit: " px" }
    SettingSlider { label: "Redondeo"; desc: "Radio de las esquinas de las ventanas"; key: "look.rounding"; from: 0; to: 30; unit: " px" }
    SettingSwitch { label: "Smart gaps"; desc: "Sin huecos ni borde cuando hay una sola ventana"; key: "look.smart_gaps"; last: true }
  }

  // ── Efectos ──
  CCGroup {
    title: "Efectos"
    icon: "blur_on"
    resettable: CCStore.anySet(["look.blur", "look.shadow", "look.animations", "look.active_opacity", "look.inactive_opacity"])
    onResetClicked: CCStore.resetOver(["look.blur", "look.shadow", "look.animations", "look.active_opacity", "look.inactive_opacity"])
    SettingSwitch { label: "Desenfoque (blur)"; desc: "Detrás de ventanas translúcidas, la barra y los paneles"; key: "look.blur" }
    SettingSwitch { label: "Sombras"; key: "look.shadow" }
    SettingSwitch { label: "Animaciones"; desc: "Apertura, cierre y cambio de workspace"; key: "look.animations" }
    SettingSlider { label: "Opacidad de la ventana activa"; key: "look.active_opacity"; from: 0.3; to: 1; step: 0.05; decimals: 2 }
    SettingSlider { label: "Opacidad de las inactivas"; key: "look.inactive_opacity"; from: 0.3; to: 1; step: 0.05; decimals: 2; last: true }
  }

  // ── Layouts ──
  CCGroup {
    title: "Layouts"
    icon: "dashboard"
    subtitle: "SUPER+Tab recorre esta lista · el primero es el de inicio"
    resettable: CCStore.isSet("layouts")
    onResetClicked: CCStore.resetOver(["layouts"])
    Repeater {
      model: page.curLayouts
      CCRow {
        required property string modelData
        required property int index
        label: (index + 1) + " · " + page.layoutInfo(modelData).name + (index === 0 ? "  (inicio)" : "")
        desc: page.layoutInfo(modelData).desc
        icon: page.layoutInfo(modelData).icon
        modified: CCStore.isSet("layouts")
        CCButton { compact: true; icon: "arrow_upward"; enabled: index > 0; onClicked: page.moveLayout(index, -1) }
        CCButton { compact: true; icon: "arrow_downward"; enabled: index < page.curLayouts.length - 1; onClicked: page.moveLayout(index, 1) }
        CCButton {
          compact: true; danger: true; icon: "close"
          enabled: page.curLayouts.length > 1
          onClicked: page.setLayouts(page.curLayouts.filter((_, i) => i !== index))
        }
      }
    }
    CCRow {
      label: "Agregar layout"
      icon: "add_circle"
      last: true
      Repeater {
        model: page.layoutOptions.filter(o => page.curLayouts.indexOf(o.id) < 0)
        CCChip {
          required property var modelData
          icon: "add"; label: modelData.name
          onClicked: page.setLayouts(page.curLayouts.concat([modelData.id]))
        }
      }
      Text {
        visible: page.curLayouts.length >= page.layoutOptions.length
        text: "Ya están todos"
        color: DeskTheme.textFaint
        font.family: Theme.fontSans
        font.pixelSize: 13
      }
    }
  }

  // ── Ajustes finos de cada layout ──
  readonly property var dwKeys: ["dwindle.preserve_split", "dwindle.smart_split", "dwindle.force_split"]
  readonly property var maKeys: ["master.new_status", "master.orientation", "master.mfact"]
  CCGroup {
    title: "Dwindle"
    icon: "grid_view"
    subtitle: "Divide el espacio en espiral"
    resettable: CCStore.anySet(page.dwKeys)
    onResetClicked: CCStore.resetOver(page.dwKeys)
    CCRow {
      label: "Conservar la división"
      desc: "Mantiene la orientación de cada división al cambiar el tamaño"
      modified: CCStore.isSet("dwindle.preserve_split")
      CCSwitch { checked: (CCStore.eff("dwindle.preserve_split") ?? true) === true; onToggled: v => CCStore.setOver("dwindle.preserve_split", v) }
    }
    CCRow {
      label: "División inteligente"
      desc: "La ventana nueva va del lado del puntero"
      modified: CCStore.isSet("dwindle.smart_split")
      CCSwitch { checked: (CCStore.eff("dwindle.smart_split") ?? false) === true; onToggled: v => CCStore.setOver("dwindle.smart_split", v) }
    }
    CCRow {
      label: "Lado de la ventana nueva"
      last: true
      modified: CCStore.isSet("dwindle.force_split")
      CCSegmented {
        options: [{ v: 0, l: "Automático" }, { v: 1, l: "Izq./arriba" }, { v: 2, l: "Der./abajo" }]
        value: Number(CCStore.eff("dwindle.force_split") ?? 0)
        onPicked: v => CCStore.setOver("dwindle.force_split", v)
      }
    }
  }
  CCGroup {
    title: "Master"
    icon: "view_sidebar"
    subtitle: "Una ventana grande y una pila al costado"
    resettable: CCStore.anySet(page.maKeys)
    onResetClicked: CCStore.resetOver(page.maKeys)
    CCRow {
      label: "Ventana nueva"
      desc: "Dónde cae al abrirse"
      modified: CCStore.isSet("master.new_status")
      CCSegmented {
        options: [{ v: "slave", l: "En la pila" }, { v: "master", l: "Principal" }, { v: "inherit", l: "Hereda" }]
        value: String(CCStore.eff("master.new_status") ?? "slave")
        onPicked: v => CCStore.setOver("master.new_status", v)
      }
    }
    CCRow {
      label: "Orientación"
      desc: "De qué lado va la ventana principal"
      modified: CCStore.isSet("master.orientation")
      CCSegmented {
        options: [{ v: "left", l: "Izquierda" }, { v: "right", l: "Derecha" }, { v: "top", l: "Arriba" }, { v: "bottom", l: "Abajo" }, { v: "center", l: "Centro" }]
        value: String(CCStore.eff("master.orientation") ?? "left")
        onPicked: v => CCStore.setOver("master.orientation", v)
      }
    }
    SettingSlider { label: "Tamaño de la principal"; desc: "Fracción del ancho"; key: "master.mfact"; from: 0.2; to: 0.8; step: 0.01; decimals: 2; last: true }
  }

  // ── Luz nocturna ──
  property bool nightOn: false
  CCRun { id: nightRun }
  CCGroup {
    title: "Luz nocturna"
    icon: "bedtime"
    subtitle: "hyprsunset · SUPER+R la activa, SUPER+SHIFT+R la apaga"
    resettable: CCStore.isSet("nightlight")
    onResetClicked: CCStore.resetOver(["nightlight"])
    SettingSlider {
      label: "Temperatura de color"
      desc: "Más bajo = más cálido"
      key: "nightlight"; from: 1000; to: 6500; step: 100; unit: " K"
    }
    CCRow {
      label: "Probar ahora"
      desc: "Aplica la temperatura actual a la pantalla"
      last: true
      CCButton {
        compact: true; icon: "light_mode"; label: "Apagar"
        onClicked: nightRun.run("pkill hyprsunset; true")
      }
      CCButton {
        compact: true; primary: true; icon: "bedtime"; label: "Activar"
        onClicked: nightRun.run("pkill hyprsunset; setsid -f hyprsunset -t " + Math.round(Number(CCStore.eff('nightlight'))) + " >/dev/null 2>&1; true")
      }
    }
  }

  readonly property var kbKeys: ["input.kb_layout", "input.kb_variant", "input.follow_mouse", "input.repeat_delay", "input.repeat_rate", "input.numlock_by_default"]

  // ── Teclado y ratón ──
  CCGroup {
    title: "Teclado y ratón"
    icon: "keyboard"
    resettable: CCStore.anySet(kbKeys)
    onResetClicked: { CCStore.resetOver(kbKeys); page.kbError = "" }
    CCRow {
      label: "Distribución"
      desc: "Código XKB; varias separadas por coma (us,es)"
      icon: "language"
      modified: CCStore.isSet("input.kb_layout")
      controlWidth: 330
      CCField {
        id: layField
        Layout.fillWidth: true
        placeholder: "us"
        text: String(CCStore.eff("input.kb_layout") ?? "")
        onAccepted: page.applyKb()
      }
    }
    CCRow {
      label: "Variante"
      desc: "Ej. altgr-intl (AltGr + vocal = acentos, AltGr + n = ñ)"
      icon: "text_fields"
      modified: CCStore.isSet("input.kb_variant")
      controlWidth: 330
      CCField {
        id: varField
        Layout.fillWidth: true
        placeholder: "ninguna"
        text: String(CCStore.eff("input.kb_variant") ?? "")
        onAccepted: page.applyKb()
      }
      CCButton { compact: true; primary: true; icon: "check"; label: "Aplicar"; onClicked: page.applyKb() }
    }
    Text {
      visible: page.kbError !== ""
      Layout.fillWidth: true
      Layout.leftMargin: 18; Layout.rightMargin: 18; Layout.bottomMargin: 12
      text: page.kbError
      wrapMode: Text.WordWrap
      color: Theme.yellow
      font.family: Theme.fontSans
      font.pixelSize: 13
    }
    CCRow {
      label: "Retardo de repetición"
      desc: "Milisegundos hasta que una tecla empieza a repetirse"
      icon: "timer"
      modified: CCStore.isSet("input.repeat_delay")
      controlWidth: 300
      CCSlider {
        Layout.fillWidth: true
        from: 150; to: 1000; step: 25; unit: " ms"
        value: Number(CCStore.eff("input.repeat_delay") ?? 600)
        onCommitted: v => CCStore.setOver("input.repeat_delay", v)
      }
    }
    CCRow {
      label: "Velocidad de repetición"
      desc: "Repeticiones por segundo"
      icon: "speed"
      modified: CCStore.isSet("input.repeat_rate")
      controlWidth: 300
      CCSlider {
        Layout.fillWidth: true
        from: 5; to: 80; step: 1; unit: "/s"
        value: Number(CCStore.eff("input.repeat_rate") ?? 25)
        onCommitted: v => CCStore.setOver("input.repeat_rate", v)
      }
    }
    CCRow {
      label: "Bloq Num al iniciar"
      desc: "Activa el teclado numérico al entrar a la sesión"
      icon: "pin"
      modified: CCStore.isSet("input.numlock_by_default")
      CCSwitch {
        checked: (CCStore.eff("input.numlock_by_default") ?? false) === true
        onToggled: v => CCStore.setOver("input.numlock_by_default", v)
      }
    }
    CCRow {
      label: "Foco con el ratón"
      desc: "Cómo se elige la ventana activa"
      icon: "mouse"
      last: true
      modified: CCStore.isSet("input.follow_mouse")
      Repeater {
        model: [{ v: 1, l: "Sigue al ratón" }, { v: 2, l: "Click + puntero" }, { v: 3, l: "Independiente" }, { v: 0, l: "Solo click" }]
        CCChip {
          required property var modelData
          label: modelData.l
          selected: Number(CCStore.eff("input.follow_mouse")) === modelData.v
          onClicked: CCStore.setOver("input.follow_mouse", modelData.v)
        }
      }
    }
  }

  // ── Pantalla ──
  CCGroup {
    title: "Pantalla"
    icon: "monitor"
    resettable: CCStore.anySet(["display.vrr", "display.auto_hdr"])
    onResetClicked: CCStore.resetOver(["display.vrr", "display.auto_hdr"])
    CCRow {
      label: "Sincronía adaptativa (VRR)"
      desc: "Evita el tearing si el monitor la soporta"
      icon: "speed"
      modified: CCStore.isSet("display.vrr")
      Repeater {
        model: [{ v: 0, l: "Apagada" }, { v: 1, l: "Siempre" }, { v: 2, l: "Pantalla completa" }]
        CCChip {
          required property var modelData
          label: modelData.l
          selected: Number(CCStore.eff("display.vrr")) === modelData.v
          onClicked: CCStore.setOver("display.vrr", modelData.v)
        }
      }
    }
    CCRow {
      label: "HDR automático"
      desc: "Cambia a gama amplia con contenido en pantalla completa (la pantalla parpadea 2-3 s)"
      icon: "hdr_on"
      last: true
      modified: CCStore.isSet("display.auto_hdr")
      CCSwitch {
        checked: Number(CCStore.eff("display.auto_hdr")) === 1
        onToggled: v => CCStore.setOver("display.auto_hdr", v ? 1 : 0)
      }
    }
  }
}
