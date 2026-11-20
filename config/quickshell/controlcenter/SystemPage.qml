import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

CCPage {
  id: page
  title: "Sistema"
  subtitle: "Versión, estado del entorno, guardado y bloqueo de pantalla"

  property string version: ""
  property var report: []          // [{ kind: head|ok|warn|bad|raw, text }]
  property int warnCount: 0
  property string armed: ""        // acción esperando confirmación
  property string jobName: ""

  CCRun { id: verRun; onFinished: (c, out) => page.version = out.trim() }
  CCRun {
    id: doctor
    onFinished: (c, out) => {
      const rep = []
      let warns = 0
      for (const raw of out.split("\n")) {
        const line = raw.replace(/\x1b\[[0-9;]*m/g, "")
        if (line.trim() === "") continue
        let m
        if ((m = line.match(/^==>\s*(.*)$/))) rep.push({ kind: "head", text: m[1] })
        else if ((m = line.match(/^\s*✓\s*(.*)$/))) rep.push({ kind: "ok", text: m[1] })
        else if ((m = line.match(/^\s*!\s*(.*)$/))) { rep.push({ kind: "warn", text: m[1] }); warns++ }
        else if ((m = line.match(/^\s*✗\s*(.*)$/))) { rep.push({ kind: "bad", text: m[1] }); warns++ }
        else rep.push({ kind: "raw", text: line.trim() })
      }
      page.report = rep; page.warnCount = warns
    }
  }
  CCRun {
    id: job
    onFinished: (c, out) => {
      CCStore.notify(c === 0 ? page.jobName + ": listo" : page.jobName + ": falló (código " + c + ")", c !== 0)
      if (page.jobName === "Guardar" || page.jobName === "Actualizar") doctor.run(CCStore.cli + " doctor")
    }
  }
  CCRun {
    id: idleGet
    onFinished: (c, out) => {
      try {
        const o = JSON.parse(out.trim())
        page.idleLock = o.lock_min; page.idleOff = o.off_min
        page.idleLockNew = o.lock_min; page.idleOffNew = o.off_min
        page.idleAvail = true
      } catch (e) { page.idleAvail = false }
    }
  }
  CCRun {
    id: idleSet
    onFinished: (c, out) => {
      page.idleMsg = out.trim().split("\n").pop().replace(/^\s*[✓✗!]\s*/, "")
      page.idleErr = c !== 0
      if (c === 0) idleGet.run(CCStore.cli + " idle --json")
    }
  }

  property bool idleAvail: true
  property int idleLock: 10
  property int idleOff: 15
  property int idleLockNew: 10
  property int idleOffNew: 15
  property string idleMsg: ""
  property bool idleErr: false
  readonly property bool idleInvalid: idleLockNew > 0 && idleOffNew > 0 && idleOffNew <= idleLockNew
  readonly property bool idleDirty: idleLockNew !== idleLock || idleOffNew !== idleOff

  Component.onCompleted: {
    verRun.run(CCStore.cli + " version")
    doctor.run(CCStore.cli + " doctor")
    idleGet.run(CCStore.cli + " idle --json")
  }

  function runJob(name, args, cmdPrefix) {
    if (job.running) return
    armed = ""
    jobName = name
    job.run((cmdPrefix ?? "") + CCStore.cli + " " + args)
  }
  function arm(name) { armed = name; disarm.restart() }
  Timer { id: disarm; interval: 4000; onTriggered: page.armed = "" }

  // ── Versión ──
  CCGroup {
    title: "ceft-shell"
    icon: "deployed_code"
    Item {
      Layout.fillWidth: true
      implicitHeight: 96
      RowLayout {
        anchors { fill: parent; margins: 20 }
        spacing: 16
        Rectangle {
          Layout.preferredWidth: 56; Layout.preferredHeight: 56
          radius: 18
          color: Theme.accentContainer
          Icon { anchors.centerIn: parent; name: "terminal"; fill: 1; font.pixelSize: 30; color: Theme.accent }
        }
        ColumnLayout {
          spacing: 2
          Text {
            text: "Versión " + (page.version || "…")
            color: Theme.foreground
            font.family: Theme.fontSans
            font.pixelSize: 20
            font.weight: Font.DemiBold
          }
          Text {
            text: "Entorno versionado en ~/ceft-shell"
            color: DeskTheme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 13
          }
        }
        Item { Layout.fillWidth: true }
      }
    }
  }

  // ── Estado ──
  CCGroup {
    title: "Estado"
    icon: "health_and_safety"
    subtitle: doctor.running ? "Revisando…" : (page.warnCount === 0 ? "Todo en orden" : page.warnCount + (page.warnCount === 1 ? " aviso" : " avisos"))
    headerExtra: [
      CCButton { compact: true; icon: "refresh"; label: "Revisar"; busy: doctor.running; onClicked: doctor.run(CCStore.cli + " doctor") }
    ]
    Item {
      Layout.fillWidth: true
      implicitHeight: rep.implicitHeight + 28
      ColumnLayout {
        id: rep
        x: 20; y: 14
        width: parent.width - 40
        spacing: 6
        Text {
          visible: doctor.running && page.report.length === 0
          text: "Corriendo ceft-shell doctor…"
          color: DeskTheme.textMuted
          font.family: Theme.fontSans
          font.pixelSize: 13
        }
        Repeater {
          model: page.report
          RowLayout {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.topMargin: modelData.kind === "head" && index > 0 ? 10 : 0
            spacing: 10
            Icon {
              visible: modelData.kind !== "head" && modelData.kind !== "raw"
              name: modelData.kind === "ok" ? "check_circle" : (modelData.kind === "warn" ? "warning" : "error")
              fill: 1
              font.pixelSize: 18
              color: modelData.kind === "ok" ? Theme.green : (modelData.kind === "warn" ? Theme.yellow : Theme.active)
              Layout.alignment: Qt.AlignTop
            }
            Text {
              Layout.fillWidth: true
              text: modelData.text
              wrapMode: Text.WordWrap
              color: modelData.kind === "head" ? Theme.accent : (modelData.kind === "raw" ? DeskTheme.textFaint : Theme.foreground)
              font.family: modelData.kind === "raw" ? Theme.font : Theme.fontSans
              font.pixelSize: modelData.kind === "head" ? 13 : 13
              font.weight: modelData.kind === "head" ? Font.DemiBold : Font.Normal
              font.capitalization: modelData.kind === "head" ? Font.AllUppercase : Font.MixedCase
              font.letterSpacing: modelData.kind === "head" ? 0.6 : 0
            }
          }
        }
      }
    }
  }

  // ── Acciones ──
  CCGroup {
    title: "Acciones"
    icon: "bolt"
    CCRow {
      label: "Guardar cambios"
      desc: "Hace commit de todo lo modificado en el repo y lo sube (git push)"
      icon: "cloud_upload"
      CCButton {
        icon: page.armed === "Guardar" ? "priority_high" : "save"
        label: page.armed === "Guardar" ? "Confirmar" : "Guardar"
        primary: page.armed === "Guardar"
        busy: job.running && page.jobName === "Guardar"
        enabled: !job.running
        onClicked: page.armed === "Guardar" ? page.runJob("Guardar", "save") : page.arm("Guardar")
      }
    }
    CCRow {
      label: "Actualizar"
      desc: "Trae cambios del repo, enlaza configs, instala paquetes nuevos y recarga"
      icon: "system_update_alt"
      CCButton {
        icon: page.armed === "Actualizar" ? "priority_high" : "download"
        label: page.armed === "Actualizar" ? "Confirmar" : "Actualizar"
        primary: page.armed === "Actualizar"
        busy: job.running && page.jobName === "Actualizar"
        enabled: !job.running
        onClicked: page.armed === "Actualizar" ? page.runJob("Actualizar", "update", "CEFT_YES=1 ") : page.arm("Actualizar")
      }
    }
    CCRow {
      label: "Recargar"
      desc: "Recarga Hyprland y reinicia la barra (esta ventana se cierra)"
      icon: "restart_alt"
      last: true
      CCButton {
        icon: page.armed === "Recargar" ? "priority_high" : "refresh"
        label: page.armed === "Recargar" ? "Confirmar" : "Recargar"
        primary: page.armed === "Recargar"
        enabled: !job.running
        onClicked: page.armed === "Recargar" ? page.runJob("Recargar", "reload") : page.arm("Recargar")
      }
    }
    // consola
    Rectangle {
      visible: job.running || job.done
      Layout.fillWidth: true
      Layout.margins: 14
      Layout.topMargin: 4
      implicitHeight: Math.min(220, logText.implicitHeight + 28)
      radius: 14
      color: Qt.alpha(Theme.background, 0.55)
      border.width: 1
      border.color: job.running ? Qt.alpha(Theme.accent, 0.5) : (job.ok ? Qt.alpha(Theme.green, 0.5) : Qt.alpha(Theme.active, 0.5))
      clip: true
      Text {
        id: logText
        x: 14; y: 14
        width: parent.width - 28
        text: (job.output.trim() || "Ejecutando " + page.jobName + "…").replace(/\x1b\[[0-9;]*m/g, "")
        wrapMode: Text.WrapAnywhere
        color: DeskTheme.textMuted
        font.family: Theme.font
        font.pixelSize: 12
      }
    }
  }

  // ── Bloqueo e inactividad ──
  CCGroup {
    title: "Bloqueo e inactividad"
    icon: "lock_clock"
    subtitle: page.idleAvail ? "hypridle · 0 = nunca" : "No disponible en esta versión de ceft-shell"
    resettable: false
    CCRow {
      visible: page.idleAvail
      label: "Bloquear la sesión"
      desc: "Minutos sin actividad hasta pedir la contraseña"
      icon: "lock"
      controlWidth: 300
      CCSlider {
        Layout.fillWidth: true
        from: 0; to: 60; step: 1; unit: " min"; zeroLabel: "Nunca"
        value: page.idleLockNew
        onCommitted: v => page.idleLockNew = v
      }
    }
    CCRow {
      visible: page.idleAvail
      label: "Apagar la pantalla"
      desc: "Debe ser mayor que el tiempo de bloqueo"
      icon: "desktop_access_disabled"
      controlWidth: 300
      CCSlider {
        Layout.fillWidth: true
        from: 0; to: 120; step: 1; unit: " min"; zeroLabel: "Nunca"
        value: page.idleOffNew
        onCommitted: v => page.idleOffNew = v
      }
    }
    CCRow {
      visible: page.idleAvail
      last: true
      label: page.idleInvalid ? "El apagado debe ser posterior al bloqueo" : (page.idleMsg !== "" ? page.idleMsg : (page.idleDirty ? "Cambios sin aplicar" : "Aplicado"))
      icon: page.idleInvalid || page.idleErr ? "warning" : (page.idleDirty ? "edit" : "check_circle")
      CCButton {
        primary: true; icon: "check"; label: "Aplicar"
        enabled: page.idleDirty && !page.idleInvalid
        busy: idleSet.running
        onClicked: { page.idleMsg = ""; idleSet.run(CCStore.cli + " idle " + page.idleLockNew + " " + page.idleOffNew) }
      }
    }
    Text {
      visible: !page.idleAvail
      Layout.fillWidth: true
      Layout.margins: 18
      text: "Actualizá el repo (ceft-shell update) para tener el comando \"ceft-shell idle\"."
      color: DeskTheme.textMuted
      font.family: Theme.fontSans
      font.pixelSize: 13
      wrapMode: Text.WordWrap
    }
  }
}
