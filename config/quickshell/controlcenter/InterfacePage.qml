import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

CCPage {
  id: page
  title: "Interfaz"
  subtitle: "Transparencias, formas, tipografía y reloj · se guarda en ui.json y se ve al instante"

  // ── fuentes instaladas ──
  property var allFonts: []
  property var monoFonts: []
  CCRun {
    id: fonts
    onFinished: (c, out) => {
      const sans = new Set(), mono = new Set()
      let sec = "all"
      for (const raw of out.split("\n")) {
        const l = raw.trim()
        if (l === "@@mono") { sec = "mono"; continue }
        if (l === "") continue
        const fam = l.split(",")[0].trim()
        if (fam === "" || fam.startsWith(".")) continue
        if (sec === "all") sans.add(fam); else mono.add(fam)
      }
      const cmp = (a, b) => a.localeCompare(b)
      page.allFonts = Array.from(sans).sort(cmp).map(f => ({ v: f, l: f }))
      page.monoFonts = Array.from(mono).sort(cmp).map(f => ({ v: f, l: f }))
    }
  }
  Component.onCompleted: fonts.run("fc-list : family | sort -u; echo @@mono; { fc-list :spacing=100 family; fc-list : family | grep -iE 'mono|code|nerd'; } | sort -u")

  // ── transparencias ──
  CCGroup {
    title: "Transparencias"
    icon: "opacity"
    subtitle: "El desenfoque lo pone Hyprland; esto es cuánto deja ver el vidrio"
    resettable: ["glassAlpha", "barAlpha", "popupAlpha"].some(k => CCCustom.uiIsSet(k))
    onResetClicked: CCCustom.resetUi(["glassAlpha", "barAlpha", "popupAlpha"])
    UiSlider { key: "glassAlpha"; label: "Vidrio"; desc: "Islas, widgets y el propio Centro de control"; icon: "blur_on"; from: 0.2; to: 1; step: 0.02; decimals: 2 }
    UiSlider { key: "barAlpha"; label: "Barra"; desc: "Fondo de la barra"; icon: "view_day"; from: 0; to: 1; step: 0.02; decimals: 2 }
    UiSlider { key: "popupAlpha"; label: "Popups"; desc: "Calendario, red, volumen y demás paneles"; icon: "web_asset"; from: 0.3; to: 1; step: 0.02; decimals: 2; last: true }
  }

  // ── formas ──
  CCGroup {
    title: "Formas"
    icon: "rounded_corner"
    resettable: ["radius", "radiusSmall", "borderWidth"].some(k => CCCustom.uiIsSet(k))
    onResetClicked: CCCustom.resetUi(["radius", "radiusSmall", "borderWidth"])
    UiSlider { key: "radius"; label: "Radio grande"; desc: "Islas y popups"; icon: "crop_square"; from: 0; to: 36; unit: " px" }
    UiSlider { key: "radiusSmall"; label: "Radio pequeño"; desc: "Filas, botones y celdas"; icon: "rounded_corner"; from: 0; to: 24; unit: " px" }
    UiSlider { key: "borderWidth"; label: "Borde"; desc: "Grosor del filo de los paneles"; icon: "border_style"; from: 0; to: 4; unit: " px"; last: true }
  }

  // ── tipografía ──
  CCGroup {
    title: "Tipografía"
    icon: "text_fields"
    subtitle: page.allFonts.length + " familias instaladas"
    resettable: ["fontSans", "fontMono", "fontSize"].some(k => CCCustom.uiIsSet(k))
    onResetClicked: CCCustom.resetUi(["fontSans", "fontMono", "fontSize"])

    Item {
      Layout.fillWidth: true
      implicitHeight: fcol.implicitHeight + 28
      ColumnLayout {
        id: fcol
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 14 }
        spacing: 8
        RowLayout {
          spacing: 8
          Text { text: "Fuente principal"; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium }
          Rectangle { visible: CCCustom.uiIsSet("fontSans"); width: 7; height: 7; radius: 4; color: Theme.accent }
          Text { text: "texto de la interfaz"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12 }
        }
        CCSelect {
          items: page.allFonts
          value: CCCustom.uiGet("fontSans")
          searchable: true; fontPreview: true; maxRows: 7
          onPicked: v => CCCustom.setUi("fontSans", v)
        }
        RowLayout {
          Layout.topMargin: 8
          spacing: 8
          Text { text: "Fuente monoespaciada"; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium }
          Rectangle { visible: CCCustom.uiIsSet("fontMono"); width: 7; height: 7; radius: 4; color: Theme.accent }
          Text { text: "números, códigos y terminal embebida"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12 }
        }
        CCSelect {
          items: page.monoFonts
          value: CCCustom.uiGet("fontMono")
          searchable: true; fontPreview: true; maxRows: 7
          onPicked: v => CCCustom.setUi("fontMono", v)
        }
      }
    }
    UiSlider { key: "fontSize"; label: "Tamaño de letra"; desc: "Base; el resto escala a partir de este"; icon: "format_size"; from: 10; to: 20; unit: " px"; last: true }
  }

  // ── reloj ──
  property date now: new Date()
  Timer { interval: 1000; running: true; repeat: true; onTriggered: page.now = new Date() }
  readonly property bool h24: CCCustom.uiGet("clock24h") === true
  readonly property bool secs: CCCustom.uiGet("clockSeconds") === true
  readonly property string timeFmt: (h24 ? "HH:mm" : "h:mm") + (secs ? ":ss" : "") + (h24 ? "" : " AP")
  readonly property string dateFmt: String(CCCustom.uiGet("dateFormat") ?? "ddd, dd/MM")
  readonly property var es: Qt.locale("es_ES")
  readonly property var dateOptions: ["ddd, dd/MM", "dd/MM/yyyy", "d MMM", "dddd d 'de' MMMM", "yyyy-MM-dd"].map(f => ({ v: f, l: es.toString(now, f) }))

  CCGroup {
    title: "Reloj"
    icon: "schedule"
    resettable: ["clock24h", "clockSeconds", "dateFormat"].some(k => CCCustom.uiIsSet(k))
    onResetClicked: CCCustom.resetUi(["clock24h", "clockSeconds", "dateFormat"])

    // vista previa
    Item {
      Layout.fillWidth: true
      implicitHeight: 84
      Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18 } height: 1; color: Theme.hairline }
      Row {
        anchors.centerIn: parent
        spacing: 16
        Text {
          text: page.es.toString(page.now, page.dateFmt)
          anchors.baseline: tm.baseline
          color: DeskTheme.textMuted
          font.family: Theme.fontSans
          font.pixelSize: 20
        }
        Text {
          id: tm
          text: page.es.toString(page.now, page.timeFmt)
          color: Theme.foreground
          font.family: Theme.fontSans
          font.pixelSize: 38
          font.weight: Font.DemiBold
          font.features: ({ "tnum": 1 })
        }
      }
      Text {
        anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 10 }
        text: "VISTA PREVIA"
        color: DeskTheme.textFaint
        font.family: Theme.fontSans
        font.pixelSize: 10
        font.letterSpacing: 1
      }
    }
    UiSwitch { key: "clock24h"; label: "Formato de 24 horas"; desc: "Apagado: 12 horas con AM/PM"; icon: "schedule" }
    UiSwitch { key: "clockSeconds"; label: "Mostrar segundos"; icon: "timer" }
    CCRow {
      label: "Formato de fecha"
      desc: "Códigos de Qt: d dd ddd dddd · M MM MMM MMMM · yy yyyy"
      icon: "calendar_month"
      last: true
      modified: CCCustom.uiIsSet("dateFormat")
      controlWidth: 400
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        CCSelect {
          items: page.dateOptions
          value: page.dateFmt
          placeholder: page.dateFmt
          onPicked: v => { CCCustom.setUi("dateFormat", v); fmtField.text = v }
        }
        RowLayout {
          spacing: 8
          CCField {
            id: fmtField
            Layout.fillWidth: true
            implicitHeight: 34
            placeholder: "formato propio"
            text: page.dateFmt
            onAccepted: if (text.trim() !== "") CCCustom.setUi("dateFormat", text.trim())
          }
          CCButton { compact: true; primary: true; icon: "check"; label: "Aplicar"; onClicked: if (fmtField.text.trim() !== "") CCCustom.setUi("dateFormat", fmtField.text.trim()) }
        }
      }
    }
  }

  // ── animaciones ──
  CCGroup {
    title: "Animaciones"
    icon: "animation"
    resettable: CCCustom.uiIsSet("animations")
    onResetClicked: CCCustom.resetUi(["animations"])
    UiSwitch { key: "animations"; label: "Animaciones de la interfaz"; desc: "Barra, popups y este panel (las de las ventanas están en Hyprland)"; icon: "animation"; last: true }
  }
}
