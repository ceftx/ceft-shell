import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Módulo "agent" estilo Omarchy: tokens de Claude Code gastados hoy.
// Click izquierdo: panel con desglose. Click derecho: refrescar.
BarText {
  id: root
  required property var barWindow
  property bool vertical: false    // barra vertical: solo el % de sesión, debajo del ícono

  // Varias cuentas (~/.claude y ~/.claude-*): datos de todas + la seleccionada
  property var usageAll: null
  property var limitsAll: null
  property string selEmail: ""
  readonly property var accounts: (limitsAll ? limitsAll.accounts : usageAll ? usageAll.accounts : []).map(a => a.email)
  readonly property string curEmail: accounts.indexOf(selEmail) >= 0 ? selEmail : (accounts[0] ?? "")
  readonly property var usage: usageAll ? usageAll.accounts.find(a => a.email === curEmail) ?? null : null
  readonly property var limits: limitsAll ? limitsAll.accounts.find(a => a.email === curEmail) ?? null : null
  readonly property real total: usage ? usage.today.total : 0

  function fmt(n) {
    if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
    if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(1) + "k"
    return String(n)
  }
  function refresh() { if (!proc.running) proc.running = true }
  function refreshLimits() { if (!limitsProc.running) limitsProc.running = true }

  // ── Límites del plan (sesión 5 h / semanal) ──
  property real now: Date.now()
  function limitOf(acc, kind) { return acc ? acc.limits.find(l => l.kind === kind) ?? null : null }
  function limit(kind) { return limitOf(limits, kind) }
  function limitColor(l) {
    if (!l) return Theme.dim
    if (l.severity !== "normal" || l.percent >= 90) return Theme.active
    if (l.percent >= 70) return Theme.yellow
    return Theme.green
  }
  function countdown(iso) {
    if (!iso) return ""
    const s = Math.max(0, (Date.parse(iso) - now) / 1000)
    const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`
  }
  function resetTime(iso) {
    if (!iso) return ""
    const t = new Date(iso), today = new Date(now)
    return t.toDateString() === today.toDateString()
      ? Qt.formatDateTime(t, "HH:mm")
      : ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"][t.getDay()] + " " + Qt.formatDateTime(t, "d, HH:mm")
  }
  readonly property var session: limit("session")
  readonly property var weekly: limit("weekly_all")

  // Barra: "% sesión · % semanal" por cuenta (con inicial si hay varias)
  function accText(acc) {
    const se = limitOf(acc, "session"), we = limitOf(acc, "weekly_all")
    if (vertical) return se ? `${se.percent}%` : "–"
    const pre = limitsAll.accounts.length > 1 ? acc.label.charAt(0).toUpperCase() + " " : ""
    return pre + (se ? `${se.percent}% · ${we ? we.percent : "?"}%` : "–")
  }
  function accColor(acc) {
    const se = limitOf(acc, "session"), we = limitOf(acc, "weekly_all")
    if (!se) return Theme.dim
    return limitColor(we && we.percent > se.percent ? we : se)
  }
  symbol: true
  text: Theme.sym("smart_toy")   // los textos van en accRow
  lit: popup.open
  color: popup.open ? Theme.accent : Theme.foreground
  rightPadding: vertical ? 0 : accRow.width + 6
  bottomPadding: vertical ? accRow.height + 1 : 0
  Grid {
    id: accRow
    anchors { right: root.vertical ? undefined : parent.right; horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
              bottom: root.vertical ? parent.bottom : undefined; verticalCenter: root.vertical ? undefined : parent.verticalCenter }
    columns: root.vertical ? 1 : 10
    horizontalItemAlignment: Grid.AlignHCenter
    spacing: root.vertical ? 0 : 10
    Repeater {
      model: root.limitsAll ? root.limitsAll.accounts : []
      Text {
        required property var modelData
        text: root.accText(modelData)
        color: popup.open ? Theme.accent : root.accColor(modelData)
        font.family: Theme.font
        font.pixelSize: root.vertical ? Theme.fontSmall : Theme.fontSmall + 1
        font.bold: root.limitsAll.accounts.length > 1 && modelData.email === root.curEmail
      }
    }
    Text {
      visible: !root.limitsAll
      text: root.usage ? root.fmt(root.total) : "…"
      color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: root.vertical ? 9 : Theme.fontSmall + 1
    }
  }

  onClicked: mouse => {
    if (mouse.button === Qt.RightButton) { refresh(); refreshLimits() }
    else { PopupState.toggle("agent"); if (popup.open) { now = Date.now(); refresh() } }
  }

  Process {
    id: proc
    command: ["python3", "-I", Quickshell.shellDir + "/scripts/agent-usage.py"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.usageAll = JSON.parse(text) } catch (e) {} }
    }
  }
  Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { root.now = Date.now(); root.refresh() } }

  Process {
    id: limitsProc
    command: ["python3", "-I", Quickshell.shellDir + "/scripts/agent-limits.py"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.limitsAll = JSON.parse(text) } catch (e) {} }
    }
  }
  // API interna: no la machacamos, cada 10 min (click derecho fuerza)
  Timer { interval: 600000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshLimits() }

  BarPopup {
    id: popup
    name: "agent"
    barWindow: root.barWindow
    anchorItem: root
    panelWidth: 320

    Item {
      Layout.fillWidth: true
      implicitHeight: content.implicitHeight
      ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right }
        spacing: 6

        component Row2: RowLayout {
          property string label
          property string value
          property color valueColor: Theme.foreground
          Layout.fillWidth: true
          Text { text: label; color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase }
          Item { Layout.fillWidth: true }
          Text { text: value; color: valueColor; font.family: Theme.font; font.pixelSize: Theme.fontBase }
        }

        // ── Selector de cuenta (solo si hay más de una) ──
        RowLayout {
          visible: root.accounts.length > 1
          Layout.fillWidth: true
          spacing: 4
          Repeater {
            model: root.limitsAll ? root.limitsAll.accounts : []
            Rectangle {
              required property var modelData
              readonly property bool sel: modelData.email === root.curEmail
              Layout.fillWidth: true
              implicitHeight: 40
              radius: Theme.radiusSmall
              color: sel ? Qt.alpha(Theme.accent, 0.18) : tabArea.containsMouse ? Theme.hover : "transparent"
              border.color: sel ? Theme.accent : Theme.glassEdge
              Column {
                anchors.centerIn: parent
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.label
                  color: sel ? Theme.accent : Theme.foreground
                  font.family: Theme.fontSans; font.pixelSize: Theme.fontBase; font.bold: sel
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.email
                  color: Theme.dim
                  font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
                }
              }
              MouseArea { id: tabArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selEmail = modelData.email }
            }
          }
        }

        // ── Límites del plan ──
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Límites del plan"
            color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase + 1; font.bold: true
          }
          Item { Layout.fillWidth: true }
          Text {
            visible: !!root.limits && !!root.limits.plan
            text: root.limits ? `${root.limits.plan} · ${root.limits.tier}` : ""
            color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
          }
        }
        Text {
          visible: !root.limits || root.limits.limits.length === 0
          text: root.limits && root.limits.error ? "Sin datos (" + root.limits.error + ")" : "Cargando…"
          color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
        }
        Repeater {
          model: root.limits ? root.limits.limits : []
          ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
              Layout.fillWidth: true
              Text { text: modelData.label; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase }
              Item { Layout.fillWidth: true }
              Text {
                text: `${modelData.percent}% usado`
                color: root.limitColor(modelData); font.family: Theme.fontSans; font.pixelSize: Theme.fontBase; font.bold: true
              }
            }
            Rectangle {   // barra de progreso
              Layout.fillWidth: true
              implicitHeight: 6
              radius: 3
              color: Qt.alpha(Theme.foreground, 0.12)
              Rectangle {
                width: parent.width * Math.min(100, modelData.percent) / 100
                height: parent.height
                radius: 3
                color: root.limitColor(modelData)
              }
            }
            Text {
              text: `quedan ${100 - modelData.percent}% · reinicia ${root.resetTime(modelData.resets_at)} (en ${root.countdown(modelData.resets_at)})`
              color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
            }
          }
        }
        Text {
          visible: !!root.limits && !!root.limits.stale && root.limits.limits.length > 0
          text: "⚠ datos en caché (" + (root.limits ? root.limits.error : "") + ")"
          color: Theme.yellow; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
        Text {
          text: "Tokens · hoy"
          color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase + 1; font.bold: true
        }
        Row2 { label: "Total";           value: root.fmt(root.total); valueColor: Theme.accent }
        Row2 { label: "Entrada";         value: root.usage ? root.fmt(root.usage.today.input) : "-" }
        Row2 { label: "Salida";          value: root.usage ? root.fmt(root.usage.today.output) : "-" }
        Row2 { label: "Caché (lectura)"; value: root.usage ? root.fmt(root.usage.today.cache_read) : "-" }
        Row2 { label: "Caché (escritura)"; value: root.usage ? root.fmt(root.usage.today.cache_write) : "-" }
        Row2 { label: "Sesiones";        value: root.usage ? String(root.usage.sessions) : "-" }

        // ── Desglose por sesión ──
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
        Text {
          visible: root.usage && root.usage.session_details && root.usage.session_details.length > 0
          text: "Por sesión · hoy"
          color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase + 1; font.bold: true
        }
        Repeater {
          model: root.usage && root.usage.session_details ? root.usage.session_details : []
          RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            Text {
              text: (modelData.project ? modelData.project.replace("-home-ceft-", "").replace("-home-ceft-orca-workspaces-", "").replace("-work-crecia-", "") : "?")
              color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
              Layout.preferredWidth: 140
              wrapMode: Text.WordWrap
            }
            Item { Layout.fillWidth: true }
            Text {
              text: root.fmt(modelData.tokens)
              color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Theme.fontBase; font.bold: true
            }
            BarText {
              text: "📂"
              font.pixelSize: Theme.fontBase
              color: Theme.dim
              pill: false
              onClicked: root.barWindow.run("notify-send 'Sesión Claude' '" + modelData.project + " (session: " + modelData.sessionId + ") - Tokens hoy: " + String(root.fmt ? root.fmt(modelData.tokens) : modelData.tokens) + "'")
            }
          }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
        Text { text: "Por modelo"; color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize }
        Repeater {
          model: root.usage ? root.usage.models : []
          Row2 {
            required property var modelData
            label: modelData[0].replace("claude-", "")
            value: root.fmt(modelData[1])
            valueColor: Theme.green
          }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
        Row2 { label: "Últimos 7 días"; value: root.usage ? root.fmt(root.usage.week) : "-" }

        // Mini gráfico de barras por día
        RowLayout {
          id: chart
          Layout.fillWidth: true
          Layout.preferredHeight: 60
          spacing: 6
          readonly property real maxDay: root.usage ? Math.max(1, ...root.usage.days.map(d => d[1])) : 1
          Repeater {
            model: root.usage ? root.usage.days : []
            ColumnLayout {
              required property var modelData
              required property int index
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 2
              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: Math.max(2, parent.height * modelData[1] / chart.maxDay)
                  radius: 2
                  color: index === 6 ? Theme.accent : Theme.dim
                }
              }
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: modelData[0]
                color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
              }
            }
          }
        }

        Text {
          Layout.alignment: Qt.AlignRight
          text: root.usage ? "actualizado " + root.usage.updated + " · click der. refresca" : ""
          color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
        }


      }
    }
  }
}
