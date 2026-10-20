#!/bin/bash

# Carpeta de este script = carpeta de presentación0.html, objetivos, ...
AQUI="$(cd "$(dirname "$0")" && pwd)"
cd "$AQUI" || exit 1
LOG=/tmp/servidor_overlay.log

# Comprobaciones previas (con mensajes claros)
if [ ! -f "$AQUI/servidor_overlay.py" ]; then
    echo "ERROR: falta servidor_overlay.py junto a este script ($AQUI)"; exit 1
fi
if [ ! -f "$AQUI/presentación0.html" ]; then
    echo "ERROR: no encuentro presentación0.html en $AQUI"; exit 1
fi

# 0. Matar Brave Y servidor previos
pkill brave 2>/dev/null
pkill -f "http.server 8000" 2>/dev/null
pkill -f "servidor_overlay.py" 2>/dev/null
fuser -k 8000/tcp 2>/dev/null
sleep 2

# 1. Ocultar cursor a nivel sistema
unclutter -idle 0 -root &
PID_UNCLUTTER=$!

# 2. Servidor local + escudo CINAE fijo arriba a la derecha en TODOS los .html
python3 "$AQUI/servidor_overlay.py" "$AQUI" 8000 > "$LOG" 2>&1 &
PID_SERVER=$!

# 3. Esperar a que el servidor responda (hasta 5 s)
OK=0
for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -s -o /dev/null "http://localhost:8000/"; then OK=1; break; fi
    sleep 0.5
done
if [ "$OK" != 1 ]; then
    echo "ERROR: el servidor no arrancó. Detalle ($LOG):"
    cat "$LOG"
    kill $PID_UNCLUTTER 2>/dev/null
    exit 1
fi
cat "$LOG"

# 4. FORZAR ALTO RENDIMIENTO EN HARDWARE (Solo si se ejecuta con sudo)
if [ "$EUID" -eq 0 ]; then
    # Forzar todos los núcleos de la CPU al máximo
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
    # Liberar potencia gráfica de la GPU
    teectl set subslice all >/dev/null 2>&1
    xrandr --output $(xrandr | grep " connected" | cut -f1 -d" ") --set "TearFree" "on" >/dev/null 2>&1
    # Optimización de presión de caché
    sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1
fi

# 5. Limpiar caché del perfil temporal de Brave
rm -rf /tmp/brave-tesis

# 6. Abrir Brave en kiosco
brave --kiosk --user-data-dir=/tmp/brave-tesis "http://localhost:8000/presentación0.html" &

echo "=========================================================="
echo "Servidor y Brave iniciados. Caché limpia. Escudo CINAE activo."
echo "Para cerrar: Alt+F4. Para apagar servidor: CTRL+C."
echo "=========================================================="

# Al presionar CTRL+C, apaga el servidor y regresa la CPU al modo equilibrado (powersave)
trap "echo 'powersave' | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1; kill $PID_UNCLUTTER $PID_SERVER 2>/dev/null; exit 0" INT TERM
wait $PID_SERVER

