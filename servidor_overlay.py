#!/usr/bin/env python3
"""Servidor local que sirve la carpeta de la presentación e inyecta el escudo
CINAE (fondo transparente, giro lento) en la esquina superior derecha de
TODOS los .html, sin tener que editarlos."""
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

# Tamaño máximo 2 cm x 3 cm (CSS cm). Ajustá ANCHO/ALTO si querés otra medida.
ANCHO, ALTO, MARGEN_SUP, MARGEN_DER = "2.1cm", "3.15cm", "0.8cm", "1.3cm"
INYECCION = f"""
<img id="escudo-cinae" src="/__escudo/cinae3d_lento.webp" alt=""
 style="position:fixed;top:{MARGEN_SUP};right:{MARGEN_DER};width:{ANCHO};height:{ALTO};
 max-width:{ANCHO};max-height:{ALTO};object-fit:contain;background:transparent;
 pointer-events:none;z-index:2147483647;">
""".encode()

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
