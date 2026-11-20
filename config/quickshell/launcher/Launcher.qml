import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs
import qs.desktop

// Launcher: ventana flotante arriba-centro sobre un velo.
//   qs ipc call launcher toggle | open | close | run | actions | clipboard | query <texto> | accept | move <n> | dump
Scope {
  id: root

  property bool open: false
  property real shown: open ? 1 : 0
  Behavior on shown { NumberAnimation { duration: root.open ? 200 : 140; easing.type: Easing.OutCubic } }
  readonly property bool mapped: open || shown > 0.001
  // Fuente de emojis: la del sistema si existe; si no, Twemoji que trae Firefox
  FontLoader { id: twemoji; source: "file:///usr/lib/firefox/fonts/TwemojiMozilla.ttf" }
  readonly property string emojiFont: Qt.fontFamilies().indexOf("Noto Color Emoji") >= 0 ? "Noto Color Emoji" : (twemoji.status === FontLoader.Ready ? twemoji.name : "Noto Color Emoji")
  readonly property var targetScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

  function show(initial: string): void {
    field.text = initial
    list.currentIndex = 0; grid.currentIndex = 0
    open = true
    search.refreshStatus()
    if (initial.startsWith("$")) search.clipRefresh()
    grid.positionViewAtBeginning()
    focusTimer.restart()
  }

  IpcHandler {
    target: "launcher"
    function open(): void { root.show("") }
    function close(): void { root.open = false }
    function toggle(): void { if (root.open) root.open = false; else root.show("") }
    function run(): void { if (root.open && field.text.startsWith(">")) root.open = false; else root.show(">") }
    function actions(): void { root.show(":") }
    function clipboard(): void { if (root.open && field.text.startsWith("$")) root.open = false; else root.show("$") }
    function clipenv(dir: string): void { search.clipEnv = dir === "" ? ({}) : ({ CLIPHIST: dir + "/cliphist", CLIP_STATE_DIR: dir + "/state", CLIP_CACHE_DIR: dir + "/cache", CLIP_PASTE_CMD: "echo pasted >> " + dir + "/pasted.log", CLIP_NO_WATCH: "1", CLIP_TYPES: "text/plain", CLIP_ACTIVE: "test||" }) }   // solo pruebas
    function emoji(): void { if (root.open && field.text.startsWith(".") && !field.text.startsWith(".g")) root.open = false; else root.show(".") }
    function glyphs(): void { if (root.open && /^\.g(\s|$)/.test(field.text)) root.open = false; else root.show(".g ") }
    function tone(n: int): void { search.setTone(Math.max(0, Math.min(5, n))) }
    function del(): void { root.deleteCurrent() }
    function pin(): void { search.clipPin(search.results[curList.currentIndex], curList.currentIndex) }
    function pause(): void { search.clipTogglePause() }
    function wipe(): void { search.clipWipeClick() }
    function query(text: string): void { if (!root.open) root.show(""); field.text = text }
    function hide(): void { search.hideApp(search.results[curList.currentIndex]) }
    function accept(): void { root.accept(false) }
    function move(n: int): void { root.move(n) }
    function dump(): string { return "[" + field.text + "] " + search.mode + "\n" + search.results.map(r => r.kind + ":" + r.title).join("\n") }
  }

  LSearch {
    id: search
    query: field.text
    onCloseRequested: root.open = false
    onResultsChanged: {
      if (holdIndex >= 0) { curList.currentIndex = Math.min(holdIndex, results.length - 1); holdIndex = -1 }
      else { list.currentIndex = 0; grid.currentIndex = 0; sel = results[0] ?? null; Qt.callLater(root.resetSel); return }
      sel = results[curList.currentIndex] ?? null
    }
  }
  readonly property var groupEs: ({ "Smileys & Emotion": "Caras y emociones", "People & Body": "Personas y cuerpo", "Animals & Nature": "Animales y naturaleza", "Food & Drink": "Comida y bebida", "Travel & Places": "Viajes y lugares", "Activities": "Actividades", "Objects": "Objetos", "Symbols": "Símbolos", "Flags": "Banderas" })
  function codepoints(c) { const o = []; for (const ch of c) o.push("U+" + ch.codePointAt(0).toString(16).toUpperCase()); return o.join(" ") }
  function resetSel() { if (grid.count > 0 && grid.currentIndex < 0) grid.currentIndex = 0; search.sel = search.results[Math.max(0, curList.currentIndex)] ?? null }
  function deleteCurrent() { if (search.mode === "clip") search.clipDelete(search.results[curList.currentIndex], curList.currentIndex) }

  function move(n, clamp) {
    const c = search.results.length
    if (c === 0) return
    search.pending = ""
    if (clamp) { curList.currentIndex = Math.max(0, Math.min(c - 1, curList.currentIndex + n)); return }
    curList.currentIndex = (curList.currentIndex + n + c) % c
  }
  readonly property Item curList: scope.gridOn ? grid : list
  Connections { target: list; function onCurrentIndexChanged() { search.sel = search.results[root.curList.currentIndex] ?? null } }
  Connections { target: grid; function onCurrentIndexChanged() { search.sel = search.results[root.curList.currentIndex] ?? null } }
  function accept(shift) { search.activate(search.results[curList.currentIndex], shift) }

  Timer { id: focusTimer; interval: 30; onTriggered: field.forceActiveFocus() }

  // ── velo ──
  PanelWindow {
    screen: root.targetScreen
    visible: root.mapped
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Qt.rgba(0, 0, 0, 0.26 * root.shown)
    WlrLayershell.namespace: "quickshell-launcher-scrim"
    WlrLayershell.layer: WlrLayer.Top   // debajo de la ventana (Overlay); en la misma capa el velo la tapaba
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.open = false }
  }

  // ── ventana ──
  PanelWindow {
    id: win
    screen: root.targetScreen
    visible: root.mapped
    anchors.top: true
    margins.top: Math.round((root.targetScreen?.height ?? 1080) * 0.15)
    implicitWidth: 700
    implicitHeight: 680
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // click en la zona transparente de la ventana (bajo la tarjeta) también cierra
    MouseArea { anchors.fill: parent; onPressed: root.open = false }

    FocusScope {
      id: scope
      anchors.fill: parent
      focus: true
      opacity: root.shown

      readonly property int rowsH: search.results.reduce((a, r) => a + (r.kind === "calc" ? 88 : 54), 0)
      readonly property bool clip: search.mode === "clip"
      readonly property bool emoji: search.mode === "emoji"
      readonly property bool gridOn: emoji && search.results.length > 0
      readonly property int cols: 11
      readonly property int cell: Math.floor((700 - 16 - 16) / cols)
      readonly property int gridH: gridOn ? Math.min(5, Math.ceil(search.results.length / cols)) * cell + 12 : 0
      readonly property bool showPrev: clip && search.sel !== null && search.sel.kind === "clip"
      readonly property int prevH: showPrev ? 168 : (gridOn ? 96 : 0)
      readonly property int listH: gridOn ? gridH - 12 : Math.min(rowsH, (clip ? 6 : 7) * 54 + 8)
      readonly property bool empty: (search.mode === "apps" && field.text.trim() !== "" || emoji) && search.results.length === 0

      Item {
        id: card
        width: parent.width
        height: 72 + (scope.listH > 0 || scope.empty ? 1 + listWrap.height : 0) + (scope.prevH > 0 ? 1 + prevPane.height : 0) + 1 + 46
        y: (1 - root.shown) * -10
        scale: 0.975 + 0.025 * root.shown
        transformOrigin: Item.Top
        readonly property int listH: scope.empty ? 118 : scope.listH + (scope.listH > 0 ? 12 : 0)

        Rectangle {
          anchors.fill: parent
          radius: 28
          color: Qt.alpha(Theme.background, 0.86)
          border.width: 1
          border.color: Theme.glassEdge
        }

        // ── campo de búsqueda ──
        Item {
          id: head
          width: parent.width; height: 72

          Item {
            id: modeIcon
            width: 28; height: 28
            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
            Icon {
              id: ic
              anchors.centerIn: parent
              readonly property var names: ({ apps: "search", calc: "calculate", cmd: "terminal", act: "bolt", clip: "content_paste", emoji: "mood", hidden: "visibility_off", ai: "deployed_code" })
              name: names[search.mode]
              fill: search.mode === "apps" ? 0 : 1
              font.pixelSize: 26
              color: search.mode === "apps" ? DeskTheme.textMuted : Theme.accent
              Behavior on color { ColorAnimation { duration: Theme.animFast } }
              onNameChanged: pop.restart()
              SequentialAnimation {
                id: pop
                NumberAnimation { target: ic; property: "scale"; to: 0.7; duration: 70 }
                NumberAnimation { target: ic; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
              }
            }
          }

          TextInput {
            id: field
            anchors { left: modeIcon.right; leftMargin: 16; right: modeChip.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            color: Theme.foreground
            selectionColor: Qt.alpha(Theme.accent, 0.45)
            selectedTextColor: Theme.foreground
            font.family: search.mode === "cmd" ? Theme.font : Theme.fontSans
            font.pixelSize: 24
            font.weight: Font.Normal
            clip: true
            focus: true
            selectByMouse: true
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
              const ctrl = event.modifiers & Qt.ControlModifier
              if (event.key === Qt.Key_Escape) { root.open = false; event.accepted = true }
              else if (scope.clip && event.key === Qt.Key_Delete && field.cursorPosition === field.text.length) { root.deleteCurrent(); event.accepted = true }
              else if (scope.clip && ctrl && event.key === Qt.Key_Backspace) { root.deleteCurrent(); event.accepted = true }
              else if (scope.clip && ctrl && event.key === Qt.Key_P) { search.clipPin(search.results[curList.currentIndex], curList.currentIndex); event.accepted = true }
              else if (search.mode === "apps" && ctrl && event.key === Qt.Key_H) { search.hideApp(search.results[curList.currentIndex]); event.accepted = true }
              else if (scope.emoji && ctrl && event.key === Qt.Key_T) { search.cycleTone(); event.accepted = true }
              else if (scope.gridOn && event.key === Qt.Key_Left && scope.gridOn) { root.move(-1, true); event.accepted = true }
              else if (scope.gridOn && event.key === Qt.Key_Right && scope.gridOn) { root.move(1, true); event.accepted = true }
              else if (scope.gridOn && event.key === Qt.Key_Down) { root.move(scope.cols, true); event.accepted = true }
              else if (scope.gridOn && event.key === Qt.Key_Up) { root.move(-scope.cols, true); event.accepted = true }
              else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) { root.move(1); event.accepted = true }
              else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) { root.move(-1); event.accepted = true }
              else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.accept(event.modifiers & Qt.ShiftModifier); event.accepted = true }
              else if (event.key === Qt.Key_PageDown) { root.move(5); event.accepted = true }
              else if (event.key === Qt.Key_PageUp) { root.move(-5); event.accepted = true }
            }
            Text {
              visible: field.text === ""
              anchors.verticalCenter: parent.verticalCenter
              text: search.mode === "clip" ? "Buscar en el historial" : search.mode === "emoji" ? "Buscar emojis" : search.mode === "hidden" ? "Apps ocultas" : search.mode === "ai" ? "AppImages sin registrar" : "Buscar aplicaciones"
              color: DeskTheme.textFaint
              font: field.font
            }
          }

          // etiqueta del modo activo
          Rectangle {
            id: modeChip
            anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
            readonly property var labels: ({ apps: "", calc: "Calculadora", cmd: "Comando", act: "Acciones", clip: "Portapapeles", emoji: "Emojis", hidden: "Apps ocultas", ai: "AppImages" })
            readonly property string label: search.glyphMode ? "Glifos Nerd" : labels[search.mode]
            implicitWidth: label === "" ? 0 : chipText.implicitWidth + 22
            width: implicitWidth
            height: 28
            radius: 14
            color: Theme.accentContainer
            opacity: label === "" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            clip: true
            Text {
              id: chipText
              anchors.centerIn: parent
              text: parent.label
              color: Theme.accent
              font.family: Theme.fontSans
              font.pixelSize: 12
              font.weight: Font.DemiBold
            }
          }
        }

        Rectangle {
          y: 72; x: 20; width: parent.width - 40; height: 1
          color: Theme.hairline
          opacity: card.listH > 0 ? 1 : 0
        }

        // ── resultados ──
        Item {
          id: listWrap
          y: 73
          x: 8
          width: parent.width - 16
          height: card.listH
          clip: true
          Behavior on height { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

          ListView {
            id: list
            visible: !scope.empty && !scope.gridOn
            anchors { fill: parent; topMargin: 6; bottomMargin: 6 }
            model: scope.emoji ? [] : search.results
            property real lastX: -100
            property real lastY: -100
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: false
            highlightMoveDuration: 130
            highlightResizeDuration: 130
            highlightFollowsCurrentItem: true
            highlight: Rectangle {
              width: list.width
              height: list.currentItem ? list.currentItem.height : 54
              radius: 18
              color: Theme.accentContainer
              Rectangle {
                width: 3; height: 22; radius: 2
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                color: Theme.accent
              }
            }
            delegate: LRow {
              selected: ListView.isCurrentItem
              confirming: search.pending !== "" && modelData.id === search.pending
              onHovered: (sx, sy) => {
                // solo movimientos reales: al aparecer/desplazarse bajo el cursor Qt manda hovers sintéticos
                if (Math.abs(sx - list.lastX) + Math.abs(sy - list.lastY) > 2) { list.currentIndex = index; list.lastX = sx; list.lastY = sy }
              }
              onClicked: { list.currentIndex = index; root.accept(false) }
            }
          }


          // grilla de emojis / glifos
          GridView {
            id: grid
            visible: scope.gridOn
            anchors { fill: parent; topMargin: 6; bottomMargin: 6; leftMargin: 8; rightMargin: 8 }
            model: scope.emoji ? search.results : []
            cellWidth: scope.cell
            cellHeight: scope.cell
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 90
            highlightFollowsCurrentItem: true
            cacheBuffer: 0
            property real lastX: -100
            property real lastY: -100
            highlight: Rectangle {
              radius: 12
              color: Theme.accentContainer
              border.width: 1
              border.color: Qt.alpha(Theme.accent, 0.6)
            }
            delegate: Item {
              id: cellItem
              required property var modelData
              required property int index
              width: scope.cell; height: scope.cell
              Text {
                anchors.centerIn: parent
                text: cellItem.modelData.char ?? cellItem.modelData.base
                font.family: cellItem.modelData.glyph ? Theme.font : root.emojiFont
                font.pixelSize: cellItem.modelData.glyph ? 24 : 26
                color: Theme.foreground
                renderType: Text.QtRendering
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => {
                  const p = mapToItem(null, mouse.x, mouse.y)
                  if (Math.abs(p.x - grid.lastX) + Math.abs(p.y - grid.lastY) > 2) { grid.currentIndex = cellItem.index; grid.lastX = p.x; grid.lastY = p.y }
                }
                onClicked: { grid.currentIndex = cellItem.index; root.accept(false) }
              }
            }
          }

          // estado vacío
          Column {
            visible: scope.empty
            anchors.centerIn: parent
            spacing: 6
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: scope.emoji ? "mood_bad" : "search_off"; font.pixelSize: 34; color: DeskTheme.textFaint }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: scope.emoji ? (search.glyphMode ? "Ningún glifo se llama así" : (search.emojiReady ? "Ningún emoji se llama así" : "Cargando emojis…")) : "Nada se llama así"
              color: Theme.foreground
              font.family: Theme.fontSans; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: scope.emoji ? "Probá en español o en inglés: «risa», «fuego», «heart»" + (search.glyphMode ? "" : "   ·   .g para glifos Nerd") : "Probá con otra palabra, o usá  >  para correr «" + field.text.trim() + "»"
              color: DeskTheme.textFaint
              font.family: Theme.fontSans; font.pixelSize: 12
            }
          }
        }


        // ── vista previa (portapapeles) ──
        Item {
          id: prevPane
          y: 73 + listWrap.height + 1
          x: 8
          width: parent.width - 16
          height: scope.prevH
          clip: true
          opacity: scope.prevH > 0 ? 1 : 0
          Behavior on height { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
          readonly property var r: search.sel
          readonly property bool isImg: r !== null && r.kind === "clip" && (r.isImage ?? false)
          readonly property bool ready: r !== null && search.previewId === r.id

          Rectangle {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 8; bottomMargin: 8 }
            radius: 14
            color: Qt.alpha(Theme.foreground, 0.05)
            border.width: 1
            border.color: Theme.hairline


            // vista previa de emoji / glifo
            Item {
              visible: scope.gridOn
              anchors { fill: parent; margins: 10 }
              readonly property var r: search.sel
              readonly property bool ok: r !== null && r.kind === "emoji"
              Rectangle {
                id: bigBox
                width: 76; height: 76; radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Theme.foreground, 0.06)
                Text {
                  anchors.centerIn: parent
                  text: parent.parent.ok ? (parent.parent.r.char ?? parent.parent.r.base) : ""
                  font.family: parent.parent.ok && parent.parent.r.glyph ? Theme.font : root.emojiFont
                  font.pixelSize: 46
                  color: Theme.foreground
                  renderType: Text.QtRendering
                }
              }
              Column {
                anchors { left: bigBox.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 3
                Text {
                  width: parent.width
                  text: parent.parent.ok ? parent.parent.r.title : ""
                  elide: Text.ElideRight
                  color: Theme.foreground
                  font.family: Theme.fontSans; font.pixelSize: 16; font.weight: Font.DemiBold
                }
                Text {
                  width: parent.width
                  text: parent.parent.ok ? parent.parent.r.sub : ""
                  elide: Text.ElideRight
                  color: DeskTheme.textMuted
                  font.family: Theme.fontSans; font.pixelSize: 12
                }
                Text {
                  width: parent.width
                  readonly property var r: parent.parent.r
                  text: !parent.parent.ok || r === null ? "" : (r?.glyph ? "Nerd Font · " + r?.group + " · " : (root.groupEs[r?.group] ?? r?.group) + " · ") + root.codepoints(r?.base ?? "") + (r?.tones ? "   ·   ^T cambia el tono (" + search.toneNames[search.tone].toLowerCase() + ")" : "")
                  elide: Text.ElideRight
                  color: DeskTheme.textFaint
                  font.family: Theme.fontSans; font.pixelSize: 11
                }
              }
            }

            Image {
              visible: prevPane.isImg && source !== ""
              anchors { fill: parent; margins: 10 }
              source: prevPane.isImg && prevPane.r.thumb ? prevPane.r.thumb : ""
              fillMode: Image.PreserveAspectFit
              sourceSize.width: 1200; sourceSize.height: 400
              asynchronous: true
              smooth: true
            }
            Text {
              visible: !prevPane.isImg && !scope.gridOn
              anchors { fill: parent; margins: 12 }
              text: prevPane.ready ? search.previewText.replace(/\s+$/, "") : (prevPane.r ? prevPane.r.title : "")
              textFormat: Text.PlainText
              wrapMode: Text.WrapAtWordBoundaryOrAnywhere
              maximumLineCount: 6
              elide: Text.ElideRight
              color: Theme.foreground
              font.family: Theme.font
              font.pixelSize: 12
              lineHeight: 1.15
            }
            // contador de líneas / caracteres
            Rectangle {
              visible: !prevPane.isImg && prevPane.ready
              anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
              height: 20; radius: 10
              width: cnt.implicitWidth + 16
              color: Qt.alpha(Theme.background, 0.8)
              Text {
                id: cnt
                anchors.centerIn: parent
                readonly property int lines: search.previewText.replace(/\s+$/, "").split("\n").length
                text: lines + (lines === 1 ? " línea" : " líneas") + " · " + search.previewText.length + (search.previewText.length >= 20000 ? "+" : "") + " car."
                color: DeskTheme.textMuted
                font.family: Theme.fontSans; font.pixelSize: 11
              }
            }
          }
        }

        Rectangle {
          y: card.height - 47; x: 20; width: parent.width - 40; height: 1
          color: Theme.hairline
        }

        // ── pie: atajos + prefijos ──
        Item {
          width: parent.width; height: 46
          y: card.height - 46

          Row {
            anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
            spacing: 14
            opacity: noticeBox.visible ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Repeater {
              model: scope.emoji ? [{ k: "↵", t: "pegar" }, { k: "⇧↵", t: "copiar" }, { k: "←↑↓→", t: "mover" }, { k: "^T", t: "tono" }] : scope.clip ? [{ k: "↵", t: "pegar" }, { k: "⇧↵", t: "copiar" }, { k: "Supr", t: "borrar" }, { k: "^P", t: "fijar" }] : search.mode === "apps" ? [{ k: "↑↓", t: "elegir" }, { k: "↵", t: "abrir" }, { k: "^H", t: "ocultar" }, { k: "Esc", t: "cerrar" }] : [{ k: "↑↓", t: "elegir" }, { k: "↵", t: "abrir" }, { k: "Esc", t: "cerrar" }]
              Row {
                required property var modelData
                spacing: 6
                KeyCap { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.k }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: parent.modelData.t
                  color: DeskTheme.textFaint
                  font.family: Theme.fontSans; font.pixelSize: 12
                }
              }
            }
          }

          // aviso temporal (borrado, fijado, pausa...)
          Rectangle {
            id: noticeBox
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            height: 28; radius: 14
            width: noticeText.implicitWidth + 24
            color: Theme.accentContainer
            opacity: search.notice !== "" && (scope.clip || scope.emoji) ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Text { id: noticeText; anchors.centerIn: parent; text: search.notice; color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.DemiBold }
          }

          Row {
            visible: scope.clip
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 4
            Rectangle {
              width: pz.implicitWidth + 18; height: 28; radius: 14
              color: search.clipPaused ? Theme.accentContainer : (pzm.containsMouse ? Theme.hover : "transparent")
              Behavior on color { ColorAnimation { duration: Theme.animFast } }
              Row {
                id: pz
                anchors.centerIn: parent
                spacing: 6
                Icon { anchors.verticalCenter: parent.verticalCenter; name: search.clipPaused ? "play_arrow" : "pause"; fill: 1; font.pixelSize: 16; color: search.clipPaused ? Theme.accent : DeskTheme.textMuted }
                Text { anchors.verticalCenter: parent.verticalCenter; text: search.clipPaused ? "Reanudar" : "Pausar"; color: search.clipPaused ? Theme.accent : DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium }
              }
              MouseArea { id: pzm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { search.clipTogglePause(); field.forceActiveFocus() } }
            }
            Rectangle {
              width: wp.implicitWidth + 18; height: 28; radius: 14
              color: search.wipePending ? Qt.alpha(Theme.active, 0.2) : (wpm.containsMouse ? Theme.hover : "transparent")
              Behavior on color { ColorAnimation { duration: Theme.animFast } }
              Row {
                id: wp
                anchors.centerIn: parent
                spacing: 6
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "delete_sweep"; font.pixelSize: 16; color: search.wipePending ? Theme.active : DeskTheme.textMuted }
                Text { anchors.verticalCenter: parent.verticalCenter; text: search.wipePending ? "¿Seguro? Otro clic" : "Borrar todo"; color: search.wipePending ? Theme.active : DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 12; font.weight: search.wipePending ? Font.DemiBold : Font.Medium }
              }
              MouseArea { id: wpm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { search.clipWipeClick(); field.forceActiveFocus() } }
            }
          }

          Row {
            visible: scope.emoji
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 4
            Repeater {
              model: [{ p: ".", t: "emojis", g: false }, { p: ".g ", t: "glifos", g: true }]
              Rectangle {
                id: ec
                required property var modelData
                readonly property bool on: search.glyphMode === modelData.g
                width: er.implicitWidth + 18; height: 28; radius: 14
                color: on ? Theme.accentContainer : (ema.containsMouse ? Theme.hover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text {
                  id: er
                  anchors.centerIn: parent
                  text: ec.modelData.t
                  color: ec.on ? Theme.accent : DeskTheme.textMuted
                  font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium
                }
                MouseArea { id: ema; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { field.text = ec.modelData.p; field.forceActiveFocus() } }
              }
            }
            Rectangle {
              visible: !search.glyphMode
              width: tn.implicitWidth + 18; height: 28; radius: 14
              color: search.tone > 0 ? Theme.accentContainer : (tma.containsMouse ? Theme.hover : "transparent")
              Behavior on color { ColorAnimation { duration: Theme.animFast } }
              Row {
                id: tn
                anchors.centerIn: parent
                spacing: 6
                Text { anchors.verticalCenter: parent.verticalCenter; text: "✋" + ["", "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}"][search.tone]; font.family: root.emojiFont; font.pixelSize: 14; renderType: Text.QtRendering }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "tono"; color: search.tone > 0 ? Theme.accent : DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium }
              }
              MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { search.cycleTone(); field.forceActiveFocus() } }
            }
          }

          Row {
            visible: !scope.clip && !scope.emoji
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 4
            Repeater {
              model: [{ p: "=", t: "calcular" }, { p: ">", t: "comando" }, { p: ":", t: "acciones" }, { p: "$", t: "portapapeles" }, { p: ".", t: "emojis" }, { p: "!", t: "ocultas" }, { p: "+", t: "AppImage" }]
              Rectangle {
                id: pc
                required property var modelData
                readonly property bool on: field.text.startsWith(modelData.p)
                width: pr.implicitWidth + 18; height: 28; radius: 14
                color: on ? Theme.accentContainer : (pma.containsMouse ? Theme.hover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Row {
                  id: pr
                  anchors.centerIn: parent
                  spacing: 6
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pc.modelData.p
                    color: pc.on ? Theme.accent : Theme.foreground
                    font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Bold
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pc.modelData.t
                    color: pc.on ? Theme.accent : DeskTheme.textMuted
                    font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium
                  }
                }
                MouseArea {
                  id: pma
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { field.text = pc.on ? "" : pc.modelData.p; field.forceActiveFocus() }
                }
              }
            }
          }
        }
      }
    }
  }
}
