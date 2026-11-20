#!/usr/bin/env bash
# Emite métricas en streaming, una línea por muestra:
#   cpu <usado%>   ram <usado%> <usadoGiB> <totalGiB>   gpu <util%> <tempC> <vram%>
interval=${1:-2}
read -r _ u n s i w q sq _ < /proc/stat; pt=$((u+n+s+i+w+q+sq)); pi=$((i+w))
has_gpu=0; command -v nvidia-smi >/dev/null && has_gpu=1
tick=0
while :; do
  sleep "$interval"
  read -r _ u n s i w q sq _ < /proc/stat; t=$((u+n+s+i+w+q+sq)); idl=$((i+w))
  dt=$((t-pt)); di=$((idl-pi)); pt=$t; pi=$idl
  [ "$dt" -gt 0 ] && echo "cpu $(( (100*(dt-di)) / dt ))"
  awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "ram %d %.1f %.1f\n", (t-a)*100/t, (t-a)/1048576, t/1048576}' /proc/meminfo
  if [ "$has_gpu" = 1 ] && [ $((tick % 2)) = 0 ]; then
    nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null \
      | awk -F', *' 'NR==1{printf "gpu %d %d %d\n", $1, $2, ($4>0 ? $3*100/$4 : 0)}'
  fi
  tick=$((tick+1))
done
