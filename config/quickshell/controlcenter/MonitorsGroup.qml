import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Monitores (hyprctl monitors -j): modo/Hz, escala y posición.
// "Probar" aplica el cambio con `hyprctl eval` y arranca una cuenta de 15 s; si no se confirma con "Mantener" vuelve
// solo al estado anterior. El revert también lo programa un `sh` independiente de Quickshell, así que un cuelgue
// de la interfaz tampoco deja al usuario sin pantalla. Solo "Mantener" escribe overrides.json ("monitors").
CCGroup {
  id: g
  title: "Monitores"
  icon: "monitor"
  subtitle: "Probá un cambio: tenés 15 segundos para confirmarlo, si no vuelve solo"
  resettable: CCStore.isSet("monitors")
  onResetClicked: { CCStore.resetOver(["monitors"]); g.drafts = ({}) ; g.refresh() }

  readonly property string flag: Quickshell.env("XDG_RUNTIME_DIR") + "/ceft-monitor-keep"
  property var monitors: []
  property var drafts: ({})           // nombre -> { mode, x, y, scale } (lo que el usuario eligió, sin aplicar)
  property var test: null             // { name, prev: {mode,x,y,scale}, next: {...} } mientras corre la prueba
  property int secsLeft: 0
  readonly property bool testing: test !== null

  function hzStr(hz) { return String(Number(Number(hz).toFixed(2))) }
  function modeKey(w, h, hz) { return w + "x" + h + "@" + hzStr(hz) }
  function parseModes(list) {
    const seen = {}, out = []
    for (const m of list) {
      const mm = String(m).match(/^(\d+)x(\d+)@([\d.]+)/)
      if (!mm) continue
      const k = modeKey(mm[1], mm[2], mm[3])
      if (seen[k]) continue
      seen[k] = true
      out.push({ v: k, l: mm[1] + "x" + mm[2] + "  ·  " + hzStr(mm[3]) + " Hz", area: Number(mm[1]) * Number(mm[2]), hz: Number(mm[3]) })
    }
    out.sort((a, b) => b.area - a.area || b.hz - a.hz)
    return out
  }

  function refresh() { mons.run("hyprctl monitors -j") }
  Component.onCompleted: refresh()
  CCRun {
    id: mons
    onFinished: (c, out) => {
      try {
        const arr = JSON.parse(out)
        g.monitors = arr.filter(m => !m.disabled).map(m => ({
          name: m.name, desc: m.description ?? "", w: m.width, h: m.height, hz: m.refreshRate,
          x: m.x, y: m.y, scale: m.scale, modes: g.parseModes(m.availableModes ?? [])
        }))
      } catch (e) { g.monitors = [] }
    }
  }
  CCRun { id: act }

  function cur(m) { return { mode: modeKey(m.w, m.h, m.hz), x: m.x, y: m.y, scale: Number(Number(m.scale).toFixed(2)) } }
  function want(m) { return Object.assign({}, cur(m), drafts[m.name] ?? {}) }
  function changed(m) { const a = cur(m), b = want(m); return a.mode !== b.mode || a.x !== b.x || a.y !== b.y || a.scale !== b.scale }
  function setDraft(name, key, val) {
    const d = Object.assign({}, drafts)
    d[name] = Object.assign({}, d[name] ?? {}, { [key]: val })
    drafts = d
  }
  function lua(name, s) {
    return 'hl.monitor({output="' + name + '", mode="' + s.mode + '", position="' + s.x + 'x' + s.y + '", scale=' + s.scale + '})'
  }
  function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

  function startTest(m) {
    if (testing) return
    const prev = cur(m), next = want(m)
    g.test = { name: m.name, prev: prev, next: next }
    g.secsLeft = 15
    // revert independiente de Quickshell (17 s), cancelado por el archivo-bandera de "Mantener"
    act.run("rm -f " + shq(flag) + "; hyprctl eval " + shq(lua(m.name, next)) +
            "; setsid -f sh -c " + shq("sleep 17; [ -f " + shq(flag) + " ] || hyprctl eval " + shq(lua(m.name, prev))) + " >/dev/null 2>&1")
    tick.restart()
  }
  function keep() {
    if (!test) return
    tick.stop()
    const t = test
    act.run("touch " + shq(flag))
    // upsert en overrides.json
    const list = (CCStore.over.monitors ?? []).filter(e => e.output !== t.name)
    list.push({ output: t.name, mode: t.next.mode, position: t.next.x + "x" + t.next.y, scale: t.next.scale })
    CCStore.setOver("monitors", list)
    g.test = null
    const d = Object.assign({}, drafts); delete d[t.name]; drafts = d
    CCStore.notify("Monitor guardado: " + t.name, false)
    refreshLater.restart()
  }
  function revert(auto) {
    if (!test) return
    tick.stop()
    const t = test
    act.run("hyprctl eval " + shq(lua(t.name, t.prev)) + "; touch " + shq(flag))
    g.test = null
    CCStore.notify(auto ? "Sin confirmar: volví a la configuración anterior" : "Cambio descartado", auto)
    refreshLater.restart()
  }
  Timer { id: refreshLater; interval: 1500; onTriggered: g.refresh() }
  Timer {
    id: tick
    interval: 1000; repeat: true
    onTriggered: { g.secsLeft -= 1; if (g.secsLeft <= 0) g.revert(true) }
  }

  // ── aviso ¿Mantener? ──
  Rectangle {
    visible: g.testing
    Layout.fillWidth: true
    Layout.margins: 12
    implicitHeight: kcol.implicitHeight + 24
    radius: 16
    color: Qt.alpha(Theme.yellow, 0.14)
    border.width: 1
    border.color: Qt.alpha(Theme.yellow, 0.6)
    ColumnLayout {
      id: kcol
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 16 }
      spacing: 10
      RowLayout {
        spacing: 10
        Icon { name: "timer"; fill: 1; font.pixelSize: 24; color: Theme.yellow }
        ColumnLayout {
          spacing: 1
          Text { text: "¿Mantener esta configuración?"; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 15; font.weight: Font.DemiBold }
          Text {
            text: "Si no confirmás, vuelve sola en " + g.secsLeft + " s"
            color: DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 12
          }
        }
        Item { Layout.fillWidth: true }
        CCButton { compact: true; icon: "undo"; label: "Revertir"; onClicked: g.revert(false) }
        CCButton { compact: true; primary: true; icon: "check"; label: "Mantener"; onClicked: g.keep() }
      }
      Rectangle {
        Layout.fillWidth: true
        height: 4; radius: 2
        color: Qt.alpha(Theme.foreground, 0.12)
        Rectangle {
          height: parent.height; radius: 2
          color: Theme.yellow
          width: parent.width * Math.max(0, g.secsLeft) / 15
          Behavior on width { NumberAnimation { duration: 950 } }
        }
      }
    }
  }

  // ── un bloque por monitor ──
  Repeater {
    model: g.monitors
    Item {
      id: mb
      required property var modelData
      required property int index
      readonly property var w: g.want(modelData)
      readonly property bool dirty: g.changed(modelData)
      readonly property bool thisTest: g.testing && g.test.name === modelData.name
      Layout.fillWidth: true
      implicitHeight: mcol.implicitHeight + 28

      Rectangle {
        visible: mb.index < g.monitors.length - 1
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18 }
        height: 1; color: Theme.hairline
      }
      ColumnLayout {
        id: mcol
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 14 }
        spacing: 10

        RowLayout {
          spacing: 10
          Icon { name: "desktop_windows"; font.pixelSize: 24; color: Theme.accent; fill: 1 }
          ColumnLayout {
            spacing: 1
            Text { text: mb.modelData.name; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text {
              text: mb.modelData.desc + "  ·  actual " + mb.modelData.w + "x" + mb.modelData.h + " @ " + g.hzStr(mb.modelData.hz) + " Hz"
              color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12
              elide: Text.ElideRight
            }
          }
          Item { Layout.fillWidth: true }
          Rectangle { visible: mb.dirty && !mb.thisTest; width: 7; height: 7; radius: 4; color: Theme.accent }
          CCButton {
            compact: true; icon: "undo"; label: "Descartar"
            visible: mb.dirty && !g.testing
            onClicked: { const d = Object.assign({}, g.drafts); delete d[mb.modelData.name]; g.drafts = d }
          }
          CCButton {
            compact: true; primary: true; icon: "play_arrow"; label: "Probar"
            enabled: mb.dirty && !g.testing
            onClicked: g.startTest(mb.modelData)
          }
        }

        Text { text: "Resolución y frecuencia"; color: DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium }
        CCSelect {
          items: mb.modelData.modes
          value: mb.w.mode
          placeholder: mb.w.mode
          maxRows: 6
          enabled: !g.testing
          onPicked: v => g.setDraft(mb.modelData.name, "mode", v)
        }

        RowLayout {
          spacing: 12
          Text { text: "Escala"; color: DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium; Layout.preferredWidth: 52 }
          Repeater {
            model: [1, 1.25, 1.5, 1.75, 2]
            CCChip {
              required property real modelData
              label: modelData + "×"
              selected: Math.abs(mb.w.scale - modelData) < 0.01
              enabled: !g.testing
              onClicked: g.setDraft(mb.modelData.name, "scale", modelData)
            }
          }
          Item { Layout.fillWidth: true }
        }
        RowLayout {
          spacing: 12
          Text { text: "Posición"; color: DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium; Layout.preferredWidth: 52 }
          Text { text: "X"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12 }
          CCField {
            id: fx
            implicitWidth: 96; implicitHeight: 34
            text: String(mb.w.x)
            enabled: !g.testing
            onAccepted: g.commitPos(mb.modelData.name, fx.text, fy.text)
            input.onActiveFocusChanged: if (!input.activeFocus) g.commitPos(mb.modelData.name, fx.text, fy.text)
          }
          Text { text: "Y"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12 }
          CCField {
            id: fy
            implicitWidth: 96; implicitHeight: 34
            text: String(mb.w.y)
            enabled: !g.testing
            onAccepted: g.commitPos(mb.modelData.name, fx.text, fy.text)
            input.onActiveFocusChanged: if (!input.activeFocus) g.commitPos(mb.modelData.name, fx.text, fy.text)
          }
          Text { text: "px  ·  0x0 es la esquina de arriba a la izquierda"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12 }
        }
      }
    }
  }

  function commitPos(name, xs, ys) {
    const x = parseInt(xs), y = parseInt(ys)
    if (isNaN(x) || isNaN(y)) return
    const m = monitors.find(k => k.name === name)
    if (!m) return
    const w = want(m)
    if (w.x !== x) setDraft(name, "x", x)
    if (w.y !== y) setDraft(name, "y", y)
  }

  Text {
    visible: g.monitors.length === 0
    Layout.margins: 18
    text: "No pude leer los monitores (hyprctl monitors -j)."
    color: DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 13
  }
}
