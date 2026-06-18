# HETNA CNC — Documentación Técnica Completa
## Cotizador Profesional Android v1.0

---

## ESTRUCTURA DEL PROYECTO

```
hetna_cnc/
├── pubspec.yaml                          # Dependencias Flutter
├── supabase/
│   └── schema.sql                        # Base de datos completa
└── lib/
    ├── main.dart                         # Punto de entrada + tema
    ├── models/
    │   └── models.dart                   # Todos los modelos de datos
    ├── services/
    │   ├── supabase_service.dart         # CRUD completo Supabase
    │   ├── whatsapp_service.dart         # Mensajes WA prellenados
    │   ├── pdf_service.dart              # Generación PDF profesional
    │   └── notificaciones_service.dart   # Alertas push locales
    └── screens/
        ├── home_screen.dart              # Navegación inferior (6 tabs)
        ├── inicio_screen.dart            # Dashboard + estadísticas
        ├── alertas_screen.dart           # Seguimientos pendientes
        ├── clientes_screen.dart          # CRM de clientes
        ├── cotizar_screen.dart           # Cotizador + catálogo/PDF
        ├── avances_screen.dart           # Estado de pedidos
        └── config_screen.dart            # Configuración autollenado
```

---

## PASOS DE INSTALACIÓN

### PASO 1 — Crear cuenta en Supabase (gratis)
1. Ir a https://supabase.com → Sign Up con Google
2. New Project → nombre: `hetna-cnc` → región: `us-east-1`
3. Guardar la contraseña que genera (la necesitas después)

### PASO 2 — Crear la base de datos
1. En Supabase → SQL Editor → New Query
2. Copiar todo el contenido de `supabase/schema.sql`
3. Presionar **Run** (botón azul)
4. Verificar que aparezca: "Success. No rows returned"

### PASO 3 — Obtener credenciales
1. En Supabase → Settings → API
2. Copiar:
   - **Project URL** → pegar en `main.dart` como `supabaseUrl`
   - **anon public key** → pegar en `main.dart` como `supabaseKey`

### PASO 4 — Configurar Flutter
```bash
# Instalar Flutter si no lo tienes:
# https://docs.flutter.dev/get-started/install/windows/mobile

# En la carpeta del proyecto:
flutter pub get

# Verificar que todo esté bien:
flutter doctor
```

