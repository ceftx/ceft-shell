import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// Widgets de escritorio: una ventana por monitor en la capa Bottom (bajo las ventanas, sobre el wallpaper).
// Solo las columnas de tarjetas reciben el ratón (mask); el resto del escritorio queda libre.
Scope {
  id: root

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      exclusiveZone: 0
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "quickshell-desktop"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      mask: Region {
        Region { item: leftCol }
        Region { item: rightCol }
        Region { item: bottomRight }
        Region { item: bottomLeft }
      }

      readonly property real m: DeskConfig.margin
      readonly property real top: m   // la barra ya reserva su zona exclusiva

      // id -> componente
      Component { id: cProfile; ProfileCard {} }
      Component { id: cClock; ClockCard {} }
      Component { id: cBigClock; BigClock {} }
      Component { id: cMedia; MediaCard {} }
      Component { id: cWeather; WeatherCard {} }
      Component { id: cCalendar; CalendarCard {} }
      Component { id: cResources; ResourcesCard {} }
      Component { id: cConverter; ConverterCard {} }
      readonly property var registry: ({
        profile: cProfile, clock: cClock, bigclock: cBigClock, media: cMedia,
        weather: cWeather, calendar: cCalendar, resources: cResources, converter: cConverter
      })

      component Stack: Column {
        id: stack
        property string side: "left"
        spacing: DeskTheme.gap
        width: DeskTheme.colWidth
        Repeater {
          model: DeskConfig.list(stack.side)
          Loader {
            required property string modelData
            required property int index
            sourceComponent: win.registry[modelData]
            onLoaded: item.order = index
          }
        }
      }

      Stack { id: leftCol; side: "left"; x: win.m; y: win.top }
      Stack { id: rightCol; side: "right"; x: win.width - width - win.m; y: win.top }
      Stack { id: bottomRight; side: "bottomRight"; x: win.width - width - win.m; y: win.height - height - win.m }
      Stack { id: bottomLeft; side: "bottomLeft"; x: win.m; y: win.height - height - win.m }
    }
  }
}
