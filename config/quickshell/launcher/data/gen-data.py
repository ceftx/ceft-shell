#!/usr/bin/env python3
"""Genera emoji.json y glyphs.json (una vez; el resultado se versiona).
Uso: gen-data.py <dir con emoji-test.txt, ann-{es,en}.json, annd-{es,en}.json, glyphnames.json>
Fuentes: unicode.org/Public/emoji/latest/emoji-test.txt, unicode-org/cldr-json (annotations y
annotationsDerived, es y en), ryanoasis/nerd-fonts glyphnames.json."""
import json, re, sys, os
src = sys.argv[1]; out = os.path.dirname(os.path.abspath(__file__))
def load(n): return json.load(open(os.path.join(src, n), encoding="utf-8"))
ann = {}
for l in ("es", "en"):
    d = {}
    for f, k in (("annd-%s.json", "annotationsDerived"), ("ann-%s.json", "annotations")):
        d.update(load(f % l)[k]["annotations"])
    ann[l] = d
def look(l, ch):
    d = ann[l]
    for k in (ch, ch.replace("️", "")):
        if k in d: return d[k]
    return None
TONES = ["light", "medium-light", "medium", "medium-dark", "dark"]
rows = []; tones = {}; group = ""
for line in open(os.path.join(src, "emoji-test.txt"), encoding="utf-8"):
    if line.startswith("# group:"): group = line.split(":", 1)[1].strip(); continue
    m = re.match(r"^([0-9A-F ]+?)\s*; (\S+)\s*# (\S+) E[\d.]+ (.*)$", line)
    if not m or m.group(2) != "fully-qualified" or group == "Component": continue
    ch, name = m.group(3), m.group(4)
    t = re.match(r"^(.*): (light|medium-light|medium|medium-dark|dark) skin tone$", name)
    if t:
        tones.setdefault(t.group(1), {})[t.group(2)] = ch; continue
    if "skin tone" in name: continue
    rows.append((ch, name, group))
res = []
for ch, name, g in rows:
    es, en = look("es", ch), look("en", ch)
    nes = (es["tts"][0] if es and es.get("tts") else name)
    nen = (en["tts"][0] if en and en.get("tts") else name)
    kw = []
    for a in (es, en):
        if a:
            for w in a.get("default", []):
                if w not in kw and w != nes and w != nen: kw.append(w)
    e = [ch, nes, nen, "|".join(kw), g]
    tv = tones.get(name)
    if tv and all(t in tv for t in TONES): e.append([tv[t] for t in TONES])
    res.append(e)
json.dump(res, open(os.path.join(out, "emoji.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
gl = load("glyphnames.json"); gl.pop("METADATA", None)
g = []
for name, v in gl.items(): g.append([name, v["char"]])
json.dump(g, open(os.path.join(out, "glyphs.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(len(res), "emojis,", sum(1 for e in res if len(e) > 5), "con tono;", len(g), "glifos")
