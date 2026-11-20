import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

CCPage {
  id: page
  title: "Barra"
  subtitle: "Qué módulos hay y dónde · se guarda en bar.json y la barra cambia al instante"

  // ── Disposición ──
  CCGroup {
    title: "Disposición"
    icon: "view_day"
    subtitle: "Tocá un módulo para moverlo con ‹ ›, × lo quita, + agrega uno de los disponibles"
    resettable: CCCustom.barIsSet("left") || CCCustom.barIsSet("center") || CCCustom.barIsSet("right")
    onResetClicked: CCCustom.resetBar(["left", "center", "right"])

    ZoneEditor { id: zl; zone: "left";   title: "IZQUIERDA"; onSelectionChanged2: { zc.selIndex = -1; zr.selIndex = -1 } }
    Rectangle { Layout.fillWidth: true; Layout.leftMargin: 18; Layout.rightMargin: 18; height: 1; color: Theme.hairline }
    ZoneEditor { id: zc; zone: "center"; title: "CENTRO";    onSelectionChanged2: { zl.selIndex = -1; zr.selIndex = -1 } }
    Rectangle { Layout.fillWidth: true; Layout.leftMargin: 18; Layout.rightMargin: 18; height: 1; color: Theme.hairline }
    ZoneEditor { id: zr; zone: "right";  title: "DERECHA";   onSelectionChanged2: { zl.selIndex = -1; zc.selIndex = -1 } }
  }

  // ── Posición y estilo ──
  CCGroup {
    title: "Posición y estilo"
    icon: "dashboard_customize"
    resettable: ["position", "style", "groupBackground", "showBackground", "autohide", "divider"].some(k => CCCustom.barIsSet(k))
    onResetClicked: CCCustom.resetBar(["position", "style", "groupBackground", "showBackground", "autohide", "divider"])

    CCRow {
      label: "Posición"
      icon: "swap_vert"
      modified: CCCustom.barIsSet("position")
      CCSegmented {
        options: [{ v: "top", l: "Arriba", icon: "arrow_upward" }, { v: "bottom", l: "Abajo", icon: "arrow_downward" }, { v: "left", l: "Izquierda", icon: "arrow_back" }, { v: "right", l: "Derecha", icon: "arrow_forward" }]
        value: CCCustom.barGet("position")
        onPicked: v => CCCustom.setBar("position", v)
      }
    }
    CCRow {
      label: "Estilo"
      desc: "Pegada al borde, flotante o grupos como píldoras sueltas"
      icon: "style"
      modified: CCCustom.barIsSet("style")
      CCSegmented {
        options: [{ v: "hug", l: "Pegada", icon: "dock_to_bottom" }, { v: "float", l: "Flotante", icon: "web_asset" }, { v: "islands", l: "Islas", icon: "bubble_chart" }]
        value: CCCustom.barGet("style")
        onPicked: v => CCCustom.setBar("style", v)
      }
    }
    UiSwitch { file: "bar"; key: "groupBackground"; label: "Fondo de grupos"; desc: "Un fondo tonal detrás de cada grupo de módulos"; icon: "layers" }
    UiSwitch { file: "bar"; key: "showBackground"; label: "Fondo de la barra"; desc: "Apagado, los módulos flotan sobre el wallpaper"; icon: "texture" }
    UiSwitch { file: "bar"; key: "autohide"; label: "Ocultar automáticamente"; desc: "Se esconde y reaparece al acercar el puntero al borde"; icon: "visibility_off" }
    CCRow {
      label: "Divisor"
      desc: "Cómo se separan los módulos de un mismo grupo"
      icon: "more_horiz"
      last: true
      modified: CCCustom.barIsSet("divider")
      CCSegmented {
        options: [{ v: "dots", l: "Puntos" }, { v: "line", l: "Línea" }, { v: "space", l: "Espacio" }]
        value: CCCustom.barGet("divider")
        onPicked: v => CCCustom.setBar("divider", v)
      }
    }
  }

  // ── Bandeja ──
  CCGroup {
    title: "Bandeja del sistema"
    icon: "inbox"
    resettable: CCCustom.barIsSet("tray.tint") || CCCustom.barIsSet("tray.hidden")
    onResetClicked: CCCustom.resetBar(["tray.tint", "tray.hidden"])

    UiSwitch { file: "bar"; key: "tray.tint"; label: "Tintar los íconos"; desc: "Los pinta con el color del tema para que combinen"; icon: "format_color_fill" }
    Item {
      Layout.fillWidth: true
      implicitHeight: hcol.implicitHeight + 28
      ColumnLayout {
        id: hcol
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 14 }
        spacing: 10
        RowLayout {
          spacing: 8
          Icon { name: "visibility_off"; font.pixelSize: 21; color: DeskTheme.textMuted }
          ColumnLayout {
            spacing: 2
            Text { text: "Íconos ocultos"; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium }
            Text { text: "Siguen corriendo, solo no se muestran en la barra"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12 }
          }
        }
        Flow {
          Layout.fillWidth: true
          spacing: 8
          Repeater {
            model: CCCustom.trayHidden
            Rectangle {
              id: hc
              required property string modelData
              height: 30
              width: hrow.implicitWidth + 18
              radius: 15
              color: Qt.alpha(Theme.foreground, 0.10)
              border.width: 1; border.color: Qt.alpha(Theme.foreground, 0.08)
              Row {
                id: hrow
                anchors.centerIn: parent
                spacing: 6
                Text { text: hc.modelData; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                  width: 20; height: 20; radius: 10
                  anchors.verticalCenter: parent.verticalCenter
                  color: hx.containsMouse ? Qt.alpha(Theme.active, 0.30) : "transparent"
                  Icon { anchors.centerIn: parent; name: "close"; font.pixelSize: 15; color: hx.containsMouse ? Theme.active : DeskTheme.textMuted }
                  MouseArea { id: hx; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: CCCustom.setTrayHidden(CCCustom.trayHidden.filter(x => x !== hc.modelData)) }
                }
              }
            }
          }
          Text {
            visible: CCCustom.trayHidden.length === 0
            height: 30; verticalAlignment: Text.AlignVCenter
            text: "Ninguno oculto"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 13; font.italic: true
          }
        }
        // ahora en la bandeja (para ocultar con un click)
        Flow {
          Layout.fillWidth: true
          spacing: 8
          visible: now.count > 0
          Text { height: 30; verticalAlignment: Text.AlignVCenter; text: "En la bandeja ahora:"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12 }
          Repeater {
            id: now
            model: SystemTray.items.values.filter(i => CCCustom.trayHidden.indexOf(i.id) < 0)
            CCChip {
              required property var modelData
              implicitHeight: 30
              icon: "visibility_off"
              label: modelData.id
              onClicked: CCCustom.setTrayHidden(CCCustom.trayHidden.concat([modelData.id]))
            }
          }
        }
        RowLayout {
          spacing: 8
          CCField { id: trayAdd; Layout.preferredWidth: 260; implicitHeight: 34; placeholder: "Id del ícono (ej. nm-applet)"; onAccepted: page.addHidden() }
          CCButton { compact: true; icon: "add"; label: "Ocultar"; enabled: trayAdd.text.trim() !== ""; onClicked: page.addHidden() }
        }
      }
    }
  }

  function addHidden() {
    const v = trayAdd.text.trim()
    if (v === "" || CCCustom.trayHidden.indexOf(v) >= 0) { trayAdd.text = ""; return }
    CCCustom.setTrayHidden(CCCustom.trayHidden.concat([v]))
    trayAdd.text = ""
  }

  // ── Reloj ──
  CCGroup {
    title: "Reloj"
    icon: "schedule"
    subtitle: "El formato de hora y fecha está en Interfaz"
    resettable: CCCustom.barIsSet("clock.showWeather") || CCCustom.barIsSet("clock.showDate")
    onResetClicked: CCCustom.resetBar(["clock.showWeather", "clock.showDate"])
    UiSwitch { file: "bar"; key: "clock.showWeather"; label: "Mostrar el clima"; desc: "Temperatura junto a la hora"; icon: "partly_cloudy_day" }
    UiSwitch { file: "bar"; key: "clock.showDate"; label: "Mostrar la fecha"; icon: "calendar_today"; last: true }
  }
}
