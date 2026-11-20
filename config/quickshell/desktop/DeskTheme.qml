pragma Singleton
import Quickshell
import QtQuick
import qs

// Tokens de los widgets de escritorio, derivados de Theme (sigue al wallpaper).
Singleton {
  readonly property string sans: Theme.fontSans
  readonly property string icons: Theme.iconFont

  readonly property int colWidth: 340
  readonly property int gap: 14
  readonly property int margin: 28
  readonly property int cardRadius: 26
  readonly property int pad: 20

  // Vidrio de tarjeta: más translúcido que los popups (hay que ver el wallpaper), borde fino arriba más claro
  readonly property color card: Qt.alpha(Theme.background, 0.76)
  readonly property color cardEdge: Qt.alpha(Theme.foreground, 0.12)
  readonly property color cardEdgeHover: Qt.alpha(Theme.foreground, 0.22)
  readonly property color tile: Qt.alpha(Theme.foreground, 0.07)        // celdas dentro de una tarjeta
  readonly property color tileHover: Qt.alpha(Theme.foreground, 0.13)
  readonly property color text: Theme.foreground
  readonly property color textMuted: Qt.alpha(Theme.foreground, 0.78)
  readonly property color textFaint: Qt.alpha(Theme.foreground, 0.64)
  readonly property color onAccent: Theme.background
}
