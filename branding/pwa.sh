#!/usr/bin/env bash
# Convierte el build web de Flutter en una app instalable desde el navegador
# (PWA): manifest con nombre, colores e íconos de HETNA CNC; título y
# descripción en index.html; y un aviso dentro de la app con el botón
# "Instalar" (Chrome, Edge, Samsung Internet) o la instrucción para iPhone
# (Safari: Compartir → Añadir a pantalla de inicio).
#
# Uso: bash branding/pwa.sh tmp_app/build/web
# La llama el workflow build-web antes de subir a hetnacnc.com/cotizador/.
set -euo pipefail
WEB="${1:?carpeta build/web}"

# --- manifest.json (Flutter genera uno con "hetna_cnc" / "A new Flutter project.") ---
cat > "$WEB/manifest.json" << 'JSON'
{
  "name": "HETNA CNC — Sistema de gestión para talleres",
  "short_name": "HETNA CNC",
  "description": "Cotiza, cobra y controla tu taller CNC desde el celular. Gratis para empezar.",
  "id": "/cotizador/",
  "start_url": "/cotizador/",
  "scope": "/cotizador/",
  "display": "standalone",
  "orientation": "portrait-primary",
  "background_color": "#142033",
  "theme_color": "#142033",
  "lang": "es-MX",
  "categories": ["business", "productivity", "utilities"],
  "prefer_related_applications": false,
  "icons": [
    { "src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "icons/Icon-maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable" },
    { "src": "icons/Icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
JSON

# --- index.html: título, descripción, colores y aviso de instalación ---
IDX="$WEB/index.html"
sed -i 's#<title>hetna_cnc</title>#<title>HETNA CNC</title>#' "$IDX"
sed -i 's#content="A new Flutter project."#content="Cotiza, cobra y controla tu taller CNC desde el celular. Gratis para empezar."#' "$IDX"
sed -i 's#<meta name="apple-mobile-web-app-title" content="hetna_cnc">#<meta name="apple-mobile-web-app-title" content="HETNA CNC">#' "$IDX"
# barra de estado y color del tema (Android pinta la barra con theme-color)
sed -i 's#</head>#  <meta name="theme-color" content="\#142033">\n  <link rel="apple-touch-icon" sizes="192x192" href="icons/Icon-192.png">\n</head>#' "$IDX"

# aviso de instalación: se inyecta antes de </body>
cat > /tmp/hetna-instalar.html << 'HTML'
<div id="hetna-instalar" style="display:none;position:fixed;left:12px;right:12px;bottom:12px;z-index:2147483000;background:#142033;color:#fff;border-radius:14px;padding:12px 14px;font:14px/1.35 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;box-shadow:0 10px 30px rgba(0,0,0,.4);align-items:center;gap:12px;max-width:520px;margin:0 auto">
  <img src="icons/Icon-192.png" alt="" width="44" height="44" style="border-radius:11px;flex:none">
  <div style="flex:1;min-width:0"><b style="font-size:15px">Instala HETNA CNC en tu celular</b><br><span id="hetna-instalar-txt" style="opacity:.85">Queda en tu pantalla de inicio y abre como una app, sin tienda.</span></div>
  <button id="hetna-instalar-btn" type="button" style="flex:none;background:#FF6A1A;color:#fff;border:0;border-radius:10px;padding:10px 14px;font-weight:700;font-size:14px;cursor:pointer">Instalar</button>
  <button id="hetna-instalar-x" type="button" aria-label="Cerrar" style="flex:none;background:transparent;color:#fff;border:0;font-size:18px;opacity:.7;cursor:pointer;padding:4px 6px">✕</button>
</div>
<script>
(function () {
  try {
    var instalada = (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) || window.navigator.standalone === true;
    if (instalada) return;
    var hasta = Number(localStorage.getItem('hetna-instalar-hasta') || 0);
    if (hasta > Date.now()) return;
  } catch (e) {}
  var caja = document.getElementById('hetna-instalar');
  var btn = document.getElementById('hetna-instalar-btn');
  var txt = document.getElementById('hetna-instalar-txt');
  var x = document.getElementById('hetna-instalar-x');
  var evento = null;
  function mostrar() { caja.style.display = 'flex'; }
  function ocultar(dias) {
    caja.style.display = 'none';
    try { localStorage.setItem('hetna-instalar-hasta', String(Date.now() + (dias || 7) * 86400000)); } catch (e) {}
  }
  var ua = navigator.userAgent || '';
  var iOS = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  // Chrome, Edge, Samsung Internet, Brave: el navegador avisa cuando se puede instalar
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    evento = e;
    btn.style.display = '';
    setTimeout(mostrar, 2500);
  });
  btn.addEventListener('click', function () {
    if (!evento) return;
    evento.prompt();
    evento.userChoice.then(function (r) { ocultar(r && r.outcome === 'accepted' ? 365 : 3); evento = null; });
  });
  x.addEventListener('click', function () { ocultar(7); });
  if (iOS) {
    var safari = /Safari/.test(ua) && !/CriOS|FxiOS|EdgiOS/.test(ua);
    txt.innerHTML = safari
      ? 'Toca <b>Compartir</b> (el cuadrito con la flecha) y luego <b>Añadir a pantalla de inicio</b>.'
      : 'Ábrela en <b>Safari</b>, toca <b>Compartir</b> y luego <b>Añadir a pantalla de inicio</b>.';
    btn.style.display = 'none';
    setTimeout(mostrar, 4000);
  }
  window.addEventListener('appinstalled', function () { ocultar(365); });
})();
</script>
HTML
python3 - "$IDX" /tmp/hetna-instalar.html << 'PY'
import sys
idx, inj = sys.argv[1], sys.argv[2]
html = open(idx, encoding="utf-8").read()
bloque = open(inj, encoding="utf-8").read()
assert "</body>" in html, "index.html sin </body>"
html = html.replace("</body>", bloque + "\n</body>", 1)
open(idx, "w", encoding="utf-8").write(html)
print("index.html listo para instalar desde el navegador")
PY
