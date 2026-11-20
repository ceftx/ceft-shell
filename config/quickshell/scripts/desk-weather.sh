#!/usr/bin/env bash
# Descarga el clima actual de Open-Meteo (sin API key) al cache. Uso: desk-weather.sh LAT LON [celsius|fahrenheit]
set -u
lat=${1:?lat}; lon=${2:?lon}; units=${3:-celsius}
dir="${XDG_CACHE_HOME:-$HOME/.cache}/ceft-shell"; mkdir -p "$dir"
tu=celsius; [ "$units" = fahrenheit ] && tu=fahrenheit
url="https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m&daily=sunrise,sunset&timezone=auto&forecast_days=1&temperature_unit=$tu&wind_speed_unit=kmh"
tmp=$(mktemp "$dir/weather.XXXXXX") || exit 1
if curl -fsS -m 20 "$url" -o "$tmp" && grep -q '"current"' "$tmp"; then
  mv -f "$tmp" "$dir/weather.json"
else
  rm -f "$tmp"; exit 1
fi
