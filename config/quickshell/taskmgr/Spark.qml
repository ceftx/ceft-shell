import QtQuick
import qs

// Gráfica de historial: values (y values2 opcional) en el rango 0..max (max <= 0 = auto).
Canvas {
  id: c
  property var values: []
  property var values2: []
  property real max: 100
  property color color: Theme.accent
  property color color2: Theme.green
  property int slots: 60
  property bool grid: true
  readonly property real limit: {
    if (max > 0) return max
    let m = 1
    for (const v of values) if (v > m) m = v
    for (const v of values2) if (v > m) m = v
    return m * 1.15
  }
  onValuesChanged: requestPaint()
  onValues2Changed: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onColorChanged: requestPaint()

  function draw(ctx, vals, col) {
    if (!vals || vals.length < 2) return
    const w = width, h = height, step = w / (slots - 1)
    const x0 = w - (vals.length - 1) * step
    ctx.beginPath()
    for (let i = 0; i < vals.length; i++) {
      const x = x0 + i * step, y = h - Math.min(1, vals[i] / limit) * (h - 2) - 1
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
    }
    ctx.strokeStyle = col; ctx.lineWidth = 1.6; ctx.lineJoin = "round"; ctx.stroke()
    ctx.lineTo(w, h); ctx.lineTo(x0, h); ctx.closePath()
    ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.16); ctx.fill()
  }

  onPaint: {
    const ctx = getContext("2d")
    ctx.reset()
    if (grid) {
      ctx.strokeStyle = Qt.alpha(Theme.foreground, 0.08); ctx.lineWidth = 1
      for (let i = 1; i < 4; i++) { const y = Math.round(height * i / 4) + 0.5; ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke() }
    }
    draw(ctx, values, color)
    draw(ctx, values2, color2)
  }
}
