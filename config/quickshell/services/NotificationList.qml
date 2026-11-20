import QtQuick
import QtQuick.Layouts
import qs

// Lista de notificaciones agrupada por app, con acciones, descartar (× / deslizar), "Limpiar todo" y estado vacío.
// Embebible: `NotificationList { Layout.fillWidth: true; Layout.fillHeight: true }` (import qs.services).
// Los grupos se pliegan con el chevron; los no leídos llevan un punto. No marca como leído por sí sola:
// quien la aloje llama a Notifs.markAllRead() (p. ej. al abrir el panel).
Item {
  id: root
  property bool showHeader: true
  property string title: "Notificaciones"
  implicitWidth: 380
  implicitHeight: Math.min(520, 60 + content.implicitHeight)

  property var collapsed: ({})
  // [{ app, icon, time, items: [...] }] por actividad reciente (el historial ya viene ordenado, el más nuevo primero)
  readonly property var groups: {
    const map = {}, out = []
    for (const e of Notifs.list) {
      let g = map[e.appName]
      if (!g) { g = map[e.appName] = { app: e.appName, icon: e.appIcon, items: [] }; out.push(g) }
      g.items.push(e)
    }
    return out
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 8

    RowLayout {
      visible: root.showHeader
      Layout.fillWidth: true
      Layout.leftMargin: 4; Layout.rightMargin: 2
      spacing: 8
      Text {
        text: root.title
        color: Theme.foreground
        font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 4; font.weight: Font.DemiBold
      }
      Rectangle {
        visible: Notifs.unread > 0
        Layout.preferredHeight: 18; Layout.preferredWidth: Math.max(18, cnt.implicitWidth + 10); radius: 9
        color: Theme.accent
        Text { id: cnt; anchors.centerIn: parent; text: Notifs.unread; color: Theme.background
               font.family: Theme.fontSans; font.pixelSize: Theme.fontSmall - 1; font.weight: Font.Bold }
      }
      Item { Layout.fillWidth: true }
      Rectangle {
        visible: Notifs.list.length > 0
        Layout.preferredHeight: 30; Layout.preferredWidth: clr.implicitWidth + 36; radius: 15
        color: clrArea.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Row {
          id: clr
          anchors.centerIn: parent; spacing: 6
          NSym { name: "delete_sweep"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "Limpiar todo"; color: Theme.foreground; anchors.verticalCenter: parent.verticalCenter
                 font.family: Theme.fontSans; font.pixelSize: Theme.fontSize; font.weight: Font.Medium }
        }
        MouseArea { id: clrArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.clearAll() }
      }
    }

    Flickable {
      id: flick
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: width
      contentHeight: content.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      visible: Notifs.list.length > 0

      ColumnLayout {
        id: content
        width: flick.width
        spacing: 6

        Repeater {
          model: root.groups
          ColumnLayout {
            id: grp
            required property var modelData
            readonly property bool folded: root.collapsed[modelData.app] === true
            Layout.fillWidth: true
            spacing: 6

            // Cabecera del grupo
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 30
              Layout.topMargin: 4
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { const c = Object.assign({}, root.collapsed); c[grp.modelData.app] = !grp.folded; root.collapsed = c }
              }
              RowLayout {
                anchors { fill: parent; leftMargin: 4; rightMargin: 2 }
                spacing: 8
                NotifAvatar { size: 22; icon: grp.modelData.icon; appName: grp.modelData.app }
                Text {
                  text: grp.modelData.app
                  color: Theme.foreground
                  font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold
                }
                Text {
                  text: grp.modelData.items.length
                  color: Theme.muted
                  font.family: Theme.fontSans; font.pixelSize: Theme.fontSmall
                }
                NSym {
                  name: grp.folded ? "expand_more" : "expand_less"; font.pixelSize: 18
                  color: Theme.muted
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                  Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                  color: gx.containsMouse ? Theme.hover : "transparent"
                  Behavior on color { ColorAnimation { duration: Theme.animFast } }
                  NSym { anchors.centerIn: parent; name: "close"; font.pixelSize: 16; color: Theme.muted }
                  MouseArea { id: gx; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { for (const e of grp.modelData.items) Notifs.dismiss(e.id) } }
                }
              }
            }

            Repeater {
              model: grp.folded ? [] : grp.modelData.items
              Item {
                id: row
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: nc.implicitHeight
                // punto de no leído
                NotifCard {
                  id: nc
                  anchors { left: parent.left; right: parent.right }
                  entry: row.modelData
                  onDismissed: Notifs.dismiss(row.modelData.id)
                }
                Rectangle {
                  visible: !row.modelData.read
                  x: 5; y: 5; width: 8; height: 8; radius: 4
                  color: Theme.accent
                }
              }
            }
          }
        }
        Item { Layout.preferredHeight: 4 }
      }
    }

    // Estado vacío
    Item {
      visible: Notifs.list.length === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 150
      Column {
        anchors.centerIn: parent
        spacing: 6
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 56; height: 56; radius: 28
          color: Qt.alpha(Theme.foreground, 0.06)
          NSym { anchors.centerIn: parent; name: Notifs.dnd ? "notifications_off" : "notifications"; font.pixelSize: 28; color: Theme.muted }
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: Notifs.dnd ? "No molestar está activo" : "Todo en calma"
          color: Theme.foreground
          font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 2; font.weight: Font.DemiBold
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 260
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          text: Notifs.dnd ? "Solo se muestran las críticas; el resto llega acá en silencio." : "Nada pendiente. Lo nuevo aparece acá."
          color: Theme.muted
          font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
        }
      }
    }
  }
}
