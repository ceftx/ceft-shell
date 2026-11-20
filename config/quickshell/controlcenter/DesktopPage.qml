import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

CCPage {
  id: page
  title: "Escritorio"
  subtitle: "Widgets, ciudad del clima, relojes del mundo y perfil"

  readonly property string home: Quickshell.env("HOME")
  readonly property var allWidgets: [
    { id: "profile",   name: "Perfil",       icon: "account_circle", desc: "Avatar, usuario, tiempo encendido y accesos rápidos" },
    { id: "clock",     name: "Reloj y zonas",icon: "schedule",       desc: "Hora local y relojes del mundo" },
    { id: "bigclock",  name: "Reloj grande", icon: "nest_clock_farsight_analog", desc: "Reloj analógico de 12 lóbulos" },
    { id: "media",     name: "Multimedia",   icon: "music_note",     desc: "Lo que suena ahora, con controles" },
    { id: "weather",   name: "Clima",        icon: "partly_cloudy_day", desc: "Temperatura y condiciones de tu ciudad" },
    { id: "calendar",  name: "Calendario",   icon: "calendar_month", desc: "Mes actual" },
    { id: "resources", name: "Recursos",     icon: "memory",         desc: "CPU, RAM, GPU y batería" },
    { id: "converter", name: "Conversor",    icon: "image",          desc: "Arrastrá imágenes para convertirlas a WebP" }
  ]
  readonly property var enabledIds: CCStore.w.enabled ?? DeskConfig.defaultEnabled
  readonly property var wx: CCStore.w.weather ?? ({})
  readonly property var clocks: CCStore.w.worldClocks ?? []
  readonly property var prof: CCStore.w.profile ?? ({})

  function toggleWidget(id, on) {
    CCStore.setWidgets(c => {
      const cur = c.enabled ?? DeskConfig.defaultEnabled.slice()
      c.enabled = page.allWidgets.map(w => w.id).filter(i => i === id ? on : cur.indexOf(i) >= 0)
    })
  }

  // ── Widgets ──
  CCGroup {
    title: "Widgets"
    icon: "widgets"
    subtitle: "Se muestran o se ocultan al instante"
    Repeater {
      model: page.allWidgets
      CCRow {
        required property var modelData
        required property int index
        label: modelData.name
        desc: modelData.desc
        icon: modelData.icon
        last: index === page.allWidgets.length - 1
        CCSwitch {
          checked: page.enabledIds.indexOf(modelData.id) >= 0
          onToggled: v => page.toggleWidget(modelData.id, v)
        }
      }
    }
  }

  // ── Clima ──
  property var results: []
  property string searchState: "idle"     // idle | loading | empty | error
  property string searchedFor: ""

  function search() {
    const q = cityField.text.trim()
    if (q.length < 2) return
    searchState = "loading"; searchedFor = q
    const xhr = new XMLHttpRequest()
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (xhr.status !== 200) { page.results = []; page.searchState = "error"; return }
      try {
        const r = JSON.parse(xhr.responseText).results ?? []
        page.results = r
        page.searchState = r.length ? "idle" : "empty"
      } catch (e) { page.results = []; page.searchState = "error" }
    }
    xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(q) + "&count=5&language=es")
    xhr.timeout = 8000
    xhr.ontimeout = () => { page.searchState = "error" }
    xhr.send()
  }
  function place(r) { return [r.name, r.admin1, r.country].filter((x, i, a) => x && a.indexOf(x) === i).join(", ") }
  function useForWeather(r) {
    CCStore.setWidgets(c => {
      c.weather = Object.assign({}, c.weather ?? ({}), { city: r.name, latitude: r.latitude, longitude: r.longitude })
      if (!c.weather.units) c.weather.units = "celsius"
    })
  }
  function addClock(city, tz) {
    if (!tz || page.clocks.length >= 3) return
    CCStore.setWidgets(c => { c.worldClocks = (c.worldClocks ?? []).concat([{ city: city, tz: tz }]) })
  }

  CCGroup {
    title: "Clima"
    icon: "partly_cloudy_day"
    subtitle: "Open-Meteo · solo se envía el nombre de la ciudad que buscás"

    CCRow {
      label: "Ciudad actual"
      desc: (page.wx.latitude !== undefined ? page.wx.latitude.toFixed(2) + ", " + page.wx.longitude.toFixed(2) : "Sin ciudad configurada")
      icon: "location_on"
      Text {
        text: page.wx.city || "—"
        color: Theme.accent
        font.family: Theme.fontSans
        font.pixelSize: 15
        font.weight: Font.DemiBold
      }
    }
    CCRow {
      label: "Unidades"
      icon: "thermostat"
      CCChip {
        label: "Celsius °C"
        selected: (page.wx.units ?? "celsius") === "celsius"
        onClicked: CCStore.setWidgets(c => { c.weather = Object.assign({}, c.weather ?? ({}), { units: "celsius" }) })
      }
      CCChip {
        label: "Fahrenheit °F"
        selected: page.wx.units === "fahrenheit"
        onClicked: CCStore.setWidgets(c => { c.weather = Object.assign({}, c.weather ?? ({}), { units: "fahrenheit" }) })
      }
    }
    CCRow {
      label: "Buscar ciudad"
      desc: "Escribí el nombre y Enter"
      icon: "search"
      last: page.searchState === "idle" && page.results.length === 0
      controlWidth: 380
      CCField {
        id: cityField
        Layout.fillWidth: true
        placeholder: "Ej: Buenos Aires, Madrid, Bogotá…"
        onAccepted: page.search()
      }
      CCButton { icon: "search"; compact: true; busy: page.searchState === "loading"; onClicked: page.search() }
    }
    Text {
      visible: page.searchState === "empty" || page.searchState === "error"
      Layout.fillWidth: true
      Layout.margins: 18
      Layout.topMargin: 0
      wrapMode: Text.WordWrap
      text: page.searchState === "empty" ? "No encontré \"" + page.searchedFor + "\". Probá con otra grafía o sin acentos."
                                           : "No pude consultar el buscador (¿sin conexión?). Reintentá en un momento."
      color: page.searchState === "error" ? Theme.yellow : DeskTheme.textMuted
      font.family: Theme.fontSans
      font.pixelSize: 13
    }
    Repeater {
      model: page.results
      CCRow {
        required property var modelData
        required property int index
        label: modelData.name
        desc: page.place(modelData) + (modelData.timezone ? "  ·  " + modelData.timezone : "")
        icon: "place"
        last: index === page.results.length - 1
        CCButton { compact: true; icon: "partly_cloudy_day"; label: "Clima"; onClicked: page.useForWeather(modelData) }
        CCButton {
          compact: true; icon: "add"; label: "Reloj"
          enabled: page.clocks.length < 3 && !!modelData.timezone
          onClicked: page.addClock(modelData.name, modelData.timezone)
        }
      }
    }
  }

  // ── Relojes ──
  CCGroup {
    title: "Relojes del mundo"
    icon: "public"
    subtitle: page.clocks.length + " de 3 · la primera celda es siempre la hora local"
    Repeater {
      model: page.clocks
      CCRow {
        required property var modelData
        required property int index
        label: modelData.city
        desc: modelData.tz
        icon: "schedule"
        CCButton {
          compact: true; danger: true; icon: "delete"; label: "Quitar"
          onClicked: CCStore.setWidgets(c => { c.worldClocks = (c.worldClocks ?? []).filter((_, i) => i !== index) })
        }
      }
    }
    Text {
      visible: page.clocks.length === 0
      Layout.fillWidth: true
      Layout.margins: 18
      text: "Todavía no hay relojes. Buscá una ciudad arriba y tocá \"Reloj\", o elegí una zona horaria acá abajo."
      wrapMode: Text.WordWrap
      color: DeskTheme.textMuted
      font.family: Theme.fontSans
      font.pixelSize: 13
    }
    CCRow {
      id: tzRow
      label: "Agregar por zona horaria"
      desc: page.clocks.length >= 3 ? "Máximo 3: quitá uno para agregar otro" : "Filtrá la lista (ej. \"lima\", \"tokyo\") y elegí"
      icon: "add_circle"
      last: true
      controlWidth: 380
      property string chosen: ""
      CCField {
        id: tzField
        Layout.fillWidth: true
        placeholder: "Zona horaria…"
        enabled: page.clocks.length < 3
        onEdited: tzRow.chosen = ""
      }
    }
    // sugerencias de la lista del sistema
    Flow {
      visible: tzField.text.trim().length >= 2 && tzRow.chosen === ""
      Layout.fillWidth: true
      Layout.margins: 18
      Layout.topMargin: 0
      spacing: 8
      Repeater {
        model: tzField.text.trim().length >= 2 ? page.tzAll.filter(z => z.toLowerCase().includes(tzField.text.trim().toLowerCase().replace(/ /g, "_"))).slice(0, 8) : []
        CCChip {
          required property string modelData
          label: modelData
          icon: "add"
          onClicked: {
            const city = modelData.split("/").pop().replace(/_/g, " ")
            page.addClock(city, modelData)
            tzField.text = ""
          }
        }
      }
    }
  }
  property var tzAll: []
  CCRun { id: tzRun; onFinished: (c, out) => page.tzAll = out.split("\n").map(s => s.trim()).filter(s => s !== "") }
  Component.onCompleted: tzRun.run("timedatectl list-timezones")

  // ── Perfil ──
  CCGroup {
    title: "Perfil"
    icon: "account_circle"
    subtitle: "Lo que muestra la tarjeta de perfil del escritorio"
    CCRow {
      label: "Nombre"
      desc: "Vacío = usuario del sistema"
      icon: "badge"
      controlWidth: 300
      CCField {
        id: nameField
        Layout.fillWidth: true
        placeholder: Quickshell.env("USER")
        text: page.prof.name ?? ""
        onAccepted: CCStore.setWidgets(c => { c.profile = Object.assign({}, c.profile ?? ({}), { name: text.trim() }) })
      }
      CCButton {
        compact: true; icon: "check"
        visible: nameField.text.trim() !== (page.prof.name ?? "")
        onClicked: nameField.accepted()
      }
    }
    CCRow {
      label: "Avatar"
      desc: "Ruta de una imagen (por defecto ~/.face)"
      icon: "face"
      last: true
      controlWidth: 420
      Rectangle {
        width: 34; height: 34; radius: 17
        color: Theme.accentContainer
        clip: true
        Image {
          id: av
          anchors.fill: parent
          source: CCStore.avatarOk ? "file://" + CCStore.avatarPath : ""
          sourceSize.width: 68; sourceSize.height: 68
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          visible: status === Image.Ready
        }
        Icon { anchors.centerIn: parent; name: "person"; fill: 1; font.pixelSize: 20; color: Theme.accent; visible: av.status !== Image.Ready }
      }
      CCField {
        id: avField
        Layout.fillWidth: true
        placeholder: "~/.face"
        text: page.prof.avatar ?? ""
        onAccepted: CCStore.setWidgets(c => { c.profile = Object.assign({}, c.profile ?? ({}), { avatar: text.trim() }) })
      }
      CCButton {
        compact: true; icon: "check"
        visible: avField.text.trim() !== (page.prof.avatar ?? "")
        onClicked: avField.accepted()
      }
    }
  }
}
