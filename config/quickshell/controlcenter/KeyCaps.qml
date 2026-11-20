import QtQuick
import qs

// "$mod + SHIFT + H" -> teclas dibujadas como keycaps.
Row {
  id: kc
  property string keys: ""
  property string mod: "SUPER"
  property bool dimmed: false
  spacing: 4

  function pretty(t) {
    const m = { SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt", Return: "Enter", left: "←", right: "→", up: "↑", down: "↓",
                grave: "`", period: ".", comma: ",", space: "Espacio", mouse_down: "Rueda ↓", mouse_up: "Rueda ↑",
                "mouse:272": "Click izq.", "mouse:273": "Click der.", minus: "-", equal: "=", slash: "/", backslash: "\\",
                semicolon: ";", apostrophe: "'", bracketleft: "[", bracketright: "]", Prior: "Re Pág", Next: "Av Pág", BackSpace: "Retroceso" }
    return m[t] ?? t
  }
  readonly property var tokens: keys === "" ? [] : keys.split("+").map(s => s.trim()).filter(s => s !== "").map(s => s === "$mod" ? mod : s)

  Repeater {
    model: kc.tokens
    Rectangle {
      required property string modelData
      implicitHeight: 26
      implicitWidth: Math.max(26, cap.implicitWidth + 16)
      radius: 8
      color: Qt.alpha(Theme.foreground, 0.09)
      border.width: 1
      border.color: Qt.alpha(Theme.foreground, 0.14)
      opacity: kc.dimmed ? 0.45 : 1
      // borde inferior más marcado = relieve de tecla
      Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 6; rightMargin: 6 } height: 2; radius: 1; color: Qt.alpha(Theme.foreground, 0.16) }
      Text {
        id: cap
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: kc.pretty(modelData)
        color: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: 12
        font.weight: Font.DemiBold
      }
    }
  }
}
