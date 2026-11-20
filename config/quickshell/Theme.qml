pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Colores desde ~/.config/ceft-shell/theme.json (los cambia `ceft-shell theme <nombre>`).
// Se recarga en vivo; si falta el archivo o una clave, usa Tokyo Night.
Singleton {
  id: root
  property var t: ({})
  property var u: ({})   // ui.json (Centro de control): gana sobre theme.json

  FileView {
    path: Quickshell.env("HOME") + "/.config/ceft-shell/theme.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.t = JSON.parse(text()) } catch (e) { console.warn("theme.json inválido:", e) }
    }
  }

  // Precedencia: ui.json > theme.json > defaults. Se recarga en vivo; si falta o es inválido, se ignora.
  FileView {
    path: Quickshell.env("HOME") + "/.config/ceft-shell/ui.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { const v = JSON.parse(text()); root.u = (v && typeof v === "object") ? v : ({}) }
      catch (e) { console.warn("ui.json inválido:", e) }
    }
    onLoadFailed: root.u = ({})
  }

  readonly property color background: t.background ?? "#1a1b26"
  readonly property color foreground: t.foreground ?? "#a9b1d6"
  readonly property color dim: t.dim ?? "#565f89"
  readonly property color accent: t.accent ?? "#7aa2f7"
  readonly property color active: t.active ?? "#f7768e"
  readonly property color yellow: t.yellow ?? "#e0af68"
  readonly property color green: t.green ?? "#9ece6a"
  readonly property color surface: t.surface ?? "#24283b"   // filas / hover de los paneles
  readonly property color border: t.border ?? "#3b4261"
  readonly property color accent2: t.accent2 ?? accent
  readonly property color shadow: t.shadow ?? "#000000"

  readonly property string font: u.fontMono ?? t.font ?? "JetBrainsMono Nerd Font"
  // fontSize (ui.json, 13 por defecto) = texto base; el de los paneles es 1 px menos (12)
  readonly property int fontSize: fontBase - 1
  readonly property int barHeight: t.barHeight ?? 40        // alto de las islas
  readonly property int spacing: t.spacing ?? 16

  // ── Vidrio / forma (islas flotantes) ──
  readonly property int barMargin: t.barMargin ?? 10        // separación con el borde de pantalla (arriba/lados)
  readonly property int barGap: t.barGap ?? 6               // aire bajo la barra antes de las ventanas
  readonly property int islandPad: t.islandPad ?? 16        // padding horizontal interno de una isla
  readonly property int radius: u.radius ?? t.radius ?? 20              // radio de islas y popups
  readonly property int radiusSmall: u.radiusSmall ?? t.radiusSmall ?? 12    // filas, botones, celdas
  readonly property real glassAlpha: u.glassAlpha ?? t.glassAlpha ?? 0.74   // opacidad del vidrio de la barra (el blur lo pone Hyprland)
  readonly property real popupAlpha: u.popupAlpha ?? t.popupAlpha ?? 0.84   // vidrio de popups/paneles (más opaco: más texto)
  readonly property real hoverAlpha: t.hoverAlpha ?? 0.10   // relleno hover sobre foreground
  readonly property color glass: Qt.alpha(background, glassAlpha)
  readonly property color glassPopup: Qt.alpha(background, popupAlpha)
  readonly property int borderWidth: u.borderWidth ?? t.borderWidth ?? 1   // borde de popups y vidrio
  readonly property color glassEdge: Qt.alpha(foreground, 0.10)   // borde fino del vidrio
  readonly property color hairline: Qt.alpha(foreground, 0.08)    // divisores
  readonly property color muted: Qt.alpha(foreground, 0.74)      // texto atenuado SOBRE vidrio (dim puede perder contraste)
  readonly property color hover: Qt.alpha(foreground, hoverAlpha)
  // Animaciones de la UI (ui.json "animations": false → todas las duraciones a 0)
  readonly property bool animations: u.animations ?? true
  readonly property int animFast: animations ? 140 : 0
  readonly property int animMed: animations ? 220 : 0
  readonly property int animSlow: animations ? 320 : 0

  // ── Reloj (ui.json) ──
  readonly property bool clock24h: u.clock24h ?? true
  readonly property bool clockSeconds: u.clockSeconds ?? false
  readonly property string dateFormat: u.dateFormat ?? "ddd, dd/MM"
  readonly property string timeFormat: (clock24h ? "HH:mm" : "h:mm") + (clockSeconds ? ":ss" : "") + (clock24h ? "" : " AP")
  readonly property var dayNames: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
  readonly property var monthNames: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
  // Fecha en español sin depender del locale del sistema. Tokens: dddd ddd dd d MMMM MMM MM M yyyy yy; 'texto' literal.
  function formatDate(d, fmt) {
    const pad = n => String(n).padStart(2, "0")
    const day = dayNames[d.getDay()], mon = monthNames[d.getMonth()]
    const map = {
      "dddd": day, "ddd": day.slice(0, 3), "dd": pad(d.getDate()), "d": String(d.getDate()),
      "MMMM": mon, "MMM": mon.slice(0, 3), "MM": pad(d.getMonth() + 1), "M": String(d.getMonth() + 1),
      "yyyy": String(d.getFullYear()), "yy": pad(d.getFullYear() % 100)
    }
    return String(fmt).replace(/'([^']*)'|dddd|ddd|dd|d|MMMM|MMM|MM|M|yyyy|yy/g, (m, lit) => lit !== undefined ? lit : map[m])
  }

  // ── Ronda 2: barra estilo end-4 (a todo el ancho, casi transparente) ──
  readonly property string fontSans: u.fontSans ?? t.fontSans ?? "Inter"
  // Qt no resuelve por nombre la variable de sistema (cae a Nerd Font): se carga el archivo.
  FontLoader {
    id: iconLoader
    source: "file:///usr/share/fonts/ttf-material-symbols-variable/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
  }
  readonly property string iconFont: t.iconFont ?? (iconLoader.status === FontLoader.Ready ? iconLoader.name : "Material Symbols Rounded")
  readonly property int barH: t.barH ?? 44                  // alto de la barra a todo el ancho
  readonly property int barW: t.barW ?? 52                  // ancho de la barra vertical (izquierda / derecha)
  readonly property int popupGap: t.popupGap ?? 6           // hueco entre el borde inferior de la barra y los popups
  readonly property real barAlpha: u.barAlpha ?? t.barAlpha ?? 0.55       // fondo de la barra (muy sutil; el blur lo pone Hyprland)
  readonly property color barBg: Qt.alpha(background, barAlpha)
  readonly property color barEdge: Qt.alpha(foreground, 0.07)
  // Fondo de los grupos de la barra. 0 = sin cajas, todo directo sobre la barra (estilo end4-pC).
  // Para volver a las píldoras: "groupAlpha": 0.55 en theme.json
  // bar.json "groupBackground": true los enciende (0.55)
  readonly property real groupAlpha: BarConfig.groupBackground ? 0.55 : (t.groupAlpha ?? 0)
  readonly property color groupBg: Qt.alpha(surface, groupAlpha)
  // Estilo "islands": píldoras de vidrio sobre el fondo, sin barra
  readonly property color islandBg: Qt.alpha(background, Math.max(glassAlpha, 0.6))
  readonly property color islandEdge: Qt.alpha(foreground, 0.12)
  readonly property color accentContainer: Qt.alpha(accent, 0.22)
  readonly property int fontSmall: fontBase - 1
  readonly property color barText: Qt.alpha(foreground, 0.88)   // texto secundario de la barra (legible sobre wallpaper claro)
  readonly property color barTextStrong: foreground
  readonly property int fontBase: u.fontSize ?? t.fontSize ?? 13

  // Material Symbols: Qt no aplica las ligaduras por nombre de esta fuente, así que se mapea nombre -> codepoint.
  readonly property var symbolMap: ({
    "smart_toy": 0xf06c,
    "wb_sunny": 0xe430,
    "partly_cloudy_day": 0xf172,
    "cloud": 0xf15c,
    "foggy": 0xe818,
    "thunderstorm": 0xebdb,
    "weather_snowy": 0xe2cd,
    "rainy": 0xf176,
    "lan": 0xeb2f,
    "wifi_1_bar": 0xe4ca,
    "wifi_2_bar": 0xe4d9,
    "wifi": 0xe63e,
    "wifi_off": 0xe648,
    "vpn_key": 0xe0da,
    "lock": 0xe899,
    "bluetooth": 0xe1a7,
    "bluetooth_disabled": 0xe1a9,
    "bluetooth_connected": 0xe1a8,
    "volume_off": 0xe04f,
    "volume_up": 0xe050,
    "volume_down": 0xe04d,
    "volume_mute": 0xe04e,
    "mic": 0xe31d,
    "mic_off": 0xe02b,
    "fiber_manual_record": 0xe061,
    "chevron_left": 0xe5cb,
    "chevron_right": 0xe5cc,
    "power_settings_new": 0xf8c7,
    "music_note": 0xe405,
    "play_arrow": 0xe037,
    "pause": 0xe034,
    "arrow_downward": 0xe5db,
    "arrow_upward": 0xe5d8,
    "system_update": 0xe62a,
    "keyboard": 0xe312,
    "crop": 0xe3be,
    "colorize": 0xe3b8,
    "tune": 0xe429,
    "memory": 0xe322,
    "speed": 0xe9e4,
    "videocam": 0xe04b,
    "screen_share": 0xe0e2,
    "sports_esports": 0xea28,
    "brightness_medium": 0xe1ae
  })
  function sym(names) {
    return String(names).split(" ").map(n => symbolMap[n] ? String.fromCodePoint(symbolMap[n]) : n).join("\u2009")
  }

  readonly property string terminal: "kitty"
}
