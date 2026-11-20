import QtQuick
import qs.desktop

// Módulo "weather": clima suelto (el mismo dato que el del reloj).
Item {
  property bool vertical: false
  implicitWidth: DeskWeather.ready ? w.implicitWidth : 0
  implicitHeight: DeskWeather.ready && vertical ? w.implicitHeight : Theme.barH - 12
  Weather { id: w; vertical: parent.vertical; anchors.centerIn: parent }
}
