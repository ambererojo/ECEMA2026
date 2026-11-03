#!/usr/bin/env python3
"""Servidor local que sirve la carpeta de la presentación e inyecta el escudo
CINAE (esquina sup. derecha) y un temporizador de 30 min (esquina sup. izquierda).
Ambos permanecen ocultos y se activan juntos con la primera interacción del usuario.
El temporizador persiste entre páginas encadenadas vía sessionStorage y, al llegar
a 00:00, se queda fijo en rojo (sin parpadeo)."""
import http.server, os, sys

RAIZ = sys.argv[1]
PUERTO = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
NOMBRE = "cinae3d_lento.webp"

def buscar_escudo():
    """Busca el escudo junto a este script, en la carpeta de la presentación
    o en cualquiera de sus subcarpetas (videos1, videos2, ...)."""
    aqui = os.path.dirname(os.path.abspath(__file__))
    for base in (aqui, RAIZ):
        for ruta in (os.path.join(base, NOMBRE),):
            if os.path.isfile(ruta):
                return ruta
    for base in (aqui, RAIZ):
        for d, _, fs in os.walk(base):
            if NOMBRE in fs:
                return os.path.join(d, NOMBRE)
    print(f"AVISO: no encuentro {NOMBRE}; se sirve la presentación sin escudo", flush=True)
    return None

ESCUDO = buscar_escudo()

# Tamaño máximo 2 cm x 3 cm (CSS cm).
ANCHO, ALTO, MARGEN_SUP, MARGEN_DER = "2.1cm", "3.15cm", "0.8cm", "1.3cm"

# OJO: string NORMAL (sin f), para no tener que doblar llaves del JS/CSS.
# Los placeholders %%...%% se sustituyen abajo con .replace().
_PLANTILLA = """
<!-- Escudo CINAE (oculto hasta la primera interacción o si ya se inició antes) -->
<img id="escudo-cinae" src="/__escudo/cinae3d_lento.webp" alt=""
 style="position:fixed;top:%%MARGEN_SUP%%;right:%%MARGEN_DER%%;
 width:%%ANCHO%%;height:%%ALTO%%;max-width:%%ANCHO%%;max-height:%%ALTO%%;
 object-fit:contain;background:transparent;
 pointer-events:none;z-index:2147483647;display:none;opacity:0;
 will-change: opacity;
 transition: opacity 0.6s ease;
 transform: translateZ(0);">

<!-- Temporizador de 30 minutos (oculto hasta la primera interacción o si ya se inició antes) -->
<div id="temporizador-tesis"
 style="position:fixed;top:15px;left:15px;z-index:2147483647;
 font-family:monospace, sans-serif;font-size:24px;font-weight:bold;
 color:#ff3333;background:rgba(0,0,0,0.7);padding:5px 10px;border-radius:5px;
 pointer-events:none;display:none;opacity:0;transition:opacity 0.6s ease;">30:00</div>

<script>
(function() {
    var CLAVE_INI = 'tesis_iniciado';
    var CLAVE_FIN = 'tesis_fin';
    var DURACION_MS = 30 * 60 * 1000; // 30 minutos

    var escudo = document.getElementById('escudo-cinae');
    var timer  = document.getElementById('temporizador-tesis');
    var intervalo = null;

    function pintar(msRestantes) {
        if (msRestantes < 0) msRestantes = 0;
        var totalSeg = Math.ceil(msRestantes / 1000);
        var m = Math.floor(totalSeg / 60);
        var s = totalSeg % 60;
        timer.innerText = String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
    }

    function mostrarElementos() {
        if (escudo) {
            escudo.style.display = 'block';
            // Usamos un pequeño retraso para que el navegador aplique el display:block antes de la opacidad
            setTimeout(function() { escudo.style.opacity = '1'; }, 20);
        }
        if (timer) {
            timer.style.display = 'block';
            setTimeout(function() { timer.style.opacity = '1'; }, 20);
        }
    }

    function arrancarCuenta(finMs) {
        if (intervalo) return;
        function tick() {
            var restante = finMs - Date.now();
            pintar(restante);
            if (restante <= 0) {
                clearInterval(intervalo);
                intervalo = null;
                timer.innerText = '00:00';
                timer.style.color = '#ff0000';
                try { sessionStorage.setItem(CLAVE_FIN, '0'); } catch(e) {}
            }
        }
        tick();
        intervalo = setInterval(tick, 1000);
    }

    function iniciarSiProcede() {
        try {
            if (sessionStorage.getItem(CLAVE_INI) === '1') {
                mostrarElementos();
                var fin = parseInt(sessionStorage.getItem(CLAVE_FIN) || '0', 10);
                if (!fin || isNaN(fin)) {
                    fin = Date.now() + DURACION_MS;
                    sessionStorage.setItem(CLAVE_FIN, String(fin));
                }
                arrancarCuenta(fin);
                return true;
            }
        } catch(e) {}
        return false;
    }

    function primeraInteraccion() {
        try {
            if (sessionStorage.getItem(CLAVE_INI) === '1') return;
            sessionStorage.setItem(CLAVE_INI, '1');
            var fin = Date.now() + DURACION_MS;
            sessionStorage.setItem(CLAVE_FIN, String(fin));
        } catch(e) {}
        mostrarElementos();
        var fin2 = Date.now() + DURACION_MS;
        try { fin2 = parseInt(sessionStorage.getItem(CLAVE_FIN), 10) || fin2; } catch(e) {}
        arrancarCuenta(fin2);
    }

    // Si ya estaba iniciado (navegación encadenada), mostrar al cargar
    if (!iniciarSiProcede()) {
        window.addEventListener('click', primeraInteraccion, { once: true });
        window.addEventListener('keydown', primeraInteraccion, { once: true });
    }
    // Re-evaluar por si el DOM aún no tenía los elementos al ejecutar el script
    document.addEventListener('DOMContentLoaded', function() {
        iniciarSiProcede();
    });
})();
</script>
"""

INYECCION = (
    _PLANTILLA
    .replace("%%ANCHO%%", ANCHO)
    .replace("%%ALTO%%", ALTO)
    .replace("%%MARGEN_SUP%%", MARGEN_SUP)
    .replace("%%MARGEN_DER%%", MARGEN_DER)
).encode()

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=RAIZ, **k)

    def do_GET(self):
        if self.path.startswith("/__escudo/"):
            if not ESCUDO:
                self.send_error(404); return
            with open(ESCUDO, "rb") as f:
                datos = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "image/webp")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(datos)))
            self.end_headers()
            self.wfile.write(datos)
            return
        ruta = self.translate_path(self.path)
        if os.path.isdir(ruta):
            ruta = os.path.join(ruta, "index.html")
        if ruta.lower().endswith((".html", ".htm")) and os.path.isfile(ruta):
            with open(ruta, "rb") as f:
                datos = f.read()
            low = datos.lower()
            i = low.rfind(b"</body>")
            datos = datos[:i] + INYECCION + datos[i:] if i != -1 else datos + INYECCION
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(datos)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(datos)
            return
        super().do_GET()

    def log_message(self, *a):
        pass

print(f"Sirviendo {RAIZ} en el puerto {PUERTO} | escudo: {ESCUDO}", flush=True)
http.server.ThreadingHTTPServer(("", PUERTO), H).serve_forever()