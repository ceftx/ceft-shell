import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

CCPage {
  id: page
  title: "Perfil"
  subtitle: "Tu avatar y nombre, y presets para guardar y recuperar toda la apariencia"

  readonly property string home: CCStore.home
  property var images: []
  property var presets: []
  property string confirmDel: ""       // id del preset esperando confirmación de borrado
  property string busyPreset: ""
  property string presetError: ""

  function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

  // ── comandos ──
  CCRun {
    id: imgs
    onFinished: (c, out) => page.images = out.split("\n").map(s => s.trim()).filter(s => s.startsWith("/"))
  }
  CCRun {
    id: plist
    onFinished: (c, out) => { try { page.presets = JSON.parse(out) } catch (e) { page.presets = [] } }
  }
  CCRun {
    id: pact
    onFinished: (c, out) => {
      const last = out.trim().split("\n").pop().replace(/^\s*[✓✗!]\s*/, "")
      CCStore.notify(c === 0 ? last : "Falló: " + last, c !== 0)
      page.busyPreset = ""
      if (c !== 0) page.presetError = last
      page.refreshPresets()
    }
  }
  CCRun {
    id: avatarCp
    onFinished: (c, out) => {
      if (c === 0) {
        CCStore.setWidgets(w => { w.profile = Object.assign({}, w.profile ?? ({}), { avatar: "~/.face" }) })
        CCStore.avatarRev++
        CCStore.avatarOk = true
        CCStore.notify("Avatar actualizado", false)
      } else CCStore.notify("No pude copiar la imagen: " + out.trim().split("\n").pop(), true)
    }
  }
  function refreshPresets() { plist.run(CCStore.cli + " preset list --json") }
  Component.onCompleted: {
    refreshPresets()
    imgs.run("find -L " + shq(home + "/Pictures") + " -maxdepth 2 -path " + shq(home + "/Pictures/Screenshots") + " -prune -o -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -print 2>/dev/null | head -40; test -f " + shq(home + "/.face") + " && echo " + shq(home + "/.face"))
  }
  function setAvatar(path) {
    if (path === home + "/.face") { CCStore.notify("Ya es tu avatar actual", false); return }
    avatarCp.run("cp -f " + shq(path) + " " + shq(home + "/.face.tmp") + " && mv -f " + shq(home + "/.face.tmp") + " " + shq(home + "/.face"))
  }
  function savePreset() {
    const n = pname.text.trim()
    if (n === "") { presetError = "Poné un nombre para el preset"; return }
    presetError = ""
    busyPreset = "save"
    pact.run(CCStore.cli + " preset save " + shq(n) + " " + shq(pdesc.text.trim()))
    pname.text = ""; pdesc.text = ""
  }

  // ── Avatar y nombre ──
  CCGroup {
    title: "Tú"
    icon: "account_circle"
    CCRow {
      label: "Nombre visible"
      desc: "Aparece en el menú lateral y en la tarjeta de perfil del escritorio"
      icon: "badge"
      controlWidth: 330
      CCField {
        id: nameField
        Layout.fillWidth: true
        placeholder: Quickshell.env("USER")
        text: String(CCStore.w.profile?.name ?? "")
        onAccepted: page.saveName()
      }
      CCButton { compact: true; primary: true; icon: "check"; label: "Guardar"; onClicked: page.saveName() }
    }
    Item {
      Layout.fillWidth: true
      implicitHeight: acol.implicitHeight + 28
      ColumnLayout {
        id: acol
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 14 }
        spacing: 12
        RowLayout {
          spacing: 14
          Rectangle {
            Layout.preferredWidth: 64; Layout.preferredHeight: 64
            radius: 32
            color: Theme.accentContainer
            CircleImage {
              anchors.fill: parent
              source: CCStore.avatarOk ? "file://" + CCStore.avatarPath + "?v=" + CCStore.avatarRev : ""
              px: 128
            }
            Icon { visible: !CCStore.avatarOk; anchors.centerIn: parent; name: "person"; fill: 1; font.pixelSize: 32; color: Theme.accent }
          }
          ColumnLayout {
            spacing: 2
            Text { text: "Avatar"; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium }
            Text { text: "Elegí una imagen de ~/Pictures: se copia a ~/.face"; color: DeskTheme.textFaint; font.family: Theme.fontSans; font.pixelSize: 12 }
          }
        }
        Flow {
          Layout.fillWidth: true
          spacing: 10
          Repeater {
            model: page.images
            Rectangle {
              id: av
              required property string modelData
              width: 56; height: 56; radius: 28
              color: DeskTheme.tile
              border.width: 2
              border.color: ama.containsMouse ? Theme.accent : "transparent"
              scale: ama.pressed ? 0.94 : 1
              Behavior on scale { NumberAnimation { duration: 90 } }
              Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
              CircleImage { anchors.fill: parent; anchors.margins: 3; source: "file://" + av.modelData; px: 112 }
              MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setAvatar(av.modelData) }
            }
          }
          Text {
            visible: page.images.length === 0 && imgs.done
            text: "No hay imágenes en ~/Pictures. Copiá una ahí o pegá una ruta abajo."
            color: DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 13
          }
        }
        RowLayout {
          spacing: 8
          CCField { id: pathField; Layout.preferredWidth: 320; implicitHeight: 34; icon: "image"; placeholder: "Ruta de otra imagen"; onAccepted: page.fromPath() }
          CCButton { compact: true; icon: "upload"; label: "Usar esta imagen"; enabled: pathField.text.trim() !== ""; onClicked: page.fromPath() }
        }
      }
    }
  }
  function saveName() {
    const n = nameField.text.trim()
    CCStore.setWidgets(w => { w.profile = Object.assign({}, w.profile ?? ({}), { name: n }) })
  }
  function fromPath() {
    const p = pathField.text.trim().replace(/^~/, home)
    if (!p.startsWith("/")) { CCStore.notify("La ruta tiene que ser absoluta o empezar con ~", true); return }
    setAvatar(p); pathField.text = ""
  }

  // ── Presets ──
  CCGroup {
    title: "Presets"
    icon: "bookmarks"
    subtitle: "Guardan tema, wallpaper, ajustes de Hyprland, barra, interfaz y widgets"

    Item {
      Layout.fillWidth: true
      implicitHeight: scol.implicitHeight + 28
      Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18 } height: 1; color: Theme.hairline }
      ColumnLayout {
        id: scol
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 14 }
        spacing: 8
        Text { text: "Guardar la apariencia actual como…"; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium }
        RowLayout {
          spacing: 8
          CCField { id: pname; Layout.preferredWidth: 200; implicitHeight: 36; icon: "bookmark"; placeholder: "Nombre"; onAccepted: pdesc.input.forceActiveFocus() }
          CCField { id: pdesc; Layout.fillWidth: true; implicitHeight: 36; placeholder: "Descripción (opcional)"; onAccepted: page.savePreset() }
          CCButton { primary: true; icon: "save"; label: "Guardar"; busy: page.busyPreset === "save"; onClicked: page.savePreset() }
        }
        Text {
          visible: page.presetError !== ""
          text: page.presetError
          color: Theme.yellow; font.family: Theme.fontSans; font.pixelSize: 13
        }
      }
    }

    Repeater {
      model: page.presets
      CCRow {
        id: pr
        required property var modelData
        required property int index
        label: modelData.name
        desc: (modelData.description !== "" ? modelData.description + " · " : "") + String(modelData.created).slice(0, 10) + (modelData.theme ? " · " + (modelData.theme === "wallpaper" ? "colores del wallpaper" : modelData.theme) : "")
        icon: "bookmark"
        last: index === page.presets.length - 1
        CCButton {
          compact: true; primary: true; icon: "play_arrow"; label: "Aplicar"
          busy: page.busyPreset === "load:" + pr.modelData.id
          enabled: page.busyPreset === ""
          onClicked: { page.confirmDel = ""; page.busyPreset = "load:" + pr.modelData.id; pact.run(CCStore.cli + " preset load " + page.shq(pr.modelData.id)) }
        }
        CCButton {
          compact: true; danger: true
          icon: page.confirmDel === pr.modelData.id ? "delete_forever" : "delete"
          label: page.confirmDel === pr.modelData.id ? "¿Borrar?" : ""
          enabled: page.busyPreset === ""
          onClicked: {
            if (page.confirmDel === pr.modelData.id) { page.confirmDel = ""; page.busyPreset = "del:" + pr.modelData.id; pact.run(CCStore.cli + " preset delete " + page.shq(pr.modelData.id)) }
            else { page.confirmDel = pr.modelData.id; confirmReset.restart() }
          }
        }
      }
    }
    Text {
      visible: page.presets.length === 0
      Layout.fillWidth: true
      Layout.margins: 20
      horizontalAlignment: Text.AlignHCenter
      text: "Todavía no guardaste ningún preset.\nArmá la apariencia que te gusta y guardala con un nombre."
      color: DeskTheme.textMuted; font.family: Theme.fontSans; font.pixelSize: 13
    }
    Timer { id: confirmReset; interval: 3500; onTriggered: page.confirmDel = "" }
  }
}
