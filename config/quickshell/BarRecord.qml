import QtQuick
import QtQuick.Layouts

// Módulo "record": indicador de grabación (solo visible mientras graba).
Item {
  property bool vertical: false
  implicitWidth: ind.visible ? ind.implicitWidth : 0
  implicitHeight: ind.visible ? ind.implicitHeight : 0
  RecordIndicator { id: ind; vertical: parent.vertical; anchors.centerIn: parent }
}
