import QtQuick
import qs.desktop

// Clima de la barra: mismo dato que el widget de escritorio (DeskWeather: Open-Meteo con la
// ciudad de ~/.config/ceft-shell/widgets.json; nunca geolocaliza por IP). Oculto si no hay datos.
Grid {
  id: root
  property bool vertical: false
  columns: vertical ? 1 : 2
  horizontalItemAlignment: Grid.AlignHCenter
  verticalItemAlignment: Grid.AlignVCenter
  visible: DeskWeather.ready
  spacing: vertical ? 0 : 4

  Icon {
    name: DeskWeather.icon
    fill: 1
    color: Theme.accent
    font.pixelSize: 18
  }
  Text {
    text: Math.round(DeskWeather.temp) + DeskWeather.unit
    color: Theme.foreground
    font.family: Theme.font; font.pixelSize: root.vertical ? Theme.fontSmall : Theme.fontSmall + 1
  }
}
