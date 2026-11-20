import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

CCPage {
  id: page
  title: "Servicios"
  subtitle: "Dónde se guardan las capturas, rotación del fondo, clima y avisos de actualización"

  readonly property string home: CCStore.home
  readonly property var wx: CCStore.w.weather ?? ({})

  CCRun { id: misc }
  CCRun { id: cu; onFinished: (c) => page.hasCheckupdates = c === 0 }
  property bool hasCheckupdates: true
  Component.onCompleted: cu.run("command -v checkupdates")

  function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
  function expand(p) { return String(p).replace(/^~/, home) }
  // Carpeta válida: absoluta o con ~, sin saltos de línea
  function validPath(p) { return /^(~|\/)[^\n]*$/.test(p) && p.length > 1 }

  // ── Carpetas ──
  CCGroup {
    title: "Capturas y grabaciones"
    icon: "folder"
    subtitle: "Las usan los atajos de captura y de grabación de pantalla"
    resettable: CCStore.anySet(["paths.screenshots", "paths.recordings"])
    onResetClicked: { CCStore.resetOver(["paths.screenshots", "paths.recordings"]); shotField.text = String(CCStore.def("paths.screenshots") ?? ""); recField.text = String(CCStore.def("paths.recordings") ?? "") }

    CCRow {
      label: "Capturas de pantalla"
      icon: "screenshot_region"
      modified: CCStore.isSet("paths.screenshots")
      controlWidth: 440
      CCField {
        id: shotField
        Layout.fillWidth: true
        implicitHeight: 36
        text: String(CCStore.eff("paths.screenshots") ?? "~/Pictures/Screenshots")
        onAccepted: page.savePath("paths.screenshots", text)
      }
      CCButton { compact: true; icon: "check"; primary: true; onClicked: page.savePath("paths.screenshots", shotField.text) }
      CCButton { compact: true; icon: "folder_open"; onClicked: misc.run("mkdir -p " + page.shq(page.expand(shotField.text)) + " && setsid -f xdg-open " + page.shq(page.expand(shotField.text)) + " >/dev/null 2>&1") }
    }
    CCRow {
      label: "Grabaciones de pantalla"
      icon: "videocam"
      last: true
      modified: CCStore.isSet("paths.recordings")
      controlWidth: 440
      CCField {
        id: recField
        Layout.fillWidth: true
        implicitHeight: 36
        text: String(CCStore.eff("paths.recordings") ?? "~/Videos/Screenrecordings")
        onAccepted: page.savePath("paths.recordings", text)
      }
      CCButton { compact: true; icon: "check"; primary: true; onClicked: page.savePath("paths.recordings", recField.text) }
      CCButton { compact: true; icon: "folder_open"; onClicked: misc.run("mkdir -p " + page.shq(page.expand(recField.text)) + " && setsid -f xdg-open " + page.shq(page.expand(recField.text)) + " >/dev/null 2>&1") }
    }
    Text {
      visible: page.pathError !== ""
      Layout.fillWidth: true
      Layout.leftMargin: 18; Layout.rightMargin: 18; Layout.bottomMargin: 12
      text: page.pathError
      wrapMode: Text.WordWrap
      color: Theme.yellow
      font.family: Theme.fontSans
      font.pixelSize: 13
    }
  }
  property string pathError: ""
  function savePath(key, raw) {
    const v = raw.trim().replace(/\/+$/, "")
    if (!validPath(v)) { pathError = "Poné una ruta absoluta o que empiece con ~ (ej. ~/Pictures/Screenshots)"; return }
    pathError = ""
    CCStore.setOver(key, v)
  }

  // ── Rotación del wallpaper ──
  CCGroup {
    title: "Rotación del fondo"
    icon: "autorenew"
    subtitle: "Cambia el wallpaper solo, cada cierto tiempo, con la transición elegida"
    resettable: CCStore.anySet(["wallpaper.interval_min", "wallpaper.transition"])
    onResetClicked: CCStore.resetOver(["wallpaper.interval_min", "wallpaper.transition"])
    CCRow {
      label: "Cambiar cada"
      desc: "Los colores siguen al fondo si el tema es “del wallpaper”"
      icon: "schedule"
      modified: CCStore.isSet("wallpaper.interval_min")
      controlWidth: 300
      CCSlider {
        Layout.fillWidth: true
        from: 0; to: 240; step: 5; unit: " min"; zeroLabel: "Nunca"
        value: Number(CCStore.eff("wallpaper.interval_min") ?? 0)
        onCommitted: v => CCStore.setOver("wallpaper.interval_min", v)
      }
    }
    CCRow {
      label: "Transición"
      desc: "Cómo se funde un fondo con el siguiente"
      icon: "animation"
      last: true
      modified: CCStore.isSet("wallpaper.transition")
      Repeater {
        model: [{ v: "grow", l: "Crecer" }, { v: "wipe", l: "Barrido" }, { v: "fade", l: "Fundido" }, { v: "outer", l: "Hacia afuera" }, { v: "any", l: "Cualquiera" }]
        CCChip {
          required property var modelData
          label: modelData.l
          selected: String(CCStore.eff("wallpaper.transition") ?? "grow") === modelData.v
          onClicked: CCStore.setOver("wallpaper.transition", modelData.v)
        }
      }
    }
  }

  // ── Clima ──
  CCGroup {
    title: "Clima"
    icon: "partly_cloudy_day"
    CCRow {
      label: "Ciudad"
      desc: (page.wx.city ?? "Sin definir") + " · se elige en Escritorio"
      icon: "location_on"
      CCButton { compact: true; icon: "arrow_forward"; label: "Cambiar en Escritorio"; onClicked: CCState.tab = "desktop" }
    }
    CCRow {
      label: "Unidades"
      icon: "thermostat"
      last: true
      CCSegmented {
        options: [{ v: "celsius", l: "Celsius (°C)" }, { v: "fahrenheit", l: "Fahrenheit (°F)" }]
        value: page.wx.units ?? "celsius"
        onPicked: v => CCStore.setWidgets(c => { c.weather = Object.assign({}, c.weather ?? ({}), { units: v }) })
      }
    }
  }

  // ── Actualizaciones ──
  CCGroup {
    title: "Actualizaciones"
    icon: "system_update_alt"
    CCRow {
      label: "Módulo en la barra"
      desc: CCCustom.updatesOn
        ? "Activo en la zona " + ({ left: "izquierda", center: "centro", right: "derecha" })[CCCustom.zoneOf("updates")] + " · cuenta los paquetes pendientes (checkupdates) y abre paru -Syu"
        : "Agrega a la barra un contador de paquetes pendientes; al hacer click abre paru -Syu"
      icon: "system_update_alt"
      last: !(!page.hasCheckupdates)
      CCSwitch { checked: CCCustom.updatesOn; onToggled: v => CCCustom.setUpdates(v) }
    }
    Text {
      visible: !page.hasCheckupdates
      Layout.fillWidth: true
      Layout.leftMargin: 18; Layout.rightMargin: 18; Layout.bottomMargin: 12
      text: "No encuentro checkupdates: instalá pacman-contrib o el contador quedará oculto."
      wrapMode: Text.WordWrap
      color: Theme.yellow
      font.family: Theme.fontSans
      font.pixelSize: 13
    }
  }
}
