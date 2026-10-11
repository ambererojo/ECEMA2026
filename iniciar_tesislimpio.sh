#!/bin/bash

# Carpeta de este script = carpeta de presentación1.html, presentación2.html, ...
AQUI="$(cd "$(dirname "$0")" && pwd)"
cd "$AQUI" || exit 1
LOG=/tmp/servidor_overlay.log

# Comprobaciones previas (con mensajes claros)
if [ ! -f "$AQUI/servidor_overlay.py" ]; then
    echo "ERROR: falta servidor_overlay.py junto a este script ($AQUI)"; exit 1
fi
if [ ! -f "$AQUI/presentación1.html" ]; then
    echo "ERROR: no encuentro presentación1.html en $AQUI"; exit 1
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

# 4. Limpiar caché del perfil temporal de Brave
rm -rf /tmp/brave-tesis

# 5. Abrir Brave en kiosco
brave --kiosk --user-data-dir=/tmp/brave-tesis "http://localhost:8000/presentación1.html" &

echo "=========================================================="
echo "Servidor y Brave iniciados. Caché limpia. Escudo CINAE activo."
echo "Para cerrar: Alt+F4. Para apagar servidor: CTRL+C."
echo "=========================================================="

trap "kill $PID_UNCLUTTER $PID_SERVER 2>/dev/null; exit 0" INT TERM
wait $PID_SERVER
