.pragma library
// Búsqueda difusa liviana: exacto > prefijo > inicio de palabra > subcadena > subsecuencia.

function norm(s) { return String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "") }

function isBoundary(t, i) { return i === 0 || " -_./".indexOf(t[i - 1]) >= 0 }

function field(q, t, allowSeq) {
  if (!t) return 0
  if (t === q) return 1000
  if (t.indexOf(q) === 0) return 850 - Math.min(100, t.length - q.length)
  var idx = t.indexOf(q)
  while (idx >= 0) {
    if (isBoundary(t, idx)) return 700 - Math.min(idx, 100)
    idx = t.indexOf(q, idx + 1)
  }
  idx = t.indexOf(q)
  if (idx >= 0) return 450 - Math.min(idx, 100)
  if (!allowSeq || q.length < 2) return 0
  // subsecuencia: se prueba cada posición donde aparece la primera letra (textos largos)
  var best = 0
  var start = t.indexOf(q[0])
  var tries = 0
  while (start >= 0 && tries < 40) {
    tries++
    var ti = start, sc = 0, run = 0, last = -2, first = -1, ok = true
    for (var qi = 0; qi < q.length; qi++) {
      var pos = t.indexOf(q[qi], ti)
      if (pos < 0) return best
      if (first < 0) first = pos
      run = pos === last + 1 ? run + 1 : 0
      sc += 10 + run * 8 + (isBoundary(t, pos) ? 15 : 0)
      last = pos; ti = pos + 1
    }
    if (last - first <= q.length * 2 + 2) {
      var v = Math.max(1, Math.min(300, sc) - (t.length - q.length) * 0.5)
      if (v > best) best = v
    }
    start = t.indexOf(q[0], start + 1)
  }
  return best
}

// it: { n, g, k, c, d } ya normalizados; tokens: consultas normalizadas
function scoreApp(tokens, it) {
  var total = 0
  for (var i = 0; i < tokens.length; i++) {
    var q = tokens[i]
    var best = Math.max(
      field(q, it.n, true),
      field(q, it.g, true) * 0.6,
      field(q, it.k, false) * 0.5,
      field(q, it.c, false) * 0.45,
      it.d && it.d.indexOf(q) >= 0 ? 90 : 0)
    if (best <= 0) return 0
    total += best
  }
  return total
}

function scoreText(tokens, text) {
  var total = 0
  for (var i = 0; i < tokens.length; i++) {
    var b = field(tokens[i], text, true)
    if (b <= 0) return 0
    total += b
  }
  return total
}
