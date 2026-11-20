import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// Una capa Overlay por monitor con la captura congelada. El estado (selección, modo) vive en Screenshot.
PanelWindow {
  id: win
  required property var shot
  required property var modelData
  screen: modelData
  readonly property string sname: modelData.name
  readonly property real sw: width
  readonly property real sh: height

  visible: shot.showing
  anchors { top: true; bottom: true; left: true; right: true }
  exclusiveZone: -1
  color: "black"
  WlrLayershell.namespace: "quickshell-screenshot"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: shot.showing && sname === shot.focusName ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  readonly property bool mine: shot.selScreen === sname      // la selección está en este monitor
  readonly property bool hasSel: mine && shot.hasSel
  readonly property bool adjusting: hasSel && shot.stage === "adjust"
  property real mx: -1
  property real my: -1
  property var hover: null                                    // rect de ventana bajo el cursor
  readonly property bool cursorHere: shot.cursorScreen === sname && mx >= 0

  // rectángulo resaltado: selección propia, o la ventana bajo el cursor
  readonly property var focusRect: hasSel ? ({ x: shot.selX, y: shot.selY, w: shot.selW, h: shot.selH })
                                 : (shot.cursorScreen === sname && shot.stage === "pick" ? hover : null)

  onVisibleChanged: if (visible) { scope.forceActiveFocus(); hover = null }

  FocusScope {
    id: scope
    anchors.fill: parent
    focus: true
    Keys.onPressed: event => { shot.key(event); event.accepted = true }

    Image {
      id: frozen
      anchors.fill: parent
      source: shot.showing && shot.files[win.sname] ? "file://" + shot.files[win.sname] : ""
      cache: false
      asynchronous: false
      smooth: false
      fillMode: Image.Stretch
    }

    // ── velo con hueco ──
    Item {
      id: dim
      anchors.fill: parent
      readonly property bool has: win.focusRect !== null
      property real rx: has ? win.focusRect.x : 0
      property real ry: has ? win.focusRect.y : 0
      property real rw: has ? win.focusRect.w : 0
      property real rh: has ? win.focusRect.h : 0
      readonly property color c: Qt.rgba(0, 0, 0, has ? 0.52 : 0.30)
      Behavior on rx { enabled: shot.drag === ""; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
      Behavior on ry { enabled: shot.drag === ""; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
      Behavior on rw { enabled: shot.drag === ""; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
      Behavior on rh { enabled: shot.drag === ""; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
      Rectangle { color: dim.c; x: 0; y: 0; width: parent.width; height: dim.has ? dim.ry : parent.height }
      Rectangle { color: dim.c; visible: dim.has; x: 0; y: dim.ry + dim.rh; width: parent.width; height: parent.height - y }
      Rectangle { color: dim.c; visible: dim.has; x: 0; y: dim.ry; width: dim.rx; height: dim.rh }
      Rectangle { color: dim.c; visible: dim.has; x: dim.rx + dim.rw; y: dim.ry; width: parent.width - x; height: dim.rh }

      // borde / relleno suave
      Rectangle {
        visible: dim.has
        x: dim.rx; y: dim.ry; width: dim.rw; height: dim.rh
        color: win.hasSel ? "transparent" : Qt.alpha(Theme.accent, 0.14)
        border.width: 2
        border.color: Theme.accent
      }
    }

    // ── asas de la selección ──
    Repeater {
      model: win.adjusting ? 8 : 0
      Rectangle {
        required property int index
        readonly property var p: shot.handlePos(index)
        width: 10; height: 10; radius: 3
        x: shot.selX + p.fx * shot.selW - 5
        y: shot.selY + p.fy * shot.selH - 5
        color: Theme.accent
        border.width: 1; border.color: Theme.background
      }
    }

    // ── medidas ──
    Rectangle {
      id: measure
      visible: dim.has && dim.rw > 0
      readonly property string cls: !win.hasSel && win.hover ? (win.hover.class ?? "") : ""
      width: mt.implicitWidth + 16; height: 24; radius: 8
      x: Math.max(4, Math.min(win.width - width - 4, dim.rx))
      y: dim.ry >= height + 8 ? dim.ry - height - 6 : Math.min(win.height - height - 4, dim.ry + 6)
      color: Qt.alpha(Theme.background, 0.92)
      border.width: 1; border.color: Qt.alpha(Theme.accent, 0.6)
      Text {
        id: mt
        anchors.centerIn: parent
        text: Math.round(dim.rw) + " × " + Math.round(dim.rh) + " px" + (measure.cls !== "" ? "  ·  " + measure.cls : "")
        color: Theme.foreground
        font.family: Theme.font
        font.pixelSize: 12
      }
    }

    // ── pista inicial ──
    Rectangle {
      visible: shot.stage === "pick" && win.sname === shot.focusName && shot.drag === "" && win.focusRect === null
      anchors { top: parent.top; topMargin: 28; horizontalCenter: parent.horizontalCenter }
      width: pr.implicitWidth + 32; height: 38; radius: 19
      color: Qt.alpha(Theme.background, 0.92)
      border.width: 1; border.color: Theme.glassEdge
      opacity: shot.drag === "" ? 1 : 0
      Row {
        id: pr
        anchors.centerIn: parent
        spacing: 12
        Text { anchors.verticalCenter: parent.verticalCenter; text: shot.mode === "copy" ? "Captura rápida · se copia al soltar" : "Captura"; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.DemiBold }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "arrastrá una zona o hacé clic en una ventana  ·  F pantalla entera  ·  Esc cancela"; color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: 13 }
      }
    }

    // ── barra de opciones ──
    ShotBar {
      id: obar
      z: 10   // por encima del MouseArea de selección (declarado después): si no, se comían los clics
      visible: win.adjusting && shot.drag === "" && shot.mode !== "copy"
      shot: win.shot
      onPick: action => shot.act(action)
      readonly property real below: shot.selY + shot.selH + 14
      readonly property real above: shot.selY - 14 - height
      x: Math.max(8, Math.min(win.width - width - 8, shot.selX + shot.selW / 2 - width / 2))
      y: below + height <= win.height - 8 ? below : (above >= 8 ? above : Math.max(8, shot.selY + shot.selH - height - 14))
      opacity: visible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    // ── lupa ──
    Item {
      id: loupe
      readonly property int box: 132
      readonly property int zoom: 8
      visible: win.cursorHere && ((shot.stage === "pick" && shot.drag === "") || shot.drag !== "")
      width: box; height: box + 22
      x: win.mx + 24 + box > win.width - 4 ? win.mx - 24 - box : win.mx + 24
      y: win.my + 24 + height > win.height - 4 ? win.my - 24 - height : win.my + 24
      Rectangle {
        id: lbox
        width: loupe.box; height: loupe.box
        color: "black"
        border.width: 2; border.color: Theme.accent
        clip: true
        Image {
          source: frozen.source
          cache: false
          smooth: false
          width: win.width; height: win.height
          transformOrigin: Item.TopLeft
          scale: loupe.zoom
          x: loupe.box / 2 - win.mx * loupe.zoom
          y: loupe.box / 2 - win.my * loupe.zoom
        }
        Rectangle {   // píxel central
          anchors.centerIn: parent
          width: loupe.zoom + 2; height: loupe.zoom + 2
          color: "transparent"; border.width: 1; border.color: "white"
          Rectangle { anchors.fill: parent; anchors.margins: 1; color: "transparent"; border.width: 1; border.color: "black" }
        }
      }
      Rectangle {
        anchors { top: lbox.bottom; left: lbox.left; right: lbox.right }
        height: 22
        color: Qt.alpha(Theme.background, 0.94)
        Text {
          anchors.centerIn: parent
          text: Math.round(win.mx) + ", " + Math.round(win.my)
          color: Theme.foreground; font.family: Theme.font; font.pixelSize: 11
        }
      }
    }

    // ── ratón ──
    MouseArea {
      id: ma
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: shot.stage === "adjust" && win.mine ? shot.cursorFor(mouseX, mouseY) : Qt.CrossCursor
      property real px: 0
      property real py: 0
      property bool moved: false

      onPositionChanged: mouse => {
        win.mx = mouse.x; win.my = mouse.y
        shot.hoverX = mouse.x; shot.hoverY = mouse.y
        shot.cursorScreen = win.sname
        shot.touch()
        if (pressed && shot.drag !== "") {
          if (!moved && Math.abs(mouse.x - px) + Math.abs(mouse.y - py) > 4) moved = true
          if (moved) shot.dragTo(win.sname, win.width, win.height, px, py, mouse.x, mouse.y)
        } else if (shot.stage === "pick") {
          win.hover = shot.windowAt(win.sname, mouse.x, mouse.y)
        }
      }
      onPressed: mouse => {
        shot.touch()
        // clic sobre la barra de opciones: es de los botones, no empieza una selección nueva
        if (obar.visible && mouse.x >= obar.x && mouse.x <= obar.x + obar.width && mouse.y >= obar.y && mouse.y <= obar.y + obar.height) { mouse.accepted = false; return }
        if (mouse.button === Qt.RightButton) { shot.back(); return }
        px = mouse.x; py = mouse.y; moved = false
        shot.beginDrag(win.sname, mouse.x, mouse.y)
      }
      onReleased: mouse => {
        if (mouse.button !== Qt.LeftButton) return
        shot.endDrag(win.sname, moved, win.hover)
      }
      onExited: { win.mx = -1; win.my = -1; if (shot.cursorScreen === win.sname) win.hover = null }
    }
  }
}
