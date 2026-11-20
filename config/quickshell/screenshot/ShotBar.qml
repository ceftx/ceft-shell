import QtQuick
import qs

// Barra flotante de opciones (tras elegir la zona).
Item {
  id: bar
  property var shot            // Screenshot (estado y avisos)
  property string hintText: ""
  signal pick(string action)

  implicitWidth: card.width
  implicitHeight: card.height + 10 + hintPill.height

  Rectangle {
    id: card
    width: row.implicitWidth + 16
    height: 56
    radius: Theme.radius
    color: Qt.alpha(Theme.background, 0.94)
    border.width: Theme.borderWidth
    border.color: Theme.glassEdge

    Row {
      id: row
      anchors.centerIn: parent
      spacing: 2
      ShotButton { icon: "content_copy"; label: "Copiar"; key: "C"; hint: "Copia la imagen y la guarda en la carpeta de capturas"; primary: bar.shot.defAction === "copy"; onActivated: bar.pick("copy"); onHoverChanged: (over) => bar.hintText = over ? hint : "" }
      ShotButton { icon: "download"; label: "Guardar"; key: "S"; hint: "Guarda el PNG en la carpeta de capturas"; onActivated: bar.pick("save"); onHoverChanged: (over) => bar.hintText = over ? hint : "" }
      ShotButton { icon: "draw"; label: "Editar"; key: "E"; hint: "Abre satty para anotar (Enter dentro de satty copia y guarda)"; primary: bar.shot.defAction === "edit"; available: bar.shot.hasSatty; onActivated: bar.pick("edit"); onHoverChanged: (over) => bar.hintText = over ? (available ? hint : "Instalá satty para anotar capturas") : "" }
      Sep {}
      ShotButton { icon: "text_fields"; label: "Texto"; key: "O"; hint: "OCR (español + inglés): el texto va al portapapeles"; available: bar.shot.hasOcr; onActivated: bar.pick("ocr"); onHoverChanged: (over) => bar.hintText = over ? (available ? hint : bar.shot.ocrMissing) : "" }
      ShotButton { icon: "qr_code_scanner"; label: "QR"; key: "Q"; hint: "Decodifica el código QR / de barras al portapapeles"; available: bar.shot.hasQr; onActivated: bar.pick("qr"); onHoverChanged: (over) => bar.hintText = over ? (available ? hint : "QR no disponible: instalá zxing-cpp") : "" }
      Sep {}
      ShotButton { icon: "videocam"; label: "Grabar"; key: "R"; hint: "Graba esta zona (misma tecla de grabación para parar)"; onActivated: bar.pick("rec"); onHoverChanged: (over) => bar.hintText = over ? hint : "" }
      ShotButton { icon: "mic"; label: "Con audio"; key: "⇧R"; hint: "Graba esta zona con el audio del sistema"; onActivated: bar.pick("recaudio"); onHoverChanged: (over) => bar.hintText = over ? hint : "" }
      Sep {}
      ShotButton { icon: "fullscreen"; label: "Pantalla"; key: "F"; hint: "Selecciona el monitor entero"; onActivated: bar.pick("full"); onHoverChanged: (over) => bar.hintText = over ? hint : "" }
      ShotButton { icon: "close"; label: ""; key: "Esc"; hint: "Cancelar"; onActivated: bar.pick("cancel"); onHoverChanged: (over) => bar.hintText = over ? hint : "" }
    }
  }

  // línea de ayuda / aviso bajo la barra
  Rectangle {
    id: hintPill
    anchors { top: card.bottom; topMargin: 10; horizontalCenter: card.horizontalCenter }
    width: ht.implicitWidth + 24
    height: 28
    radius: 14
    color: Qt.alpha(Theme.background, 0.88)
    border.width: 1; border.color: Theme.glassEdge
    Text {
      id: ht
      anchors.centerIn: parent
      text: bar.hintText !== "" ? bar.hintText
          : (bar.shot.defAction === "edit" ? "Enter edita  ·  C copia  ·  arrastrá para mover o redimensionar  ·  clic derecho vuelve a elegir" : "Enter copia  ·  arrastrá para mover o redimensionar  ·  clic derecho vuelve a elegir")
      color: bar.hintText !== "" && bar.hintText.indexOf("Instalá") >= 0 ? Theme.yellow : Theme.muted
      font.family: Theme.fontSans
      font.pixelSize: 12
    }
  }

  component Sep: Item { width: 13; height: 40; Rectangle { width: 1; height: 24; anchors.centerIn: parent; color: Theme.hairline } }
}
