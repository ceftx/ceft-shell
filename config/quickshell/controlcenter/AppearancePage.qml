import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

CCPage {
  id: page
  title: "Apariencia"
  subtitle: "Fondo de pantalla y colores de todo el entorno"

  readonly property string home: Quickshell.env("HOME")
  property var walls: []
  property string currentWall: ""
  property string currentTheme: ""
  property var themeNames: []
  property string pending: ""          // ruta o tema que se está aplicando

  readonly property string wallDir: walls.length > 0 ? walls[0].replace(/\/[^\/]*$/, "") : home + "/Pictures/Wallpapers"

  CCRun {
    id: listRun
    onFinished: (c, out) => page.walls = out.split("\n").map(s => s.trim()).filter(s => s.startsWith("/"))
  }
  CCRun {
    id: themeList
    onFinished: (c, out) => page.themeNames = out.split("\n").map(s => s.replace(/^\s*\*?\s*/, "").trim()).filter(s => s !== "" && !s.includes(" "))
  }
  CCRun {
    id: apply
    onFinished: (c, out) => {
      const last = out.trim().split("\n").pop().replace(/^\s*[✓✗!]\s*/, "")
      CCStore.notify(c === 0 ? (last || "Aplicado") : "Falló: " + last, c !== 0)
      page.pending = ""
    }
  }
  CCRun { id: misc }
  Component.onCompleted: {
    listRun.run(CCStore.cli + " wall list")
    themeList.run(CCStore.cli + " theme list")
  }

  FileView {
    path: page.home + "/.local/state/ceft-shell/wallpaper"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: page.currentWall = text().trim()
  }
  FileView {
    path: CCStore.cfgDir + "/theme.name"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: page.currentTheme = text().trim()
  }

  function setWall(path) { if (apply.running) return; pending = path; apply.run(CCStore.cli + " wall " + shq(path)) }
  function setTheme(name) { if (apply.running) return; pending = "theme:" + name; apply.run(CCStore.cli + " theme " + name) }
  function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

  // ── Fondo de pantalla ──
  CCGroup {
    title: "Fondo de pantalla"
    icon: "wallpaper"
    subtitle: page.walls.length + " imágenes en " + page.wallDir.replace(page.home, "~")
    headerExtra: [
      CCButton {
        compact: true; icon: "shuffle"; label: "Aleatorio"
        busy: apply.running && page.pending === "random"
        onClicked: { if (!apply.running) { page.pending = "random"; apply.run(CCStore.cli + " wall random") } }
      },
      CCButton {
        compact: true; icon: "folder_open"; label: "Abrir carpeta"
        onClicked: misc.run("setsid -f xdg-open " + page.shq(page.wallDir) + " >/dev/null 2>&1")
      }
    ]

    Item {
      Layout.fillWidth: true
      implicitHeight: grid.implicitHeight + 28
      Flow {
        id: grid
        x: 14; y: 14
        width: parent.width - 28
        spacing: 12
        readonly property int cols: 4
        readonly property real cw: Math.floor((width - (cols - 1) * spacing) / cols)
        Repeater {
          model: page.walls
          WallThumb {
            required property string modelData
            width: grid.cw
            height: Math.round(grid.cw * 0.62)
            path: modelData
            current: modelData === page.currentWall
            busy: apply.running && page.pending === modelData
            onClicked: page.setWall(modelData)
          }
        }
      }
      Text {
        visible: page.walls.length === 0 && listRun.done
        anchors.centerIn: parent
        text: "No hay imágenes en la carpeta de wallpapers.\nCopiá jpg, png o webp a " + page.wallDir.replace(page.home, "~")
        horizontalAlignment: Text.AlignHCenter
        color: DeskTheme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: 13
      }
    }
  }

  // ── Colores ──
  CCGroup {
    title: "Colores"
    icon: "palette"
    subtitle: page.currentTheme === "wallpaper" ? "Los colores siguen al fondo de pantalla" : "Tema fijo: " + page.currentTheme
    Item {
      Layout.fillWidth: true
      implicitHeight: tgrid.implicitHeight + 28
      Flow {
        id: tgrid
        x: 14; y: 14
        width: parent.width - 28
        spacing: 12
        readonly property int cols: 4
        readonly property real cw: Math.floor((width - (cols - 1) * spacing) / cols)
        ThemeCard {
          width: tgrid.cw; height: 92
          dynamic: true
          selected: page.currentTheme === "wallpaper"
          busy: apply.running && page.pending === "theme:wallpaper"
          onClicked: page.setTheme("wallpaper")
        }
        Repeater {
          model: page.themeNames.filter(n => n !== "wallpaper")
          ThemeCard {
            required property string modelData
            width: tgrid.cw; height: 92
            name: modelData
            selected: page.currentTheme === modelData
            busy: apply.running && page.pending === "theme:" + modelData
            onClicked: page.setTheme(modelData)
          }
        }
      }
    }
  }
}