### PASO 5 — Generar APK
```bash
# APK para instalar directamente:
flutter build apk --release

# APK split (más pequeña, recomendada):
flutter build apk --split-per-abi --release

# El archivo queda en:
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### PASO 6 — Instalar en el teléfono
1. Conectar teléfono Android con cable USB
2. Activar "Opciones de desarrollador" → "Depuración USB"
3. O copiar el APK y abrir desde Archivos → instalar

---

## MÓDULOS Y FUNCIONALIDADES

### MÓDULO 1 — Dashboard (Inicio)
- Estadísticas del mes: solicitudes elaboradas vs pedidos entregados
- Banner rojo de alertas pendientes con contador
- Últimas cotizaciones con estado visual
- Accesos rápidos a las funciones principales

### MÓDULO 2 — Alertas (Seguimiento automático)
**Cómo funciona la Opción B (gratis):**
- Al enviar una cotización por WA, la app programa 3 notificaciones push locales:
  - **Día 3:** "Seguimiento cotización"
  - **Día 5:** "Cotización por vencer"
  - **Día 7:** "Enviar cupón de cierre"
- Cuando llega la notificación, el vendedor la toca
- Se abre la pantalla de Alertas con el mensaje ya redactado
- Toca "Abrir WhatsApp" → se abre WA con el mensaje prellenado
- El vendedor da "Enviar" → un solo toque
- Al completar, la alerta desaparece

**Mensajes automáticos disponibles:**
1. Seguimiento día 3 — pregunta amable
2. Seguimiento día 5 — mensaje de urgencia con fecha vencimiento
3. Cupón día 7 — código único por folio (5% descuento)
4. Post-entrega — links redes sociales + cupón 3% por seguirnos
5. Avance de pedido — notificación de etapa completada

### MÓDULO 3 — Clientes (CRM)
**Campos registrados:**
- Nombre, empresa, RFC
- Domicilio completo (calle, colonia, ciudad, estado, CP)
- Teléfono y WhatsApp (separados)
- Correo, tipo de cliente, notas
- Historial de cotizaciones vinculado

**Tipos de cliente:**
- Cliente potencial / Cliente activo / Cliente frecuente / Distribuidor

### MÓDULO 4 — Cotizar (2 sub-vistas)

**Sub-vista A: Cotización**
- Seleccionar cliente del CRM
- Agregar productos del catálogo con búsqueda
- Configurar: fecha entrega, días hábiles, condición de entrega, método de pago, notas
- Calcular: subtotal, descuento %, IVA 16%, envío, total
- Generar PDF profesional con logo y datos de empresa
- Enviar por WhatsApp (mensaje completo con desglose)
- Convertir en Pedido (pasa al módulo de Avances)

**Sub-vista B: Catálogo / PDF**
- Productos agrupados por categoría con chips filtrables:
  - Maquinaria CNC / Refacciones / Herramientas / Consumibles / Servicios / Diseños CNC
- Botón "Enviar catálogo completo por WhatsApp"
- PDFs almacenados (catálogos, fichas técnicas, manuales):
  - Botón ojo: ver el PDF
  - Botón verde: enviar por WhatsApp con mensaje prellenado

### MÓDULO 5 — Avances (Seguimiento de pedidos)
**Etapas del pedido:**
Pedido → Pago → Producción → Pruebas → Entrega → Entregado

**Funciones:**
- Barra de progreso visual por pedido
- Fecha estimada de entrega
- Alerta visual cuando la entrega es inminente (rojo)
- "Próxima alerta: mañana 9am" (recordatorio para notificar)
- Botón "Notificar avance" → abre WA con mensaje de actualización
- Al marcar "Entregado" → alerta automática para enviar redes sociales

### MÓDULO 6 — Configuración (Autollenado)
**Datos que se autollenan en todos los formularios:**
- Nombre comercial, RFC, dirección, teléfonos, correo, web
- Redes sociales (para mensaje post-entrega)
- IVA por defecto (16% / sin IVA / preguntar)
- Vigencia de cotización por defecto
- Método de pago por defecto
- Condición de entrega por defecto
- Switches de cada alerta automática (activar/desactivar)

---

## BASE DE DATOS — TABLAS

| Tabla | Descripción |
|-------|-------------|
| `configuracion_empresa` | Datos empresa + config por defecto |
| `clientes` | CRM completo |
| `categorias_producto` | 6 categorías con colores |
| `productos` | Catálogo con precios y stock |
| `pdfs_catalogo` | PDFs almacenados para envío |
| `cotizaciones` | Cotizaciones con estado |
| `cotizacion_items` | Líneas de cada cotización |
| `pedidos` | Pedidos activos |
| `pedido_avances` | Historial de etapas |
| `alertas` | Seguimientos pendientes |

**Vistas automáticas:**
- `v_alertas_pendientes` — Alertas con datos de cliente listos
- `v_estadisticas_mes` — KPIs del dashboard

**Triggers automáticos:**
- Al cambiar cotización a "Enviada" → crea alertas día 3, 5 y 7
- Al cambiar pedido a "Entregado" → crea alerta post-entrega redes

---

## DEPENDENCIAS FLUTTER

```yaml
supabase_flutter: ^2.3.0      # Backend y base de datos
pdf: ^3.10.8                   # Generación PDF
printing: ^5.12.0              # Ver/compartir/imprimir PDF
url_launcher: ^6.2.5           # Abrir WhatsApp
flutter_local_notifications    # Alertas push locales
sqflite: ^2.3.2               # Base de datos local offline
intl: ^0.19.0                  # Formato de moneda y fechas
file_picker: ^8.0.3           # Subir PDFs al catálogo
image_picker: ^1.0.7          # Fotos de productos
```

---

## PERMISOS ANDROID (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

---

## GLOSARIO DE ESTADOS

**Cotización:**
- Borrador → Enviada → Aprobada / Rechazada / Vencida / Pedido

**Pedido:**
- Pedido → Pago → Produccion → Pruebas → Entrega → Entregado / Cancelado

---

## EVOLUCIÓN FUTURA (FASE 2 y 3)

### Fase 2 — Integraciones
- Gmail API: resumen diario de pendientes por correo
- Google Calendar: fechas de entrega sincronizadas
- Google Drive: respaldo automático de PDFs

### Fase 3 — ERP Completo
- WhatsApp Business API (mensajes automáticos sin tocar el teléfono)
- Facturación CFDI 4.0
- Punto de venta
- Control de inventario avanzado
- Órdenes de trabajo CNC
- Portal web para clientes

---

## SOPORTE TÉCNICO

Para preguntas sobre el código o instalación, contactar al desarrollador
con este documento como referencia.

Proyecto desarrollado para: **HETNA CNC**
Web: www.hetnacnc.com
