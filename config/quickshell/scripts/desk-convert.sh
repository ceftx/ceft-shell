#!/usr/bin/env bash
# Convierte imágenes a WEBP junto al original (nunca sobrescribe ni borra). Uso: desk-convert.sh archivo...
ok=0; fail=0; last=""
for f in "$@"; do
  f="${f#file://}"
  [ -f "$f" ] || { fail=$((fail+1)); continue; }
  base="${f%.*}"; out="$base.webp"; n=1
  while [ -e "$out" ]; do out="$base-$n.webp"; n=$((n+1)); done
  if command -v cwebp >/dev/null; then
    cwebp -quiet -q 85 "$f" -o "$out" >/dev/null 2>&1
  elif command -v ffmpeg >/dev/null; then
    ffmpeg -nostdin -loglevel error -y -i "$f" -frames:v 1 -c:v libwebp -quality 85 "$out" >/dev/null 2>&1
  else
    notify-send -a ceft-shell "Conversor" "Falta cwebp (libwebp) o ffmpeg"; exit 1
  fi
  if [ -s "$out" ]; then ok=$((ok+1)); last="$out"; else rm -f "$out"; fail=$((fail+1)); fi
done
if [ "$ok" -gt 0 ]; then
  msg="$ok imagen(es) a WEBP"; [ "$ok" = 1 ] && msg="$(basename "$last")"
  [ "$fail" -gt 0 ] && msg="$msg ($fail fallaron)"
  notify-send -a ceft-shell -i "$last" "Convertido a WEBP" "$msg"
else
  notify-send -a ceft-shell -u critical "Conversor" "No se pudo convertir ($fail archivo(s))"
fi
echo "ok=$ok fail=$fail"
