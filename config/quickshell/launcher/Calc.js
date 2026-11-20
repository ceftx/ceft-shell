.pragma library
// Calculadora segura (parser recursivo, sin eval). Soporta + - * / ^ % ( ), constantes y funciones.

var FUNCS = {
  sqrt: Math.sqrt, cbrt: Math.cbrt, sin: Math.sin, cos: Math.cos, tan: Math.tan,
  asin: Math.asin, acos: Math.acos, atan: Math.atan, ln: Math.log, log: Math.log10, log2: Math.log2,
  exp: Math.exp, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil, sign: Math.sign
}
var CONSTS = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI }

function tokenize(src) {
  var s = src.replace(/×/g, "*").replace(/÷/g, "/").replace(/\*\*/g, "^").replace(/(\d),(\d)/g, "$1.$2")
  var out = [], i = 0
  while (i < s.length) {
    var c = s[i]
    if (c === " " || c === "\t") { i++; continue }
    if (/[0-9.]/.test(c)) {
      var m = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(s.slice(i))
      if (!m) return null
      out.push({ t: "n", v: parseFloat(m[0]) }); i += m[0].length; continue
    }
    if (/[a-z]/i.test(c)) {
      // "2x3": una x que no inicia una palabra (ni "x2" como identificador) es multiplicación
      if ((c === "x" || c === "X") && !/[a-z]/i.test(s[i + 1] || "")) { out.push({ t: "o", v: "*" }); i++; continue }
      var w = /^[a-z]+[0-9]*/i.exec(s.slice(i))[0]
      out.push({ t: "i", v: w.toLowerCase() }); i += w.length; continue
    }
    if ("+-*/^%()".indexOf(c) >= 0) { out.push({ t: "o", v: c }); i++; continue }
    return null
  }
  return out
}

function evaluate(src) {
  var tk = tokenize(src)
  if (!tk || tk.length === 0) return null
  var p = 0
  function peek() { return tk[p] }
  function isOp(v) { var t = tk[p]; return t && t.t === "o" && t.v === v }
  function startsOperand(t) { return t && (t.t === "n" || t.t === "i" || (t.t === "o" && (t.v === "(" || t.v === "-" || t.v === "+"))) }
  function fail() { throw "x" }

  function expr() {
    var v = term()
    while (isOp("+") || isOp("-")) { var o = tk[p++].v; var r = term(); v = o === "+" ? v + r : v - r }
    return v
  }
  function term() {
    var v = unary()
    for (;;) {
      if (isOp("*")) { p++; v = v * unary() }
      else if (isOp("/")) { p++; v = v / unary() }
      else if (isOp("%")) {
        var nx = tk[p + 1]
        if (nx && (nx.t === "n" || nx.t === "i" || (nx.t === "o" && nx.v === "("))) { p++; v = v % unary() }
        else { p++; v = v / 100 }
      }
      else if (tk[p] && (tk[p].t === "n" || tk[p].t === "i" || isOp("("))) v = v * unary()   // multiplicación implícita: 2pi, 2(3)
      else break
    }
    return v
  }
  function unary() {
    if (isOp("-")) { p++; return -unary() }
    if (isOp("+")) { p++; return unary() }
    return power()
  }
  function power() {
    var b = primary()
    if (isOp("^")) { p++; return Math.pow(b, unary()) }
    return b
  }
  function primary() {
    var t = tk[p]
    if (!t) fail()
    if (t.t === "n") { p++; return t.v }
    if (t.t === "i") {
      p++
      if (CONSTS.hasOwnProperty(t.v)) return CONSTS[t.v]
      if (FUNCS.hasOwnProperty(t.v)) {
        if (!isOp("(")) fail()
        p++; var a = expr(); if (!isOp(")")) fail(); p++
        return FUNCS[t.v](a)
      }
      fail()
    }
    if (isOp("(")) { p++; var v = expr(); if (!isOp(")")) fail(); p++; return v }
    fail()
  }
  try {
    var v = expr()
    if (p !== tk.length) return null
    if (typeof v !== "number" || !isFinite(v)) return null
    return v
  } catch (e) { return null }
}

function format(v) {
  if (Math.abs(v) >= 1e15 || (v !== 0 && Math.abs(v) < 1e-9)) return v.toExponential(8).replace(/\.?0+e/, "e")
  return String(Number(v.toPrecision(12)))
}

// ¿Parece una cuenta? (para mostrar el resultado sin prefijo "=")
function looksLikeMath(q) {
  return /^[\d\s.,+\-*\/^%()x×÷]+$/.test(q) && /\d/.test(q) && /[+\-*\/^%x×÷]/.test(q.replace(/^\s*[-+]/, "")) && /\d\s*[)]?\s*[+\-*\/^%x×÷]\s*[(]?\s*[-]?[\d.]/.test(q)
}
