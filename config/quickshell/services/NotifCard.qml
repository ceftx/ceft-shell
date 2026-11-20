import QtQuick
import QtQuick.Layouts
import qs

// Una notificación. `popup: true` = sobre vidrio (esquina de la pantalla); false = dentro de una lista/panel.
// Deslizar a un lado o × la descarta (señal `dismissed`); click = acción "default" (o expandir el texto en la lista).
Item {
  id: card
  required property var entry
  property bool popup: false
  property real progress: -1        // 0..1 = barra de tiempo restante (solo popups)
  signal dismissed()
  signal activated()                // el usuario interactuó (click, acción)

  readonly property bool critical: entry.urgency === "critical"
  readonly property var acts: entry.live ? entry.actions : []
  readonly property var defaultAct: acts.find(a => a.id === "default") ?? null
  readonly property var btnActs: acts.filter(a => a.id !== "default")
  property bool expanded: false
  readonly property bool hovered: hover.hovered

  implicitHeight: body.implicitHeight + 28
  implicitWidth: 360
  clip: false

  Item {
    id: slide
    width: parent.width; height: parent.height
    opacity: 1 - Math.min(1, Math.abs(x) / (width * 0.9))
    Behavior on x { enabled: !drag.active; NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

    Rectangle {
      id: bg
      anchors.fill: parent
      radius: Theme.radiusSmall + 2
      color: card.popup ? Theme.glassPopup : Qt.alpha(Theme.foreground, card.hovered ? 0.10 : 0.06)
      border.width: card.popup ? Theme.borderWidth : 0
      border.color: card.critical ? Qt.alpha(Theme.active, 0.6) : Theme.glassEdge
      Behavior on color { ColorAnimation { duration: Theme.animFast } }

      // franja de urgencia
      Rectangle {
        visible: card.critical
        x: 0; y: 14; width: 3; height: parent.height - 28; radius: 2
        color: Theme.active
      }
      // tiempo restante
      Rectangle {
        visible: card.popup && card.progress >= 0
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: bg.radius * 0.7; bottomMargin: 1 }
        width: Math.max(0, (parent.width - bg.radius * 1.4) * card.progress); height: 2; radius: 1
        color: Qt.alpha(card.critical ? Theme.active : Theme.accent, 0.55)
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: (card.defaultAct || !card.popup) ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: {
        card.activated()
        if (card.defaultAct) Notifs.invoke(card.entry.id, "default")
        else if (card.popup) card.dismissed()
        else card.expanded = !card.expanded
      }
    }
    HoverHandler { id: hover }
    DragHandler {
      id: drag
      target: slide
      yAxis.enabled: false
      xAxis.minimum: -slide.width; xAxis.maximum: slide.width
      onActiveChanged: {
        if (active) return
        if (Math.abs(slide.x) > slide.width * 0.33) { out.to = slide.x > 0 ? slide.width : -slide.width; out.start() }
        else slide.x = 0
      }
    }
    NumberAnimation { id: out; target: slide; property: "x"; duration: Theme.animFast; easing.type: Easing.InCubic; onFinished: card.dismissed() }

    RowLayout {
      id: body
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 10 }
      spacing: 12

      NotifAvatar {
        Layout.alignment: Qt.AlignTop
        size: 42
        image: card.entry.image; icon: card.entry.appIcon; appName: card.entry.appName
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Text {
            Layout.fillWidth: card.popup
            visible: card.popup      // en la lista el grupo ya dice la app
            text: card.entry.appName
            elide: Text.ElideRight
            color: Theme.muted
            font.family: Theme.fontSans; font.pixelSize: Theme.fontSmall; font.weight: Font.Medium
          }
          Item { Layout.fillWidth: true; visible: !card.popup }
          Text {
            text: { Notifs.now; return Notifs.ago(card.entry.time) }
            color: Qt.alpha(Theme.foreground, 0.55)
            font.family: Theme.fontSans; font.pixelSize: Theme.fontSmall - 1
          }
          Rectangle {
            id: closeBtn
            Layout.preferredWidth: 22; Layout.preferredHeight: 22
            radius: 11
            color: xArea.containsMouse ? Theme.hover : "transparent"
            opacity: (card.hovered || !card.popup) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            NSym { anchors.centerIn: parent; name: "close"; font.pixelSize: 15; weight: 500 }
            MouseArea { id: xArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: { card.activated(); card.dismissed() } }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: card.entry.summary
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          maximumLineCount: card.expanded ? 6 : 2
          elide: Text.ElideRight
          color: Theme.foreground
          font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 2; font.weight: Font.DemiBold
        }
        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: card.entry.body
          textFormat: Text.StyledText
          wrapMode: Text.Wrap
          maximumLineCount: card.expanded ? 24 : (card.popup ? 4 : 3)
          elide: Text.ElideRight
          color: Theme.muted
          linkColor: Theme.accent
          font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1
          onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Flow {
          Layout.fillWidth: true
          Layout.topMargin: 6
          spacing: 6
          visible: card.btnActs.length > 0
          Repeater {
            model: card.btnActs
            Rectangle {
              required property var modelData
              height: 28; width: lbl.implicitWidth + 24; radius: 14
              color: ba.containsMouse ? Qt.alpha(Theme.accent, 0.32) : Theme.accentContainer
              scale: ba.pressed ? 0.95 : 1
              Behavior on color { ColorAnimation { duration: Theme.animFast } }
              Behavior on scale { NumberAnimation { duration: 90 } }
              Text {
                id: lbl
                anchors.centerIn: parent
                text: modelData.text
                color: Theme.foreground
                font.family: Theme.fontSans; font.pixelSize: Theme.fontSize; font.weight: Font.Medium
              }
              MouseArea { id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { card.activated(); Notifs.invoke(card.entry.id, modelData.id) } }
            }
          }
        }
      }
    }
  }
}
