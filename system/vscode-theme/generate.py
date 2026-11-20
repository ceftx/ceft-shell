#!/usr/bin/env python3
"""Genera la extensión de tema de VS Code "Ceft (wallpaper)" desde theme.json de ceft-shell.

Uso: generate.py <theme.json> <dir-extensiones> [<dir-extensiones> ...]
Escribe <dir>/ceft-material/{package.json,themes/ceft.json}. No toca settings.json.
Lo llama `ceft-shell` (theme_apply); VS Code relee el tema al recargar la ventana.
"""
import json
import os
import sys

EXT_NAME = "ceft-material"
LABEL = "Ceft (wallpaper)"


def rgb(h):
    h = h.lstrip("#")[:6]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexs(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in c)


def mix(a, b, t):
    """a * (1 - t) + b * t"""
    ca, cb = rgb(a), rgb(b)
    return hexs(tuple(x * (1 - t) + y * t for x, y in zip(ca, cb)))


def alpha(h, a):
    return h.lstrip("#")[:6].join(["#", "%02x" % round(a * 255)])


def luminance(h):
    r, g, b = (v / 255 for v in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def build(t):
    g = lambda k, d: t.get(k) if isinstance(t.get(k), str) and t.get(k).startswith("#") else d
    bg = g("background", "#1a1b26")
    fg = g("foreground", "#a9b1d6")
    dim = g("dim", mix(bg, fg, 0.45))
    accent = g("accent", "#7aa2f7")
    accent2 = g("accent2", accent)
    surface = g("surface", mix(bg, fg, 0.1))
    border = g("border", mix(bg, fg, 0.2))
    sel = g("selection", mix(bg, accent, 0.25))
    cur = g("cursor", fg)
    ansi = [g("color%d" % i, d) for i, d in enumerate(
        ["#1a1b26", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6",
         "#414868", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#c0caf5"])]
    red, green, yellow = ansi[1], ansi[2], ansi[3]
    dark = luminance(bg) < 0.5
    deep = mix(bg, "#000000" if dark else "#ffffff", 0.22)      # barras laterales/tabs inactivas
    raised = mix(bg, surface, 0.6)
    hover = mix(bg, fg, 0.07)
    on_accent = bg if luminance(accent) > luminance(bg) else fg

    colors = {
        "foreground": fg, "descriptionForeground": dim, "disabledForeground": alpha(dim, 0.6),
        "focusBorder": alpha(accent, 0.6), "widget.shadow": alpha("#000000", 0.35),
        "selection.background": alpha(accent, 0.4), "icon.foreground": dim,
        "errorForeground": red, "textLink.foreground": accent, "textLink.activeForeground": accent2,
        "textCodeBlock.background": surface, "sash.hoverBorder": accent,

        "editor.background": bg, "editor.foreground": fg,
        "editorLineNumber.foreground": alpha(dim, 0.7), "editorLineNumber.activeForeground": accent,
        "editorCursor.foreground": cur,
        "editor.selectionBackground": sel, "editor.inactiveSelectionBackground": alpha(sel, 0.6),
        "editor.selectionHighlightBackground": alpha(accent, 0.15),
        "editor.wordHighlightBackground": alpha(accent2, 0.18),
        "editor.wordHighlightStrongBackground": alpha(accent2, 0.3),
        "editor.findMatchBackground": alpha(yellow, 0.4), "editor.findMatchHighlightBackground": alpha(yellow, 0.2),
        "editor.lineHighlightBackground": mix(bg, surface, 0.45), "editor.lineHighlightBorder": "#00000000",
        "editor.rangeHighlightBackground": alpha(accent, 0.1),
        "editorBracketMatch.background": alpha(accent, 0.2), "editorBracketMatch.border": alpha(accent, 0.5),
        "editorIndentGuide.background1": alpha(border, 0.6), "editorIndentGuide.activeBackground1": dim,
        "editorWhitespace.foreground": alpha(border, 0.6), "editorRuler.foreground": border,
        "editorCodeLens.foreground": dim, "editorLink.activeForeground": accent,
        "editorGutter.background": bg,
        "editorGutter.addedBackground": green, "editorGutter.modifiedBackground": yellow,
        "editorGutter.deletedBackground": red,
        "editorError.foreground": red, "editorWarning.foreground": yellow, "editorInfo.foreground": accent2,
        "editorHint.foreground": dim,
        "editorWidget.background": raised, "editorWidget.border": border,
        "editorSuggestWidget.background": raised, "editorSuggestWidget.border": border,
        "editorSuggestWidget.selectedBackground": sel, "editorSuggestWidget.highlightForeground": accent,
        "editorHoverWidget.background": raised, "editorHoverWidget.border": border,
        "peekView.border": accent, "peekViewEditor.background": deep, "peekViewResult.background": raised,
        "peekViewTitle.background": raised,
        "diffEditor.insertedTextBackground": alpha(green, 0.16), "diffEditor.removedTextBackground": alpha(red, 0.16),
        "editorOverviewRuler.border": "#00000000",
        "editorGroup.border": border, "editorGroupHeader.tabsBackground": deep,
        "editorGroupHeader.noTabsBackground": bg,

        "tab.activeBackground": bg, "tab.activeForeground": fg, "tab.activeBorderTop": accent,
        "tab.inactiveBackground": deep, "tab.inactiveForeground": dim, "tab.border": deep,
        "tab.hoverBackground": hover, "tab.unfocusedActiveBackground": bg,

        "activityBar.background": deep, "activityBar.foreground": fg, "activityBar.inactiveForeground": dim,
        "activityBar.border": deep, "activityBar.activeBorder": accent,
        "activityBarBadge.background": accent, "activityBarBadge.foreground": on_accent,
        "sideBar.background": deep, "sideBar.foreground": mix(fg, dim, 0.25), "sideBar.border": border,
        "sideBarTitle.foreground": fg, "sideBarSectionHeader.background": mix(deep, surface, 0.5),
        "sideBarSectionHeader.foreground": fg,
        "list.activeSelectionBackground": sel, "list.activeSelectionForeground": fg,
        "list.inactiveSelectionBackground": mix(deep, sel, 0.6), "list.hoverBackground": hover,
        "list.highlightForeground": accent, "list.focusBackground": sel,
        "tree.indentGuidesStroke": border,

        "titleBar.activeBackground": deep, "titleBar.activeForeground": fg,
        "titleBar.inactiveBackground": deep, "titleBar.inactiveForeground": dim, "titleBar.border": deep,
        "menubar.selectionBackground": hover, "menu.background": raised, "menu.foreground": fg,
        "menu.selectionBackground": sel, "menu.separatorBackground": border,
        "statusBar.background": deep, "statusBar.foreground": mix(fg, dim, 0.3), "statusBar.border": border,
        "statusBar.noFolderBackground": deep, "statusBar.debuggingBackground": accent2,
        "statusBar.debuggingForeground": on_accent,
        "statusBarItem.hoverBackground": hover, "statusBarItem.remoteBackground": accent,
        "statusBarItem.remoteForeground": on_accent,
        "panel.background": bg, "panel.border": border,
        "panelTitle.activeForeground": fg, "panelTitle.inactiveForeground": dim,
        "panelTitle.activeBorder": accent,

        "input.background": deep, "input.border": border, "input.foreground": fg,
        "input.placeholderForeground": dim, "inputOption.activeBorder": accent,
        "inputOption.activeBackground": alpha(accent, 0.25),
        "dropdown.background": raised, "dropdown.border": border, "dropdown.foreground": fg,
        "button.background": accent, "button.foreground": on_accent, "button.hoverBackground": mix(accent, fg, 0.18),
        "button.secondaryBackground": surface, "button.secondaryForeground": fg,
        "badge.background": accent, "badge.foreground": on_accent,
        "progressBar.background": accent,
        "scrollbar.shadow": "#00000000", "scrollbarSlider.background": alpha(dim, 0.25),
        "scrollbarSlider.hoverBackground": alpha(dim, 0.4), "scrollbarSlider.activeBackground": alpha(accent, 0.5),
        "notifications.background": raised, "notifications.border": border,
        "notificationCenterHeader.background": surface,
        "quickInput.background": raised, "quickInputList.focusBackground": sel,
        "pickerGroup.foreground": accent, "pickerGroup.border": border,
        "breadcrumb.foreground": dim, "breadcrumb.focusForeground": fg, "breadcrumb.activeSelectionForeground": accent,
        "gitDecoration.modifiedResourceForeground": yellow, "gitDecoration.addedResourceForeground": green,
        "gitDecoration.untrackedResourceForeground": green, "gitDecoration.deletedResourceForeground": red,
        "gitDecoration.ignoredResourceForeground": alpha(dim, 0.7),
        "gitDecoration.conflictingResourceForeground": accent2,
        "textBlockQuote.background": surface, "textBlockQuote.border": accent,
        "textPreformat.foreground": accent2,

        "terminal.background": bg, "terminal.foreground": g("term_fg", fg),
        "terminal.selectionBackground": sel, "terminalCursor.foreground": cur,
        "terminal.border": border, "terminal.tab.activeBorder": accent,
    }
    names = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
    for i, n in enumerate(names):
        colors["terminal.ansi" + n] = ansi[i]
        colors["terminal.ansiBright" + n] = ansi[i + 8]

    keyword, func, typ, const, string = ansi[5], accent, ansi[6], yellow, green
    op = ansi[14]

    def tok(name, scope, fg_=None, style=None):
        s = {}
        if fg_: s["foreground"] = fg_
        if style: s["fontStyle"] = style
        return {"name": name, "scope": scope, "settings": s}

    token_colors = [
        tok("Comentarios", ["comment", "punctuation.definition.comment"], dim, "italic"),
        tok("Cadenas", ["string", "string.quoted", "markup.inline.raw"], string),
        tok("Escapes y regex", ["constant.character.escape", "string.regexp"], accent2),
        tok("Números y constantes", ["constant.numeric", "constant.language", "constant.character", "support.constant"], const),
        tok("Palabras clave", ["keyword", "storage", "storage.type", "storage.modifier", "keyword.control"], keyword),
        tok("Operadores", ["keyword.operator", "punctuation.separator.key-value"], op),
        tok("Funciones", ["entity.name.function", "support.function", "meta.function-call.generic"], func),
        tok("Tipos y clases", ["entity.name.type", "entity.name.class", "support.type", "support.class",
                               "entity.other.inherited-class"], typ),
        tok("Variables", ["variable", "variable.other.readwrite", "meta.definition.variable"], fg),
        tok("Parámetros", ["variable.parameter"], mix(fg, accent2, 0.35), "italic"),
        tok("Propiedades", ["variable.other.property", "variable.other.object.property", "meta.object-literal.key",
                            "support.type.property-name"], mix(fg, accent, 0.5)),
        tok("this/self", ["variable.language"], red, "italic"),
        tok("Puntuación", ["punctuation", "meta.brace", "meta.delimiter"], mix(fg, dim, 0.45)),
        tok("Etiquetas HTML/XML", ["entity.name.tag", "meta.tag"], red),
        tok("Atributos", ["entity.other.attribute-name"], yellow, "italic"),
        tok("Selectores CSS", ["entity.name.tag.css", "entity.other.attribute-name.class.css",
                               "entity.other.attribute-name.id.css", "meta.selector"], typ),
        tok("Propiedades CSS", ["support.type.property-name.css", "meta.property-name"], accent),
        tok("Decoradores", ["meta.decorator", "entity.name.function.decorator", "punctuation.decorator"], accent2),
        tok("Import/export", ["keyword.control.import", "keyword.control.export", "keyword.control.from"], keyword),
        tok("Encabezados Markdown", ["markup.heading", "entity.name.section"], accent, "bold"),
        tok("Negrita", ["markup.bold"], fg, "bold"),
        tok("Cursiva", ["markup.italic"], fg, "italic"),
        tok("Enlaces", ["markup.underline.link", "string.other.link"], accent2),
        tok("Listas Markdown", ["punctuation.definition.list.begin.markdown", "beginning.punctuation.definition.list"], accent),
        tok("Código citado", ["markup.quote"], dim, "italic"),
        tok("Diff agregado", ["markup.inserted"], green),
        tok("Diff borrado", ["markup.deleted"], red),
        tok("Diff modificado", ["markup.changed"], yellow),
        tok("Inválido", ["invalid", "invalid.illegal"], red),
    ]
    semantic = {
        "function": func, "method": func, "class": typ, "interface": typ, "type": typ, "enum": typ,
        "typeParameter": typ, "namespace": mix(typ, fg, 0.3), "parameter": mix(fg, accent2, 0.35),
        "property": mix(fg, accent, 0.5), "enumMember": const, "variable.readonly": const,
        "keyword": keyword, "string": string, "number": const, "comment": dim, "decorator": accent2,
    }
    return {
        "$schema": "vscode://schemas/color-theme",
        "name": LABEL, "type": "dark" if dark else "light",
        "semanticHighlighting": True,
        "colors": colors, "tokenColors": token_colors, "semanticTokenColors": semantic,
    }


def package(dark):
    return {
        "name": EXT_NAME, "displayName": "Ceft Material", "publisher": "ceft", "version": "1.0.0",
        "description": "Colores del wallpaper de ceft-shell (generado; no editar)",
        "engines": {"vscode": "^1.60.0"}, "categories": ["Themes"],
        "contributes": {"themes": [{"label": LABEL, "uiTheme": "vs-dark" if dark else "vs",
                                    "path": "./themes/ceft.json"}]},
    }


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)


def main():
    if len(sys.argv) < 3:
        sys.exit("uso: generate.py <theme.json> <dir-extensiones>...")
    t = json.load(open(sys.argv[1]))
    theme = build(t)
    for d in sys.argv[2:]:
        base = os.path.join(d, EXT_NAME)
        write(os.path.join(base, "themes", "ceft.json"), theme)
        write(os.path.join(base, "package.json"), package(theme["type"] == "dark"))
        print(base)


if __name__ == "__main__":
    main()
