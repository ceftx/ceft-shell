import Quickshell
import QtQuick
import qs
import qs.desktop

// Fila de resultado. Alto 54 (calculadora: 88).
Item {
  id: row
  required property var modelData
  required property int index
  property bool selected: false
  property bool confirming: false
  signal clicked()
  signal hovered(real sx, real sy)

  readonly property bool big: modelData.kind === "calc"
  readonly property string appIcon: modelData.kind === "app" ? Quickshell.iconPath(modelData.icon ?? "", true) : ""
  readonly property bool isApp: appIcon !== ""
  readonly property bool isClip: modelData.kind === "clip"
  readonly property bool isThumb: isClip && (modelData.thumb ?? "") !== ""
  width: ListView.view ? ListView.view.width : 600
  height: big ? 88 : 54

  Item {
    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }

    Item {
      id: ico
      width: row.big ? 44 : 34; height: width
      anchors.verticalCenter: parent.verticalCenter
      Image {
        visible: row.isApp
        anchors.fill: parent
        source: row.appIcon
        sourceSize.width: 68; sourceSize.height: 68
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
      }
      Rectangle {
        visible: row.isThumb
        anchors.fill: parent
        radius: 9
        color: Qt.alpha(Theme.foreground, 0.08)
        clip: true
        Image {
          anchors.fill: parent
          source: row.isThumb ? row.modelData.thumb : ""
          sourceSize.width: 68; sourceSize.height: 68
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
        }
      }
      Rectangle {
        visible: !row.isApp && !row.isThumb
        anchors.fill: parent
        radius: width / 2
        color: row.confirming ? Qt.alpha(Theme.active, 0.18) : Qt.alpha(Theme.accent, row.selected ? 0.26 : 0.16)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Icon {
          anchors.centerIn: parent
          name: row.modelData.kind === "app" ? "apps" : row.modelData.icon
          fill: row.selected || row.modelData.pinned ? 1 : 0
          font.pixelSize: row.big ? 26 : 20
          color: row.confirming ? Theme.active : Theme.accent
        }
      }
    }

    Column {
      anchors { left: ico.right; leftMargin: 14; right: tail.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
      spacing: row.big ? 3 : 1
      Text {
        width: parent.width
        visible: row.big
        text: row.modelData.expr ?? ""
        elide: Text.ElideRight
        color: DeskTheme.textFaint
        font.family: Theme.fontSans
        font.pixelSize: 13
      }
      Text {
        width: parent.width
        text: row.modelData.kind === "calc" ? "= " + row.modelData.title : row.modelData.title
        elide: Text.ElideRight
        color: row.modelData.warn ? DeskTheme.textMuted : Theme.foreground
        font.family: row.modelData.kind === "cmd" ? Theme.font : Theme.fontSans
        font.pixelSize: row.big ? 28 : 15
        maximumLineCount: 1
        font.weight: row.big ? Font.DemiBold : (row.selected ? Font.DemiBold : Font.Medium)
      }
      Text {
        width: parent.width
        visible: !row.big && text !== ""
        text: row.confirming ? "Enter de nuevo para confirmar" : (row.modelData.sub ?? "")
        elide: Text.ElideRight
        color: row.confirming ? Theme.active : DeskTheme.textFaint
        font.family: Theme.fontSans
        font.pixelSize: 12
        font.weight: row.confirming ? Font.DemiBold : Font.Normal
      }
    }

    Row {
      id: tail
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      spacing: 6
      opacity: row.selected && row.modelData.kind !== "hint" ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: row.modelData.kind === "calc" ? "Copiar" : row.isClip ? "Pegar" : row.modelData.kind === "app" ? "Abrir" : row.confirming ? "Confirmar" : "Ejecutar"
        color: DeskTheme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: 12
        font.weight: Font.Medium
      }
      KeyCap { anchors.verticalCenter: parent.verticalCenter; text: "↵"; strong: true }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPositionChanged: mouse => { const p = mapToItem(null, mouse.x, mouse.y); row.hovered(p.x, p.y) }
    onClicked: row.clicked()
  }
}
