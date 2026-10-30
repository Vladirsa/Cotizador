// lib/services/planes.dart
// HETNA CNC — Qué módulos abre cada plan.
//
// Es el ÚNICO lugar donde se decide qué está bloqueado. La barra inferior, el
// menú "Más" y los botones dentro de las pantallas preguntan aquí con
// AuthService.puede('modulo'). Para mover un módulo de plan, se cambia una
// línea de `_modulosPorPlan` y listo.
//
// Los nombres de los planes son los mismos que en hetnacnc.com
// (taller.cuentas): gratis / prueba / taller / pro / industrial.
// Los nombres viejos de la app siguen funcionando:
//   trial   → prueba      (todo abierto mientras no venza)
//   premium → pro
//   master  → industrial  (cuenta de HETNA, todo abierto)

enum Plan { gratis, taller, pro, industrial }

class Planes {
  // Precios publicados en hetnacnc.com/servicios/cotizador-cnc (MXN al mes)
  static const precios = {
    Plan.gratis: 0,
    Plan.taller: 299,
    Plan.pro: 599,
    Plan.industrial: 1199,
  };

  static const nombres = {
    Plan.gratis: 'Gratis',
    Plan.taller: 'Taller',
    Plan.pro: 'Pro',
    Plan.industrial: 'Industrial',
  };

  // Cotizaciones nuevas por mes (null = sin límite). Igual que la web.
  static const limiteCotizacionesGratis = 5;

  // Cotizaciones profesionales de muestra en el plan Gratis (en total, no por mes)
  static const muestrasProfesionalGratis = 1;

  // Qué incluye cada plan: lo enseña la pantalla de planes y el aviso
  // "Disponible en plan…" (así el taller ve todo lo que se lleva, no sólo lo
  // que le faltó). Igual que hetnacnc.com/servicios/cotizador-cnc.
  static const incluye = {
    Plan.gratis: [
      '5 cotizaciones sencillas al mes', 'PDF con marca de agua HETNA CNC', '1 cotización profesional de muestra',
      'Clientes, productos y avances', 'Alertas y seguimiento por WhatsApp', 'Calculadora CNC y Envíos HETNA', '1 usuario',
    ],
    Plan.taller: [
      'Cotizaciones ilimitadas', 'PDF con tu logo, sin marca de agua', 'Cotización profesional (formato internacional)',
      'Sube DXF, SVG, STL u OBJ: plano con medidas en la cotización', 'Simulador de costos con 3 precios y anticipo a tu medida',
      'Costos de tu taller', 'Gastos y compras', 'Avisos de avance por WhatsApp', 'Fotos en productos', '2 usuarios',
    ],
    Plan.pro: [
      'Todo lo de Taller', 'Inventario de bodega', 'Marketing: cupones y plantillas de WhatsApp', 'Reportes Excel',
      'Dashboard de utilidad, gastos y conversión', 'Equipo con roles: 5 usuarios',
    ],
    Plan.industrial: [
      'Todo lo de Pro', 'Facturación electrónica (CFDI)', 'API para conectar tu sistema', 'Usuarios ilimitados',
    ],
  };

  // Usuarios por taller (null = sin límite). Igual que la web.
  static const usuarios = {
    Plan.gratis: 1,
    Plan.taller: 2,
    Plan.pro: 5,
    Plan.industrial: null,
  };

  // Plan mínimo que abre cada módulo. Lo que no aparece aquí es gratis.
  static const _modulosPorPlan = <String, Plan>{
    // ── Taller ($299) ──
    'cotizaciones_ilimitadas': Plan.taller, // Gratis: 5 al mes
    'cotizacion_profesional': Plan.taller,  // Gratis: 1 de muestra
    // (la profesional es la que permite subir DXF/SVG/STL/OBJ con plano
    //  acotado: en Gratis sólo con esa muestra)
    'pdf_sin_marca': Plan.taller,   // Gratis: PDF con marca de agua HETNA CNC
    'simulador': Plan.taller,       // Simulador de costos con 3 precios
    'costos_taller': Plan.taller,   // Costos fijos, máquinas y mano de obra
    'config_simulador': Plan.taller,
    'gastos': Plan.taller,
    'equipo': Plan.taller,          // Usuarios: Taller 2, Pro 5, Industrial sin límite
    // ── Pro ($599) ──
    'inventario': Plan.pro,
    'marketing': Plan.pro,          // incluye cupones y plantillas de WhatsApp
    'reportes': Plan.pro,           // Reportes Excel
    'dashboard_avanzado': Plan.pro, // Gráficas de utilidad, gastos y conversión
    // ── Industrial ($1,199) ──
    'facturacion': Plan.industrial, // CFDI
    'api': Plan.industrial,         // Llave de API para conectar su sistema
  };

  // Módulos que siempre están abiertos (también para Gratis). Se listan para
  // que quede claro que NO se bloquean: la calculadora CNC y los envíos traen
  // gente a la plataforma y los envíos dejan margen a HETNA en cada guía.
  static const siempreAbiertos = [
    'inicio', 'alertas', 'cotizar', 'avances', 'clientes', 'productos',
    'config', 'calculadora_cnc', 'envios', 'tienda', 'foro', 'laboratorio_cam',
    'licitaciones',
  ];

  // Convierte el texto guardado en Supabase al plan que manda.
  // `pruebaVigente` = prueba/trial que todavía no vence → todo abierto.
  static Plan efectivo(String? plan, {required bool pruebaVigente}) {
    switch (plan) {
      case 'master':
      case 'industrial':
        return Plan.industrial;
      case 'premium':
      case 'pro':
        return Plan.pro;
      case 'taller':
        return Plan.taller;
      case 'trial':
      case 'prueba':
        return pruebaVigente ? Plan.industrial : Plan.gratis;
      default:
        return Plan.gratis;
    }
  }

  static Plan planMinimo(String modulo) => _modulosPorPlan[modulo] ?? Plan.gratis;

  static bool abre(Plan actual, String modulo) => actual.index >= planMinimo(modulo).index;
}
