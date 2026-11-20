import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

CCPage {
  id: page
  title: "Rápido"
  subtitle: "Lo que más se toca, en una pantalla"

  Component.onCompleted: { CCCustom.refreshWalls(); CCCustom.refreshNight(); GameMode.refresh() }

  // ── Modo juego ──
  CCGroup {
    title: "Modo juego"
    icon: "sports_esports"
    subtitle: GameMode.on ? "Activo: sin animaciones, blur ni sombras, y no molestar" : "Máximo rendimiento al jugar (SUPER + G)"
    CCRow {
      label: "Activar modo juego"
      desc: GameMode.error !== "" ? GameMode.error : "Apaga animaciones, blur, sombras y huecos; silencia los avisos. Al desactivar vuelve todo"
      icon: "sports_esports"
      last: true
      CCSwitch { checked: GameMode.on; enabled: !GameMode.busy; onToggled: v => GameMode.set(v) }
    }
  }

  // ── Fondo ──
  CCGroup {
    title: "Fondo de pantalla"
    icon: "wallpaper"
    subtitle: "Los más recientes · " + CCCustom.wallCount + " en total"
    headerExtra: [
      CCButton {
        compact: true; icon: "shuffle"; label: "Aleatorio"
        busy: CCCustom.applying && CCCustom.pending === "random"
        onClicked: CCCustom.runApply("random", CCStore.cli + " wall random")
      },
      CCButton { compact: true; icon: "grid_view"; label: "Ver todos"; onClicked: CCState.tab = "appearance" }
    ]
    Item {
      Layout.fillWidth: true
      implicitHeight: grid.implicitHeight + 28
      Flow {
        id: grid
        x: 14; y: 14
        width: parent.width - 28
        spacing: 10
        readonly property int cols: 4
        readonly property real cw: Math.floor((width - (cols - 1) * spacing) / cols)
        Repeater {
          model: CCCustom.recentWalls
          WallThumb {
            required property string modelData
            width: grid.cw
            height: Math.round(grid.cw * 0.58)
            path: modelData
            current: modelData === CCCustom.currentWall
            busy: CCCustom.applying && CCCustom.pending === modelData
            onClicked: CCCustom.setWall(modelData)
          }
        }
      }
      Text {
        visible: CCCustom.recentWalls.length === 0
        anchors.centerIn: parent
        text: "No hay imágenes en ~/Pictures/Wallpapers"
        color: DeskTheme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: 13
      }
    }
  }

  // ── Color ──
  CCGroup {
    title: "Modo de color"
    icon: "palette"
    subtitle: CCCustom.currentTheme === "wallpaper" ? "Los colores siguen al fondo de pantalla" : "Tema fijo: " + CCCustom.currentTheme
    Item {
      Layout.fillWidth: true
      implicitHeight: cflow.implicitHeight + 28
      Flow {
        id: cflow
        x: 16; y: 14
        width: parent.width - 32
        spacing: 8
        CCChip {
          icon: "wallpaper"; label: "Del wallpaper"
          selected: CCCustom.currentTheme === "wallpaper"
          onClicked: CCCustom.setTheme("wallpaper")
        }
        Rectangle { width: 1; height: 32; color: Theme.hairline }
        Repeater {
          model: CCCustom.themeNames.filter(n => n !== "wallpaper")
          CCChip {
            required property string modelData
            label: modelData
            selected: CCCustom.currentTheme === modelData
            onClicked: CCCustom.setTheme(modelData)
          }
        }
      }
    }
  }

  // ── Vidrio y efectos ──
  CCGroup {
    title: "Vidrio y efectos"
    icon: "blur_on"
    UiSlider { key: "glassAlpha"; label: "Transparencia del vidrio"; desc: "Más bajo deja ver más el fondo"; icon: "opacity"; from: 0.2; to: 1; step: 0.02; decimals: 2 }
    SettingSwitch { label: "Desenfoque (blur)"; desc: "Detrás de ventanas translúcidas, la barra y los paneles"; key: "look.blur"; icon: "blur_on" }
    CCRow {
      label: "Animaciones"
      desc: "Ventanas de Hyprland y la interfaz de Quickshell"
      icon: "animation"
      modified: CCStore.isSet("look.animations") || CCCustom.uiIsSet("animations")
      CCSwitch { checked: CCCustom.animationsOn; onToggled: v => CCCustom.setAnimations(v) }
    }
    SettingSlider { label: "Huecos internos"; desc: "Espacio entre ventanas"; key: "look.gaps_in"; from: 0; to: 30; unit: " px"; icon: "crop_free" }
    SettingSlider { label: "Huecos externos"; desc: "Entre las ventanas y el borde de la pantalla"; key: "look.gaps_out"; from: 0; to: 60; unit: " px"; icon: "fit_screen" }
    CCRow {
      label: "Luz nocturna"
      desc: "hyprsunset a " + Math.round(Number(CCStore.eff("nightlight") ?? 3500)) + " K · la temperatura se cambia en Hyprland"
      icon: "bedtime"
      last: true
      CCSwitch { checked: CCCustom.nightOn; onToggled: v => CCCustom.setNight(v) }
    }
  }

  // ── Barra ──
  CCGroup {
    title: "Barra"
    icon: "view_day"
    headerExtra: [ CCButton { compact: true; icon: "tune"; label: "Personalizar"; onClicked: CCState.tab = "bar" } ]
    CCRow {
      label: "Estilo"
      icon: "style"
      modified: CCCustom.barIsSet("style")
      CCSegmented {
        options: [{ v: "hug", l: "Pegada" }, { v: "float", l: "Flotante" }, { v: "islands", l: "Islas" }]
        value: CCCustom.barGet("style")
        onPicked: v => CCCustom.setBar("style", v)
      }
    }
    CCRow {
      label: "Posición"
      icon: "swap_vert"
      last: true
      modified: CCCustom.barIsSet("position")
      CCSegmented {
        options: [{ v: "top", l: "Arriba" }, { v: "bottom", l: "Abajo" }, { v: "left", l: "Izquierda" }, { v: "right", l: "Derecha" }]
        value: CCCustom.barGet("position")
        onPicked: v => CCCustom.setBar("position", v)
      }
    }
  }
}
