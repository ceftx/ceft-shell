import QtQuick

// Separador entre módulos / módulo "divider". Estilo (bar.json divider): dots (línea punteada) · line (filo vertical) · space.
Item {
  id: root
  property bool vertical: false
  readonly property string kind: BarConfig.divider
  property bool auto: false     // separador automático del centro (el módulo "divider" explícito es auto: false)
  property bool blank: false    // reserva el ancho pero no dibuja (lado vacío del centro, para mantener la simetría)
  // Con cajas (groupBackground / islands) los grupos ya se separan solos: solo un hueco de 8 px
  readonly property bool boxed: BarConfig.style === "islands" || Theme.groupAlpha > 0
  readonly property bool marks: !blank && !(auto && boxed)
  // Ancho total: con "dots" es el de la barra de siempre (64 px de hueco entre grupos del centro)
  implicitWidth: vertical ? 24 : auto && boxed ? 8 : kind === "dots" ? 64 : kind === "line" ? 28 : 32
  implicitHeight: vertical ? (auto && boxed ? 8 : kind === "dots" ? 36 : kind === "line" ? 20 : 24) : Theme.barH - 12

  DottedLine {
    visible: root.marks && root.kind === "dots"
    anchors { left: parent.left; right: parent.right; leftMargin: root.vertical ? 2 : 8; rightMargin: root.vertical ? 2 : 8; verticalCenter: parent.verticalCenter }
  }
  Rectangle {
    visible: root.marks && root.kind === "line"
    anchors.centerIn: parent
    width: root.vertical ? 16 : 1; height: root.vertical ? 1 : 16
    color: Theme.muted; opacity: 0.55
  }
}
