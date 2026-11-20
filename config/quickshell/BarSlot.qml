import QtQuick
import QtQuick.Layouts

// Un módulo de la barra: su contenido (Loader por id) dentro de un Island (que dibuja el fondo si toca).
// REGISTRO DE MÓDULOS: para agregar uno nuevo, creá BarXxx.qml (Item con implicitWidth/implicitHeight; ancho 0 = oculto),
// declará su Component acá abajo, agregalo a `registry` y a BarConfig.validIds.
//   never   nunca lleva fondo (separadores) · pad     padding horizontal del grupo · round  botón circular · bg  admite fondo tonal
//   shrink  puede encogerse (elide) cuando falta sitio · padIslands  padding extra en estilo islands
Island {
  id: slot
  required property string modId
  required property var barWindow
  property bool stretch: false      // ocupa todo el hueco disponible (lados del centro con un solo módulo)
  property bool blankSep: false

  readonly property var registry: ({
    launcher:       { comp: cLauncher,   round: true },
    activeWindow:   { comp: cActive,     pad: 14, padIslands: 16, bg: false, shrink: true, extra: 6 },
    workspaces:     { comp: cWorkspaces, pad: 8 },
    clock:          { comp: cClock,      pad: 14 },
    weather:        { comp: cWeather },
    resources:      { comp: cResources },
    media:          { comp: cMedia,      shrink: true },
    tray:           { comp: cTray },
    systemIcons:    { comp: cSystem },
    record:         { comp: cRecord },
    privacy:        { comp: cPrivacy },
    power:          { comp: cPower,      round: true },
    netSpeed:       { comp: cNet },
    updates:        { comp: cUpdates },
    keyboardLayout: { comp: cKeyboard },
    utilButtons:    { comp: cUtil },
    notifications:  { comp: cNotifs,     round: true },
    divider:        { comp: cSep,        pad: 0, never: true },
    "~sep":         { comp: cSepAuto,    pad: 0, never: true }
  })
  readonly property var meta: registry[modId] ?? ({})
  readonly property bool shrink: meta.shrink === true

  extra: meta.extra ?? 0
  round: meta.round === true
  bg: meta.never !== true && (meta.bg !== false || islands)
  pad: islands && meta.padIslands !== undefined ? meta.padIslands : (meta.pad ?? 12)
  inner: loader

  // Barra vertical: cada módulo recibe `vertical: true` y se apila (ancho fijo, alto = contenido)
  Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
  Layout.fillWidth: !vertical && (shrink || stretch)
  Layout.fillHeight: vertical && stretch
  Layout.maximumWidth: stretch || vertical ? 100000 : shrink ? wanted : 100000
  Layout.minimumWidth: 0

  Loader {
    id: loader
    sourceComponent: slot.meta.comp
    x: !slot.vertical && slot.shrink ? slot.pad : (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: !slot.vertical && slot.shrink ? Math.max(0, parent.width - slot.pad * 2) : (item ? item.implicitWidth : 0)
    height: item ? item.implicitHeight : 0
  }

  Component { id: cLauncher;   BarLauncher { vertical: slot.vertical } }
  Component { id: cActive;     ActiveTitle { vertical: slot.vertical; barScreen: slot.barWindow.screen } }
  Component { id: cWorkspaces; Workspaces { vertical: slot.vertical; barScreen: slot.barWindow.screen } }
  Component { id: cClock;      BarClock { vertical: slot.vertical; barWindow: slot.barWindow } }
  Component { id: cWeather;    BarWeather { vertical: slot.vertical } }
  Component { id: cResources;  BarResources { vertical: slot.vertical; barWindow: slot.barWindow } }
  Component { id: cMedia;      BarMedia { vertical: slot.vertical } }
  Component { id: cTray;       BarTray { vertical: slot.vertical; barWindow: slot.barWindow } }
  Component { id: cSystem;     BarSystemIcons { vertical: slot.vertical; barWindow: slot.barWindow } }
  Component { id: cRecord;     BarRecord { vertical: slot.vertical } }
  Component { id: cPrivacy;    BarPrivacy { vertical: slot.vertical; barWindow: slot.barWindow } }
  Component { id: cPower;      BarPower { vertical: slot.vertical } }
  Component { id: cNet;        BarNetSpeed { vertical: slot.vertical } }
  Component { id: cUpdates;    BarUpdates { vertical: slot.vertical } }
  Component { id: cKeyboard;   BarKeyboard { vertical: slot.vertical } }
  Component { id: cUtil;       BarUtilButtons { vertical: slot.vertical } }
  Component { id: cNotifs;     BarNotifications { vertical: slot.vertical } }
  Component { id: cSep;        BarSep { vertical: slot.vertical } }
  Component { id: cSepAuto;    BarSep { vertical: slot.vertical; auto: true; blank: slot.blankSep } }
}
