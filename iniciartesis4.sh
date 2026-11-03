#!/bin/bash

# Carpeta de este script = carpeta de presentación0.html, objetivos, ...
AQUI="$(cd "$(dirname "$0")" && pwd)"
cd "$AQUI" || exit 1
LOG=/tmp/servidor_overlay.log

# Modo de renderizado: "nvidia" (por defecto, el más estable en esta Dell),
#                     "intel", "software"
# Se puede sobreescribir con:  MODO_GPU=intel ./iniciartesis3.sh
MODO_GPU="${MODO_GPU:-nvidia}"

# Comprobaciones previas
if [ ! -f "$AQUI/servidor_overlay.py" ]; then
    echo "ERROR: falta servidor_overlay.py junto a este script ($AQUI)"; exit 1
fi
if [ ! -f "$AQUI/presentación0.html" ]; then
    echo "ERROR: no encuentro presentación0.html en $AQUI"; exit 1
fi

# 0. Limpieza rápida de procesos previos
pkill brave 2>/dev/null
pkill -f "http.server 8000" 2>/dev/null
pkill -f "servidor_overlay.py" 2>/dev/null
fuser -k 8000/tcp 2>/dev/null
sleep 1

# 1. Ocultar cursor
unclutter -idle 0 -root &
PID_UNCLUTTER=$!

# 2. Iniciar servidor local
python3 "$AQUI/servidor_overlay.py" "$AQUI" 8000 > "$LOG" 2>&1 &
PID_SERVER=$!

# 3. Esperar respuesta del servidor (hasta 5 s)
OK=0
for i in {1..10}; do
    if curl -s -o /dev/null "http://localhost:8000/"; then OK=1; break; fi
    sleep 0.5
done
if [ "$OK" != 1 ]; then
    echo "ERROR: el servidor no arrancó."
    kill $PID_UNCLUTTER 2>/dev/null
    exit 1
fi

# 4. LIMPIEZA DE PERFIL TEMPORAL
rm -rf /tmp/brave-tesis

# 5. CONFIGURACIÓN DE CPU (evita bajones de rendimiento en el i7 HX)
if [ "$EUID" -eq 0 ]; then
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
    FLAGS_ROOT="--no-sandbox --test-type"
else
    FLAGS_ROOT=""
fi

# 6. FLAGS COMUNES
# VA-API desactivado: el cruce de buffers Intel<->NVIDIA causaba micro-retardo
# en la decodificación de video. El i7-13650HX decodifica 1080p por software
# sin problema (14C/20T). Videos fluidos, sin cruces entre GPUs.
FLAGS_COMUNES=(
    --kiosk
    --user-data-dir=/tmp/brave-tesis
    --ignore-gpu-blocklist
    --disable-features=VaapiVideoDecodeLinuxGL,VaapiVideoDecoder,VaapiVideoEncoder,UseChromeOSDirectVideoDecoder
    $FLAGS_ROOT
)

case "$MODO_GPU" in
    nvidia)
        # Configuración más estable:
        #   X11 forzado -> prime-run funciona (Wayland lo ignora)
        #   RTX 4060 -> sin textos fantasma
        #   angle/gl -> camino estable con NVIDIA (más que egl)
        #   VA-API off -> sin micro-retardo en videos
        if command -v prime-run >/dev/null 2>&1; then
            echo "[GPU] prime-run + X11 + NVIDIA RTX 4060 (configuración estable)"
            prime-run brave "${FLAGS_COMUNES[@]}" \
                --ozone-platform=x11 \
                --use-gl=angle \
                --use-angle=gl \
                "http://localhost:8000/presentación0.html" &
        elif command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
            echo "[GPU] prime-run ausente; variables PRIME + X11"
            __NV_PRIME_RENDER_OFFLOAD=1 \
            __GLX_VENDOR_LIBRARY_NAME=nvidia \
            __VK_LAYER_NV_optimus=NVIDIA_only \
            brave "${FLAGS_COMUNES[@]}" \
                --ozone-platform=x11 \
                --use-gl=angle \
                --use-angle=gl \
                "http://localhost:8000/presentación0.html" &
        else
            echo "[GPU] nvidia-smi no responde → cayendo a Intel (DRI_PRIME=0)"
            DRI_PRIME=0 brave "${FLAGS_COMUNES[@]}" \
                --ozone-platform=x11 \
                --use-gl=angle \
                --use-angle=gl \
                "http://localhost:8000/presentación0.html" &
        fi
        ;;
    intel)
        # Todo en Intel, una sola GPU, sin cruces. Estable pero sin RTX.
        echo "[GPU] Modo Intel integrada (una sola GPU, sin cruces)"
        DRI_PRIME=0 brave "${FLAGS_COMUNES[@]}" \
            --ozone-platform=x11 \
            --use-gl=angle \
            --use-angle=gl \
            "http://localhost:8000/presentación0.html" &
        ;;
    software)
        # Último recurso: sin GPU. Lento pero sin artefactos posibles.
        echo "[GPU] Modo software (sin GPU, último recurso)"
        brave "${FLAGS_COMUNES[@]}" \
            --disable-gpu \
            --disable-gpu-compositing \
            "http://localhost:8000/presentación0.html" &
        ;;
    *)
        echo "ERROR: MODO_GPU desconocido: $MODO_GPU (usa nvidia|intel|software)"
        kill $PID_UNCLUTTER $PID_SERVER 2>/dev/null
        exit 1
        ;;
esac

BRAVE_PID=$!
sleep 4

# 7. DIAGNÓSTICO: mostrar qué GPU está usando Brave realmente
echo "=========================================================="
echo "DIAGNÓSTICO GPU (Brave recién abierto):"
if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi --query-compute-apps=pid,process_name,used_memory \
                  --format=csv,noheader 2>/dev/null | grep -qi brave; then
        echo "  ✓ Brave está usando NVIDIA (RTX 4060)"
    else
        echo "  ✗ Brave NO aparece en NVIDIA (probablemente usando Intel)"
    fi
else
    echo "  nvidia-smi no disponible, no se puede diagnosticar"
fi
echo "=========================================================="
echo "Servidor y Brave iniciados. Modo GPU: $MODO_GPU"
echo "Para cerrar: Alt+F4. Para apagar servidor: CTRL+C."
echo "Cambiar modo:  MODO_GPU=intel ./iniciartesis3.sh"
echo "              MODO_GPU=software ./iniciartesis3.sh"
echo "Verificar GPU:  abrir  brave://gpu  y mirar GL_RENDERER"
echo "=========================================================="

# Al presionar CTRL+C, apaga todo de forma limpia
trap "kill $PID_UNCLUTTER $PID_SERVER $BRAVE_PID 2>/dev/null; exit 0" INT TERM
wait $PID_SERVER