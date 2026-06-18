# GUÍA: Compilar APK con GitHub Actions
## HETNA CNC — Sin instalar nada en tu computadora

---

## ¿QUÉ ES ESTO?
GitHub Actions compila tu APK gratis en servidores de Microsoft.
Cada vez que subas un cambio, genera un APK nuevo automáticamente.
Solo necesitas crear una cuenta gratuita en GitHub.

---

## PASO 1 — Crear cuenta en GitHub (si no tienes)

1. Ir a **https://github.com**
2. Click en "Sign up"
3. Crear cuenta con tu correo (gratis)

---

## PASO 2 — Crear repositorio nuevo

1. En GitHub, click en el botón verde **"New"** (o el ícono "+")
2. Llenar:
   - **Repository name:** `hetna-cnc`
   - **Visibility:** Private ← MUY IMPORTANTE (tu código es privado)
   - **NO** marcar ninguna casilla adicional
3. Click **"Create repository"**

---

## PASO 3 — Subir el proyecto a GitHub

**Opción A — Desde la web (sin instalar Git):**

1. En tu nuevo repositorio, click en **"uploading an existing file"**
2. Descomprimir el ZIP `hetna_cnc_proyecto.zip` en tu computadora
3. Arrastrar TODA la carpeta `hetna_cnc` a la ventana de GitHub
4. En "Commit changes" escribir: `primer commit`
5. Click **"Commit changes"**

**Opción B — Con Git instalado:**
```bash
cd hetna_cnc
git init
git add .
git commit -m "primer commit"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/hetna-cnc.git
git push -u origin main
```

---

## PASO 4 — Agregar tus credenciales de Supabase (SEGURO)

⚠️ NUNCA pongas las credenciales directamente en el código.
Se guardan como "Secrets" en GitHub (encriptados, nadie los ve).

1. En tu repositorio GitHub → click en **"Settings"** (pestaña superior)
2. En el menú izquierdo → **"Secrets and variables"** → **"Actions"**
3. Click **"New repository secret"** y agregar DOS secrets:

**Secret 1:**
- Name: `SUPABASE_URL`
- Secret: `https://TU_PROYECTO.supabase.co`
  (lo encuentras en Supabase → Settings → API → Project URL)

**Secret 2:**
- Name: `SUPABASE_ANON_KEY`
- Secret: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (la clave larga)
  (lo encuentras en Supabase → Settings → API → anon public)

4. Click **"Add secret"** en cada uno

---

## PASO 5 — Ejecutar la compilación

La compilación se ejecuta automáticamente cuando subes código.
Para ejecutarla manualmente la primera vez:

1. En tu repositorio → click en la pestaña **"Actions"**
2. En el menú izquierdo → click en **"Build HETNA CNC APK"**
3. Click en el botón **"Run workflow"** (lado derecho)
4. Click en el botón verde **"Run workflow"**
5. ¡Listo! Verás el proceso en tiempo real

⏱ La primera compilación tarda **15-20 minutos** (descarga Flutter y Android SDK).
Las siguientes tardan **5-8 minutos** (usa caché).

---

## PASO 6 — Descargar tu APK

**Opción A — Desde Artifacts:**
1. En Actions → click en el workflow que terminó (ícono verde ✓)
2. Bajar hasta la sección **"Artifacts"**
3. Click en **"HetnaCNC-APK"** → se descarga un ZIP
4. Descomprimir → tienes los APKs

**Opción B — Desde Releases (más fácil):**
1. En tu repositorio → click en **"Releases"** (lado derecho)
2. Click en la versión más reciente
3. Descargar directamente el archivo `.apk`

---

## PASO 7 — Instalar en tu teléfono Android

1. Enviar el APK a tu teléfono (WhatsApp, correo, USB, o Drive)
2. En el teléfono → abrir el archivo APK
3. Si aparece "Fuentes desconocidas":
   - Ir a **Ajustes → Seguridad → Instalar apps desconocidas**
   - Activar para el navegador o explorador de archivos
4. Instalar y abrir

**¿Qué APK descargar?**
- `HetnaCNC_arm64_FECHA.apk` → para teléfonos modernos (2018+) ✅
- `HetnaCNC_arm32_FECHA.apk` → para teléfonos más antiguos

---

## CADA VEZ QUE HAGAS UN CAMBIO

1. Sube los archivos modificados a GitHub
2. GitHub Actions compila automáticamente
3. En ~8 minutos tienes el APK nuevo en Releases
4. Instala encima del anterior (no pierde datos)

---

## COSTO

| Servicio | Costo |
|----------|-------|
| GitHub (repositorio privado) | GRATIS |
| GitHub Actions (2,000 min/mes) | GRATIS |
| Supabase (hasta 500MB datos) | GRATIS |
| Hosting APK en GitHub Releases | GRATIS |
| **TOTAL** | **$0 MXN** |

---

## PROBLEMAS FRECUENTES

**Error: "flutter pub get failed"**
→ Revisa que el archivo `pubspec.yaml` esté en la raíz del proyecto

**Error: "Supabase URL not found"**
→ Verifica que los Secrets se llamen exactamente `SUPABASE_URL` y `SUPABASE_ANON_KEY`

**APK no instala en el teléfono**
→ Activa "Fuentes desconocidas" en Ajustes de seguridad del teléfono

**Error de compilación en Actions**
→ Click en el workflow fallido → click en "build" → ver el error específico
→ Compartir el error para ayudarte a resolverlo

---

## SOPORTE

Si algo falla en el proceso, comparte:
1. El error exacto que aparece en GitHub Actions
2. En qué paso falló

Proyecto: HETNA CNC Cotizador Pro
Web: www.hetnacnc.com
