@echo off
:: Configura la codificación para aceptar tildes y eñes
chcp 65001 >nul

:: Carpeta de este script = carpeta de presentación0.html
set "AQUI=%~dp0"
cd /d "%AQUI%"

:: Comprobaciones previas
if not exist "%AQUI%servidor_overlay.py" (
    echo ERROR: falta servidor_overlay.py junto a este script.
    pause
    exit /b 1
)
if not exist "%AQUI%presentación0.html" (
    echo ERROR: no encuentro presentación0.html.
    pause
    exit /b 1
)

:: 0. Matar procesos previos (Brave y servidores Python en puerto 8000)
echo Limpiando entorno previo...
taskkill /f /im brave.exe >nul 2>&1
:: Mata cualquier servidor python activo de forma silenciosa
taskkill /f /fi "WINDOWTITLE eq ServidorTesisPython" >nul 2>&1

:: 1. Ocultar el cursor (En Windows no existe 'unclutter'. Se maneja por CSS en el HTML o software externo)
:: Nota: Si necesitas ocultar el cursor, agrega en el CSS de tus .html: html { cursor: none; }

:: 2. Iniciar Servidor local + escudo CINAE (Usa el título de ventana para controlarlo después)
echo Iniciando servidor de overlay de la tesis...
start "ServidorTesisPython" /min python "%AQUI%servidor_overlay.py" "%AQUI%" 8000

:: 3. Esperar a que el servidor responda (Simulación de delay en Windows CMD)
echo Esperando estabilidad del sistema...
timeout /t 3 /nobreak >nul

:: 4. Optimización de Hardware en Windows
:: Windows gestiona el alto rendimiento de forma automática si la laptop está enchufada. 
:: Asegúrate de que la laptop de la defensa esté en plan de energía de "Alto Rendimiento".

:: 5. Limpiar caché del perfil temporal de Brave en Windows
if exist "%TEMP%\brave-tesis" rd /s /q "%TEMP%\brave-tesis"

:: 6. Abrir Brave en modo Kiosco con aceleración por hardware integrada para Windows (DirectX/D3D11)
echo Lanzando interfaz de presentación en modo Kiosco...
start "" "brave" --kiosk --user-data-dir="%TEMP%\brave-tesis" --use-angle=d3d11 --ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy "http://localhost:8000/presentación0.html"

echo ==========================================================
echo Servidor y Brave iniciados. Escudo CINAE activo en Windows.
echo Para cerrar la presentación: Alt + F4
echo Para apagar el servidor: Cierra la ventana negra de comando o usa CTRL+C.
echo ==========================================================
pause

