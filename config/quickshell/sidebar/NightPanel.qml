import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Luz nocturna: temperatura, horario automático (desde / hasta). Config en nightlight.json (ver Night.qml).
ColumnLayout {
  id: root
  spacing: 12

  // ── automático ──
  RowLayout {
    Layout.fillWidth: true
    spacing: 12
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      Text { text: "Horario automático"; color: DeskTheme.text; font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.DemiBold }
      Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: Night.auto ? (Night.inWindow ? "Activa hasta las " + Night.to : "Se enciende a las " + Night.from) : "Encendé y apagá a mano"
        color: DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 11
      }
    }
    Item {
      implicitWidth: 44; implicitHeight: 26
      Rectangle {
        anchors.fill: parent; radius: 13
        color: Night.auto ? Theme.accent : Qt.alpha(Theme.foreground, 0.16)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Rectangle {
          width: 18; height: 18; radius: 9; anchors.verticalCenter: parent.verticalCenter
          x: Night.auto ? parent.width - width - 4 : 4
          color: Night.auto ? Theme.background : Qt.alpha(Theme.foreground, 0.85)
          Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        }
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Night.set("auto", !Night.auto) }
    }
  }

  // ── desde / hasta ──
  RowLayout {
    Layout.fillWidth: true
    spacing: 10
    opacity: Night.auto ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    TimeBox { label: "Desde"; value: Night.from; onChanged: v => Night.set("from", v) }
    Icon { name: "arrow_forward"; font.pixelSize: 18; color: DeskTheme.textFaint }
    TimeBox { label: "Hasta"; value: Night.to; onChanged: v => Night.set("to", v) }
  }

  // ── temperatura ──
  SSlider {
    compact: true
    icon: "thermostat"
    label: "Temperatura · " + Night.temp + " K  (" + (Night.temp < 3000 ? "cálida" : Night.temp < 4500 ? "suave" : "casi neutra") + ")"
    showPct: false
    // 6500 K (neutra) a la izquierda... 1500 K (muy cálida) a la derecha: más a la derecha = más cálido
    value: (6500 - Night.temp) / 5000
    onMoved: v => Night.setTemp(6500 - v * 5000)
    onIconClicked: Night.setTemp(2400)
  }

  Text {
    Layout.fillWidth: true
    text: Night.running ? "Luz nocturna activa ahora" : "Apagada ahora"
    color: Night.running ? Theme.accent : DeskTheme.textFaint
    font.family: Theme.fontSans; font.pixelSize: 11
  }

  // ── caja de hora: - HH:MM + (pasos de 30 min) ──
  component TimeBox: Rectangle {
    id: tb
    property string label: ""
    property string value: "20:00"
    signal changed(string v)
    Layout.fillWidth: true
    implicitHeight: 52
    radius: Theme.radiusSmall + 4
    color: DeskTheme.tile
    function step(d) {
      let m = (Night.minutes(value) + d + 1440) % 1440
      changed(Night.fmt(Math.floor(m / 60), m % 60))
    }
    ColumnLayout {
      anchors.centerIn: parent
      spacing: 0
      Text { Layout.alignment: Qt.AlignHCenter; text: tb.label; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 11 }
      Text {
        Layout.alignment: Qt.AlignHCenter
        text: tb.value
        color: DeskTheme.text; font.family: Theme.fontSans; font.pixelSize: 18; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
      }
    }
    Repeater {
      model: [{ s: -30, left: true, ic: "remove" }, { s: 30, left: false, ic: "add" }]
      Rectangle {
        required property var modelData
        anchors { verticalCenter: parent.verticalCenter; left: modelData.left ? parent.left : undefined; right: modelData.left ? undefined : parent.right; margins: 6 }
        width: 30; height: 30; radius: 15
        color: bma.containsMouse ? DeskTheme.tileHover : "transparent"
        Icon { anchors.centerIn: parent; name: modelData.ic; font.pixelSize: 18; color: DeskTheme.textMuted }
        MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tb.step(modelData.s) }
      }
    }
    MouseArea {   // rueda sobre la caja: ±30 min
      anchors.fill: parent; acceptedButtons: Qt.NoButton
      onWheel: wheel => tb.step(wheel.angleDelta.y > 0 ? 30 : -30)
    }
  }
}
