import Quickshell
import QtQuick
import QtQuick.Layouts

// Módulo "privacy": íconos de micrófono / cámara / pantalla compartida, visibles SOLO mientras algo los usa.
// Click: popup con qué app usa cada uno. Ancho 0 cuando no hay nada (el slot desaparece).
Item {
  id: root
  required property var barWindow
  property bool vertical: false
  readonly property bool shown: Privacy.any
  implicitWidth: shown ? row.implicitWidth : 0
  implicitHeight: vertical ? (shown ? row.implicitHeight : 0) : Theme.barH - 12
  visible: shown

  readonly property var kinds: [
    { k: "mic",    icon: "mic",           on: Privacy.mic,    apps: Privacy.micApps,    title: "Micrófono" },
    { k: "camera", icon: "videocam",      on: Privacy.camera, apps: Privacy.cameraApps, title: "Cámara" },
    { k: "screen", icon: "screen_share",  on: Privacy.screen, apps: Privacy.screenApps, title: "Pantalla compartida" }
  ]

  Grid {
    id: row
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 3
    horizontalItemAlignment: Grid.AlignHCenter
    spacing: 8
    Repeater {
      model: root.kinds
      BarText {
        id: ic
        required property var modelData
        visible: modelData.on
        symbol: true; filled: true
        text: Theme.sym(modelData.icon)
        // pantalla en acento de aviso; mic/cámara en el color de alerta del tema
        color: modelData.k === "screen" ? Theme.yellow : Theme.active
        lit: PopupState.current === "privacy"
        onClicked: PopupState.toggle("privacy")
        SequentialAnimation on opacity {
          running: ic.visible && Theme.animations
          loops: Animation.Infinite
          NumberAnimation { to: 0.55; duration: 1100; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
        }
      }
    }
  }

  BarPopup {
    name: "privacy"
    title: "En uso ahora"
    barWindow: root.barWindow
    anchorItem: row
    panelWidth: 300

    Repeater {
      model: root.kinds.filter(k => k.on)
      RowLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: 10
        Text {
          text: Theme.sym(modelData.icon)
          font.family: Theme.iconFont; font.pixelSize: 22
          color: modelData.k === "screen" ? Theme.yellow : Theme.active
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1
          Text { text: modelData.title; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1; font.bold: true }
          Text {
            text: modelData.apps.join(", ")
            Layout.fillWidth: true; elide: Text.ElideRight
            color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
          }
        }
      }
    }
    Text {
      visible: !Privacy.any
      text: "Nada usa el micrófono, la cámara ni la pantalla."
      color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
      wrapMode: Text.WordWrap; Layout.fillWidth: true
    }
  }
}
