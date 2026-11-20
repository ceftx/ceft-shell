import QtQuick
import qs.services

// Puente a Notifs (servicio de A). Solo se carga (Loader) cuando services/Notifs.qml existe.
QtObject {
  readonly property bool dnd: Notifs.dnd
  readonly property int unread: Notifs.unread
  function toggleDnd() { Notifs.setDnd(!Notifs.dnd) }
  function markAllRead() { Notifs.markAllRead() }
}
