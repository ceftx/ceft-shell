pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Clima de Open-Meteo (coordenadas de widgets.json, sin geolocalización). Cache en ~/.cache/ceft-shell/weather.json.
Singleton {
  id: root
  readonly property string cachePath: Quickshell.env("HOME") + "/.cache/ceft-shell/weather.json"
  property var d: null
  property bool loading: false
  property bool failed: false

  readonly property bool ready: d !== null && d.current !== undefined
  readonly property real temp: ready ? d.current.temperature_2m : 0
  readonly property real feels: ready ? d.current.apparent_temperature : 0
  readonly property int humidity: ready ? Math.round(d.current.relative_humidity_2m) : 0
  readonly property real wind: ready ? d.current.wind_speed_10m : 0
  readonly property int code: ready ? d.current.weather_code : 0
  readonly property bool day: ready ? d.current.is_day === 1 : true
  readonly property string sunrise: ready && d.daily ? timePart(d.daily.sunrise[0]) : "--:--"
  readonly property string sunset: ready && d.daily ? timePart(d.daily.sunset[0]) : "--:--"
  readonly property string unit: DeskConfig.units === "fahrenheit" ? "°F" : "°C"

  function timePart(s) { return s ? String(s).split("T")[1] ?? "--:--" : "--:--" }

  readonly property var table: ({
    0:  ["Despejado", "clear_day", "clear_night"],
    1:  ["Casi despejado", "partly_cloudy_day", "partly_cloudy_night"],
    2:  ["Parcialmente nublado", "partly_cloudy_day", "partly_cloudy_night"],
    3:  ["Nublado", "cloud", "cloud"],
    45: ["Niebla", "foggy", "foggy"], 48: ["Niebla helada", "foggy", "foggy"],
    51: ["Llovizna ligera", "rainy_light", "rainy_light"], 53: ["Llovizna", "rainy_light", "rainy_light"], 55: ["Llovizna densa", "rainy", "rainy"],
    56: ["Llovizna helada", "rainy_snow", "rainy_snow"], 57: ["Llovizna helada", "rainy_snow", "rainy_snow"],
    61: ["Lluvia ligera", "rainy_light", "rainy_light"], 63: ["Lluvia", "rainy", "rainy"], 65: ["Lluvia fuerte", "rainy_heavy", "rainy_heavy"],
    66: ["Lluvia helada", "rainy_snow", "rainy_snow"], 67: ["Lluvia helada", "rainy_snow", "rainy_snow"],
    71: ["Nieve ligera", "weather_snowy", "weather_snowy"], 73: ["Nieve", "weather_snowy", "weather_snowy"], 75: ["Nieve fuerte", "snowing_heavy", "snowing_heavy"],
    77: ["Granizo fino", "weather_snowy", "weather_snowy"],
    80: ["Chubascos", "rainy", "rainy"], 81: ["Chubascos", "rainy", "rainy"], 82: ["Chubascos fuertes", "rainy_heavy", "rainy_heavy"],
    85: ["Chubascos de nieve", "weather_snowy", "weather_snowy"], 86: ["Chubascos de nieve", "snowing_heavy", "snowing_heavy"],
    95: ["Tormenta", "thunderstorm", "thunderstorm"], 96: ["Tormenta con granizo", "thunderstorm", "thunderstorm"], 99: ["Tormenta con granizo", "thunderstorm", "thunderstorm"]
  })
  readonly property var entry: table[code] ?? ["Sin datos", "cloud", "cloud"]
  readonly property string description: entry[0]
  readonly property string icon: day ? entry[1] : entry[2]
  // Frase corta para la tarjeta de perfil
  readonly property string phrase: !ready ? "Sin datos del clima" : description.toLowerCase() + " · " + Math.round(temp) + unit

  function refresh() {
    if (fetch.running) return
    loading = true
    fetch.command = ["sh", Quickshell.shellDir + "/scripts/desk-weather.sh", String(DeskConfig.lat), String(DeskConfig.lon), DeskConfig.units]
    fetch.running = true
  }

  FileView {
    id: cache
    path: root.cachePath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.d = JSON.parse(text()) } catch (e) { console.warn("weather.json inválido") } }
  }

  Process {
    id: fetch
    onExited: code => { root.loading = false; root.failed = code !== 0 }
  }

  Timer { interval: 15 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  // si cambian las coordenadas/unidades, refresca ya
  Connections {
    target: DeskConfig
    function onLatChanged() { root.refresh() }
    function onLonChanged() { root.refresh() }
    function onUnitsChanged() { root.refresh() }
  }
}
