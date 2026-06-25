// lib/screens/simulador_screen.dart
// HETNA CNC — Simulador de costos por tipo de taller
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'cotizar_screen.dart';

// ══════════════════════════════════════════════════════
// MODELOS DE DATOS
// ══════════════════════════════════════════════════════

class TipoTaller {
  final String id;
  final String nombre;
  final String emoji;
  final String descripcion;
  final Color color;
  final List<TipoTrabajo> trabajos;

  const TipoTaller({
    required this.id, required this.nombre, required this.emoji,
    required this.descripcion, required this.color, required this.trabajos,
  });
}

class TipoTrabajo {
  final String id;
  final String nombre;
  final String emoji;
  final List<ParametroCosto> parametros;

  const TipoTrabajo({
    required this.id, required this.nombre,
    required this.emoji, required this.parametros,
  });
}

class ParametroCosto {
  final String id;
  final String label;
  final TipoParametro tipo;
  final List<String>? opciones;
  final List<double>? factores; // factor por opción
  final String? unidad;
  final double? valorDefault;
  final double? min;
  final double? max;

  const ParametroCosto({
    required this.id, required this.label, required this.tipo,
    this.opciones, this.factores, this.unidad,
    this.valorDefault, this.min, this.max,
  });
}

enum TipoParametro { selector, numero, toggle }

class ResultadoCosto {
  final double costoMaterial;
  final double costoMaquina;
  final double costoManoObra;
  final double costoGas;
  final double subtotal;
  final double margen;
  final double total;
  final double horasEstimadas;
  final String descripcionTrabajo;

  ResultadoCosto({
    required this.costoMaterial, required this.costoMaquina,
    required this.costoManoObra, required this.costoGas,
    required this.subtotal, required this.margen,
    required this.total, required this.horasEstimadas,
    required this.descripcionTrabajo,
  });
}

// ══════════════════════════════════════════════════════
// CATÁLOGO DE TALLERES Y TRABAJOS
// ══════════════════════════════════════════════════════

final List<TipoTaller> talleresCatalogo = [

  // ── CNC ROUTER ──────────────────────────────────────
  TipoTaller(
    id: 'cnc_router', nombre: 'CNC Router', emoji: '🔧',
    descripcion: 'Madera, MDF, acrílico, aluminio',
    color: const Color(0xFF185fa5),
    trabajos: [
      TipoTrabajo(id: 'cnc_corte2d', nombre: 'Corte 2D', emoji: '✂️', parametros: [
        ParametroCosto(id: 'material', label: 'Material', tipo: TipoParametro.selector,
          opciones: ['MDF 3mm', 'MDF 9mm', 'MDF 15mm', 'Triplay', 'Acrílico', 'Aluminio'],
          factores: [1.0, 1.3, 1.6, 1.2, 1.8, 3.0]),
        ParametroCosto(id: 'ancho', label: 'Ancho (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 60, min: 1, max: 244),
        ParametroCosto(id: 'alto', label: 'Alto (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 60, min: 1, max: 122),
        ParametroCosto(id: 'complejidad', label: 'Complejidad del corte', tipo: TipoParametro.selector,
          opciones: ['Simple (líneas rectas)', 'Medio (curvas suaves)', 'Complejo (celosía / arabescos)', 'Muy complejo (celosía densa)'],
          factores: [1.0, 1.8, 3.2, 4.8]),
        ParametroCosto(id: 'cantidad', label: 'Cantidad de piezas', tipo: TipoParametro.numero,
          unidad: 'pzas', valorDefault: 1, min: 1, max: 500),
      ]),
      TipoTrabajo(id: 'cnc_talla3d', nombre: 'Talla 3D / Relieve', emoji: '🗿', parametros: [
        ParametroCosto(id: 'material', label: 'Material', tipo: TipoParametro.selector,
          opciones: ['MDF', 'Pino', 'Cedro', 'Parota', 'Encino'],
          factores: [1.0, 1.2, 1.5, 2.0, 1.8]),
        ParametroCosto(id: 'ancho', label: 'Ancho (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 30, min: 1, max: 244),
        ParametroCosto(id: 'alto', label: 'Alto (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 30, min: 1, max: 122),
        ParametroCosto(id: 'profundidad', label: 'Profundidad del tallado', tipo: TipoParametro.selector,
          opciones: ['Superficial (< 5mm)', 'Media (5-15mm)', 'Profunda (> 15mm)'],
          factores: [1.0, 1.6, 2.4]),
        ParametroCosto(id: 'detalle', label: 'Nivel de detalle', tipo: TipoParametro.selector,
          opciones: ['Básico (texto, formas simples)', 'Medio (relieves, logo)', 'Alto (figura detallada)', 'Muy alto (rostro, paisaje)'],
          factores: [1.0, 2.0, 3.5, 5.0]),
        ParametroCosto(id: 'cantidad', label: 'Cantidad', tipo: TipoParametro.numero,
          unidad: 'pzas', valorDefault: 1, min: 1, max: 100),
      ]),
      TipoTrabajo(id: 'cnc_mueble', nombre: 'Mueble / Gabinete', emoji: '🪑', parametros: [
        ParametroCosto(id: 'material', label: 'Material', tipo: TipoParametro.selector,
          opciones: ['MDF 9mm', 'MDF 15mm', 'MDF 18mm', 'Triplay 9mm', 'Triplay 15mm'],
          factores: [1.0, 1.2, 1.4, 1.1, 1.3]),
        ParametroCosto(id: 'tableros', label: 'Número de tableros 4x8', tipo: TipoParametro.numero,
          unidad: 'tableros', valorDefault: 1, min: 1, max: 20),
        ParametroCosto(id: 'complejidad', label: 'Complejidad del diseño', tipo: TipoParametro.selector,
          opciones: ['Simple (cajones rectos)', 'Medio (puertas, bisagras)', 'Complejo (curvas, tallado)', 'Premium (todo incluido)'],
          factores: [1.0, 1.5, 2.2, 3.0]),
        ParametroCosto(id: 'acabado', label: 'Acabado', tipo: TipoParametro.selector,
          opciones: ['Sin acabado (solo corte)', 'Lija + sellador', 'Pintura', 'Laca premium'],
          factores: [1.0, 1.3, 1.6, 2.0]),
      ]),
    ]),

  // ── LÁSER CO2 ───────────────────────────────────────
  TipoTaller(
    id: 'laser_co2', nombre: 'Láser CO2', emoji: '🔴',
    descripcion: 'Madera, acrílico, cuero, tela, MDF',
    color: const Color(0xFFe24b4a),
    trabajos: [
      TipoTrabajo(id: 'co2_corte', nombre: 'Corte láser', emoji: '✂️', parametros: [
        ParametroCosto(id: 'material', label: 'Material', tipo: TipoParametro.selector,
          opciones: ['MDF 3mm', 'MDF 6mm', 'Acrílico 3mm', 'Acrílico 6mm', 'Madera 3mm', 'Cuero'],
          factores: [1.0, 1.4, 1.6, 2.0, 1.3, 1.8]),
        ParametroCosto(id: 'ancho', label: 'Ancho (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 30, min: 1, max: 130),
        ParametroCosto(id: 'alto', label: 'Alto (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 30, min: 1, max: 90),
        ParametroCosto(id: 'complejidad', label: 'Densidad del corte', tipo: TipoParametro.selector,
          opciones: ['Simple (pocas líneas)', 'Medio (figura geométrica)', 'Complejo (celosía)', 'Muy complejo (filigrana densa)'],
          factores: [1.0, 1.7, 3.0, 5.0]),
        ParametroCosto(id: 'cantidad', label: 'Cantidad', tipo: TipoParametro.numero,
          unidad: 'pzas', valorDefault: 1, min: 1, max: 500),
      ]),
      TipoTrabajo(id: 'co2_grabado', nombre: 'Grabado láser', emoji: '🖋️', parametros: [
        ParametroCosto(id: 'material', label: 'Material', tipo: TipoParametro.selector,
          opciones: ['MDF', 'Madera', 'Acrílico', 'Cuero', 'Vidrio', 'Piedra'],
          factores: [1.0, 1.2, 1.5, 1.4, 1.8, 2.0]),
        ParametroCosto(id: 'ancho', label: 'Ancho (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 20, min: 1, max: 130),
        ParametroCosto(id: 'alto', label: 'Alto (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 20, min: 1, max: 90),
        ParametroCosto(id: 'densidad', label: 'Densidad del grabado', tipo: TipoParametro.selector,
          opciones: ['Texto simple', 'Logo / imagen simple', 'Foto / imagen detallada', 'Foto alta resolución'],
          factores: [1.0, 1.8, 3.2, 5.0]),
        ParametroCosto(id: 'cantidad', label: 'Cantidad', tipo: TipoParametro.numero,
          unidad: 'pzas', valorDefault: 1, min: 1, max: 500),
      ]),
    ]),

  // ── LÁSER FIBRA ─────────────────────────────────────
  TipoTaller(
    id: 'laser_fibra', nombre: 'Láser Fibra', emoji: '⚡',
    descripcion: 'Grabado en metal, acero, aluminio, joyería',
    color: const Color(0xFFef9f27),
    trabajos: [
      TipoTrabajo(id: 'fibra_grabado', nombre: 'Grabado en metal', emoji: '🔩', parametros: [
        ParametroCosto(id: 'material', label: 'Material', tipo: TipoParametro.selector,
          opciones: ['Acero inox', 'Aluminio', 'Acero negro', 'Titanio', 'Latón', 'Cobre'],
          factores: [1.0, 0.9, 1.0, 1.8, 1.3, 1.4]),
        ParametroCosto(id: 'ancho', label: 'Ancho (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 10, min: 0.5, max: 30),
        ParametroCosto(id: 'alto', label: 'Alto (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 10, min: 0.5, max: 30),
        ParametroCosto(id: 'detalle', label: 'Detalle del grabado', tipo: TipoParametro.selector,
          opciones: ['Texto / número', 'Logo simple', 'Imagen / código QR', 'Foto / detalle fino'],
          factores: [1.0, 1.5, 2.5, 4.0]),
        ParametroCosto(id: 'profundidad', label: 'Tipo de grabado', tipo: TipoParametro.selector,
          opciones: ['Superficial (marcado)', 'Profundo (relieve)', 'Muy profundo (grabado fuerte)'],
          factores: [1.0, 2.0, 3.5]),
        ParametroCosto(id: 'cantidad', label: 'Cantidad', tipo: TipoParametro.numero,
          unidad: 'pzas', valorDefault: 1, min: 1, max: 1000),
      ]),
    ]),

  // ── PLASMA / CORTE METAL ────────────────────────────
  TipoTaller(
    id: 'plasma_cnc', nombre: 'Plasma CNC', emoji: '🔥',
    descripcion: 'Corte en acero, hierro, aluminio grueso',
    color: const Color(0xFF7c3aed),
    trabajos: [
      TipoTrabajo(id: 'plasma_corte', nombre: 'Corte plasma', emoji: '⚙️', parametros: [
        ParametroCosto(id: 'material', label: 'Material', tipo: TipoParametro.selector,
          opciones: ['Acero 1mm', 'Acero 2mm', 'Acero 3mm', 'Acero 4mm', 'Acero 6mm', 'Acero 8mm', 'Aluminio 2mm', 'Aluminio 4mm'],
          factores: [1.0, 1.2, 1.5, 1.8, 2.4, 3.2, 1.3, 1.7]),
        ParametroCosto(id: 'ancho', label: 'Ancho (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 50, min: 1, max: 200),
        ParametroCosto(id: 'alto', label: 'Alto (cm)', tipo: TipoParametro.numero,
          unidad: 'cm', valorDefault: 50, min: 1, max: 200),
        ParametroCosto(id: 'complejidad', label: 'Tipo de corte', tipo: TipoParametro.selector,
          opciones: ['Simple (cuadrado, rectángulo)', 'Medio (figura con curvas)', 'Complejo (celosía, texto)', 'Muy complejo (celosía densa, filigrana)'],
          factores: [1.0, 1.8, 3.5, 5.5]),
        ParametroCosto(id: 'densidad', label: 'Material eliminado', tipo: TipoParametro.selector,
          opciones: ['Poco (< 20% del área)', 'Medio (20-50%)', 'Mucho (50-75%)', 'Celosía densa (> 75%)'],
          factores: [1.0, 1.5, 2.5, 4.0]),
        ParametroCosto(id: 'cantidad', label: 'Cantidad', tipo: TipoParametro.numero,
          unidad: 'pzas', valorDefault: 1, min: 1, max: 200),
      ]),
    ]),

  // ── IMPRESIÓN 3D ────────────────────────────────────
  TipoTaller(
    id: 'impresion_3d', nombre: 'Impresión 3D', emoji: '🖨️',
    descripcion: 'FDM (PLA, ABS, PETG) y resina',
    color: const Color(0xFF1d9e75),
    trabajos: [
      TipoTrabajo(id: 'fdm', nombre: 'FDM (filamento)', emoji: '🧵', parametros: [
        ParametroCosto(id: 'material', label: 'Material', tipo: TipoParametro.selector,
          opciones: ['PLA', 'ABS', 'PETG', 'TPU (flexible)', 'ASA', 'Fibra de carbono'],
          factores: [1.0, 1.1, 1.2, 1.5, 1.4, 3.0]),
        ParametroCosto(id: 'volumen', label: 'Volumen aprox. (cm³)', tipo: TipoParametro.numero,
          unidad: 'cm³', valorDefault: 50, min: 1, max: 5000),
        ParametroCosto(id: 'relleno', label: 'Porcentaje de relleno', tipo: TipoParametro.selector,
          opciones: ['10% (decorativo)', '20% (normal)', '40% (resistente)', '80% (muy resistente)', '100% (sólido)'],
          factores: [0.5, 1.0, 1.4, 2.0, 2.8]),
        ParametroCosto(id: 'calidad', label: 'Calidad de impresión', tipo: TipoParametro.selector,
          opciones: ['Rápida (0.3mm)', 'Normal (0.2mm)', 'Alta (0.1mm)', 'Ultra (0.05mm)'],
          factores: [0.7, 1.0, 1.8, 3.2]),
        ParametroCosto(id: 'soporte', label: 'Necesita soportes', tipo: TipoParametro.toggle,
          factores: [1.0, 1.3]),
        ParametroCosto(id: 'cantidad', label: 'Cantidad', tipo: TipoParametro.numero,
          unidad: 'pzas', valorDefault: 1, min: 1, max: 100),
      ]),
      TipoTrabajo(id: 'resina', nombre: 'Resina (SLA/DLP)', emoji: '💎', parametros: [
        ParametroCosto(id: 'material', label: 'Tipo de resina', tipo: TipoParametro.selector,
          opciones: ['Estándar', 'Alta resistencia', 'Flexible', 'Transparente', 'Dental/médica'],
          factores: [1.0, 1.5, 1.4, 1.6, 3.0]),
        ParametroCosto(id: 'volumen', label: 'Volumen aprox. (cm³)', tipo: TipoParametro.numero,
          unidad: 'cm³', valorDefault: 20, min: 0.5, max: 500),
        ParametroCosto(id: 'detalle', label: 'Nivel de detalle', tipo: TipoParametro.selector,
          opciones: ['Básico', 'Medio', 'Alto (joyería, miniaturas)', 'Ultra fino'],
          factores: [1.0, 1.5, 2.5, 4.0]),
        ParametroCosto(id: 'cantidad', label: 'Cantidad', tipo: TipoParametro.numero,
          unidad: 'pzas', valorDefault: 1, min: 1, max: 50),
      ]),
    ]),

  // ── DISEÑO DIGITAL ──────────────────────────────────
  TipoTaller(
    id: 'diseno', nombre: 'Diseño Digital', emoji: '✏️',
    descripcion: 'Archivos DXF, SVG, STL, planos, vectorización',
    color: const Color(0xFF185fa5),
    trabajos: [
      TipoTrabajo(id: 'diseno_2d', nombre: 'Diseño 2D / Vectorización', emoji: '📐', parametros: [
        ParametroCosto(id: 'tipo', label: 'Tipo de diseño', tipo: TipoParametro.selector,
          opciones: ['Logo / texto simple', 'Figura geométrica', 'Ilustración media', 'Ilustración compleja', 'Vectorización de foto'],
          factores: [1.0, 1.3, 2.0, 3.5, 2.5]),
        ParametroCosto(id: 'revisiones', label: 'Rondas de revisión', tipo: TipoParametro.selector,
          opciones: ['Sin revisiones', '1 revisión', '2 revisiones', '3+ revisiones'],
          factores: [1.0, 1.2, 1.4, 1.7]),
        ParametroCosto(id: 'urgente', label: 'Entrega urgente (< 24hrs)', tipo: TipoParametro.toggle,
          factores: [1.0, 1.5]),
      ]),
      TipoTrabajo(id: 'diseno_3d', nombre: 'Modelado 3D', emoji: '🧊', parametros: [
        ParametroCosto(id: 'tipo', label: 'Tipo de modelo', tipo: TipoParametro.selector,
          opciones: ['Pieza mecánica simple', 'Producto / objeto', 'Personaje / figura', 'Arquitectura / mueble', 'Ingeniería compleja'],
          factores: [1.0, 1.5, 3.0, 2.0, 4.0]),
        ParametroCosto(id: 'revisiones', label: 'Rondas de revisión', tipo: TipoParametro.selector,
          opciones: ['Sin revisiones', '1 revisión', '2 revisiones', '3+ revisiones'],
          factores: [1.0, 1.2, 1.4, 1.7]),
        ParametroCosto(id: 'urgente', label: 'Entrega urgente', tipo: TipoParametro.toggle,
          factores: [1.0, 1.5]),
      ]),
    ]),
];

// ══════════════════════════════════════════════════════
// PANTALLA PRINCIPAL DEL SIMULADOR
// ══════════════════════════════════════════════════════

class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key});
  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  TipoTaller? _tallerSel;
  TipoTrabajo? _trabajoSel;
  final Map<String, dynamic> _valores = {};
  ResultadoCosto? _resultado;

  // Tarifas configurables (en producción vendrían de Supabase)
  double _tarifaMaquina = 150.0;   // $/hora
  double _tarifaManoObra = 80.0;   // $/hora
  double _tarifaDiseno = 200.0;    // $/hora base
  double _margenPct = 30.0;        // %
  double _precioMaterialBase = 350.0; // $/m² base

  final _fmt = NumberFormat('\$#,##0.00', 'es_MX');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Row(children: [
          Text('⚙️', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('Simulador de costos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: AppColors.azul)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined, color: AppColors.azul),
            tooltip: 'Configurar tarifas',
            onPressed: _editarTarifas),
        ]),
      body: _tallerSel == null
        ? _pantallaSeleccionTaller()
        : _trabajoSel == null
          ? _pantallaSeleccionTrabajo()
          : _pantallaParametros(),
    );
  }

  // ── PASO 1: Seleccionar tipo de taller ──────────────
  Widget _pantallaSeleccionTaller() {
    final items = <Widget>[
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.azul, Color(0xFF2d5a8e)]),
          borderRadius: BorderRadius.circular(12)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Simulador de costos', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          SizedBox(height: 4),
          Text('Selecciona el tipo de taller para calcular el costo',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        ])),
      const SizedBox(height: 16),
      const Text('TIPO DE TALLER',
        style: TextStyle(fontSize: 10, color: AppColors.textoSecundario,
          letterSpacing: 1.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
    ];
    for (final t in talleresCatalogo) {
      items.add(GestureDetector(
        onTap: () => setState(() {
          _tallerSel = t;
          _trabajoSel = null;
          _valores.clear();
          _resultado = null;
        }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grisBorde, width: 0.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(
                color: t.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(t.emoji,
                style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.nombre, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: t.color)),
              Text(t.descripcion, style: const TextStyle(
                fontSize: 12, color: AppColors.textoSecundario)),
              const SizedBox(height: 4),
              Text('''${t.trabajos.length} tipo${t.trabajos.length > 1 ? "s" : ""} de trabajo''',
                style: TextStyle(fontSize: 10, color: t.color)),
            ])),
            Icon(Icons.arrow_forward_ios, size: 14, color: t.color),
          ]))));
    }
    return ListView(padding: const EdgeInsets.all(16), children: items);
  }


  // ── PASO 2: Seleccionar tipo de trabajo ─────────────
  Widget _pantallaSeleccionTrabajo() {
    final t = _tallerSel!;
    final items = <Widget>[];
    for (final tr in t.trabajos) {
      items.add(GestureDetector(
        onTap: () {
          setState(() {
            _trabajoSel = tr;
            _valores.clear();
            _resultado = null;
            for (final p in tr.parametros) {
              if (p.tipo == TipoParametro.numero) {
                _valores[p.id] = p.valorDefault ?? 1.0;
              } else if (p.tipo == TipoParametro.selector) {
                _valores[p.id] = 0;
              } else if (p.tipo == TipoParametro.toggle) {
                _valores[p.id] = false;
              }
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Row(children: [
            Text(tr.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr.nombre, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: t.color)),
              Text('''${tr.parametros.length} parametros a configurar''',
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            ])),
            Icon(Icons.arrow_forward_ios, size: 14, color: t.color),
          ]))));
    }
    return Column(children: [
      Container(color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _tallerSel = null),
            child: Row(children: [
              const Icon(Icons.arrow_back_ios, size: 14, color: AppColors.azul),
              const SizedBox(width: 4),
              Text('''${t.emoji} ${t.nombre}''',
                style: TextStyle(fontSize: 14, color: t.color, fontWeight: FontWeight.w600)),
            ])),
        ])),
      Expanded(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('TIPO DE TRABAJO',
            style: TextStyle(fontSize: 10, color: AppColors.textoSecundario,
              letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...items,
        ])),
    ]);
  }


  // ── PASO 3: Parámetros y resultado ──────────────────
  Widget _pantallaParametros() {
    final t = _tallerSel!;
    final tr = _trabajoSel!;
    return Column(children: [
      // Breadcrumb
      Container(color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _trabajoSel = null),
            child: const Icon(Icons.arrow_back_ios, size: 14, color: AppColors.azul)),
          const SizedBox(width: 6),
          Text('${t.emoji} ${t.nombre}',
            style: TextStyle(fontSize: 12, color: t.color)),
          const Text(' › ', style: TextStyle(color: AppColors.textoSecundario)),
          Text('${tr.emoji} ${tr.nombre}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.azul)),
        ])),

      Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [

        // ── Parámetros ──
        ...tr.parametros.map((p) => _widgetParametro(p, t.color)),

        const SizedBox(height: 16),

        // ── Botón calcular ──
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _calcular,
            icon: const Icon(Icons.calculate_outlined, color: Colors.white),
            label: const Text('Calcular costo estimado',
              style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.color,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))))),

        // ── Resultado ──
        if (_resultado != null) ...[
          const SizedBox(height: 20),
          _widgetResultado(_resultado!, t),
        ],

        const SizedBox(height: 40),
      ])),
    ]);
  }

  Widget _widgetParametro(ParametroCosto p, Color colorTaller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.label, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textoPrincipal)),
        const SizedBox(height: 8),

        if (p.tipo == TipoParametro.selector) ...[
          Wrap(spacing: 6, runSpacing: 6,
            children: (p.opciones ?? []).asMap().entries.map((e) {
              final sel = (_valores[p.id] ?? 0) == e.key;
              return GestureDetector(
                onTap: () => setState(() => _valores[p.id] = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? colorTaller : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? colorTaller : AppColors.grisBorde)),
                  child: Text(e.value, style: TextStyle(
                    fontSize: 11,
                    color: sel ? Colors.white : AppColors.textoSecundario,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal))));
            }).toList()),
        ],

        if (p.tipo == TipoParametro.numero) ...[
          Row(children: [
            IconButton(
              onPressed: () => setState(() {
                final v = (_valores[p.id] as double? ?? p.valorDefault ?? 1);
                if (v > (p.min ?? 1)) _valores[p.id] = v - 1;
              }),
              icon: const Icon(Icons.remove_circle_outline),
              color: colorTaller, iconSize: 22),
            Expanded(child: TextFormField(
              initialValue: (_valores[p.id] ?? p.valorDefault ?? 1).toString(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                suffixText: p.unidad,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              onChanged: (v) => _valores[p.id] = double.tryParse(v) ?? p.valorDefault ?? 1,
            )),
            IconButton(
              onPressed: () => setState(() {
                final v = (_valores[p.id] as double? ?? p.valorDefault ?? 1);
                if (p.max == null || v < p.max!) _valores[p.id] = v + 1;
              }),
              icon: const Icon(Icons.add_circle_outline),
              color: colorTaller, iconSize: 22),
          ]),
        ],

        if (p.tipo == TipoParametro.toggle) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_valores[p.id] == true ? 'Sí' : 'No',
              style: TextStyle(fontSize: 12,
                color: _valores[p.id] == true ? colorTaller : AppColors.textoSecundario)),
            Switch(
              value: _valores[p.id] == true,
              onChanged: (v) => setState(() => _valores[p.id] = v),
              activeColor: colorTaller),
          ]),
        ],
      ]));
  }

  Widget _widgetResultado(ResultadoCosto r, TipoTaller t) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.color.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: t.color.withOpacity(0.08),
          blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(children: [
        // Header resultado
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            const Icon(Icons.receipt_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('COSTO ESTIMADO',
              style: TextStyle(fontSize: 12, color: Colors.white,
                fontWeight: FontWeight.w700, letterSpacing: 1))),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt.format(r.total),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  color: Colors.white)),
              Text('⏱️ ~${r.horasEstimadas.toStringAsFixed(1)} hrs',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
          ])),

        // Desglose
        Padding(padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (r.costoMaterial > 0) _lineaDesglose('📦 Material', r.costoMaterial),
            if (r.costoMaquina > 0) _lineaDesglose('⚙️ Tiempo máquina', r.costoMaquina),
            if (r.costoManoObra > 0) _lineaDesglose('👷 Mano de obra', r.costoManoObra),
            if (r.costoGas > 0) _lineaDesglose('💨 Gas / insumos', r.costoGas),
            const Divider(height: 20),
            _lineaDesglose('Subtotal', r.subtotal, bold: true),
            _lineaDesglose('Margen ${_margenPct.toInt()}%', r.margen,
              color: AppColors.verde),
            const Divider(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('PRECIO AL CLIENTE',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  color: AppColors.azul)),
              Text(_fmt.format(r.total),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: t.color)),
            ]),
          ])),

        // Aviso
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.ambarClaro,
              borderRadius: BorderRadius.circular(8)),
            child: const Text(
              '⚠️ Este es un estimado referencial. El precio final puede variar según diseño específico, acabados y condiciones del material.',
              style: TextStyle(fontSize: 10, color: AppColors.ambar)))),

        // Botón agregar a cotización
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _agregarACotizacion(r, t),
              icon: const Icon(Icons.description_outlined, color: Colors.white),
              label: const Text('Agregar a cotización',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azul,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)))))),
      ]));
  }

  Widget _lineaDesglose(String label, double monto,
      {bool bold = false, Color? color}) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: color ?? AppColors.textoPrincipal)),
        Text(_fmt.format(monto), style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: color ?? AppColors.azul)),
      ]));
  }

  // ── CÁLCULO DE COSTOS ────────────────────────────────
  void _calcular() {
    final tr = _trabajoSel!;
    final taller = _tallerSel!;
    double factorTotal = 1.0;
    double area = 1.0;
    double cantidad = 1.0;
    double volumen = 1.0;

    // Extraer valores clave
    for (final p in tr.parametros) {
      final val = _valores[p.id];
      if (p.tipo == TipoParametro.selector && p.factores != null) {
        final idx = (val as int? ?? 0).clamp(0, p.factores!.length - 1);
        factorTotal *= p.factores![idx];
      } else if (p.tipo == TipoParametro.toggle && p.factores != null) {
        factorTotal *= (val == true) ? p.factores![1] : p.factores![0];
      } else if (p.tipo == TipoParametro.numero) {
        if (p.id == 'ancho') area *= (val as double? ?? 30) / 100;
        if (p.id == 'alto')  area *= (val as double? ?? 30) / 100;
        if (p.id == 'cantidad') cantidad = (val as double? ?? 1);
        if (p.id == 'volumen') volumen = (val as double? ?? 50);
        if (p.id == 'tableros') area = (val as double? ?? 1) * 2.44 * 1.22;
      }
    }

    // Tiempos base por tipo de taller (horas por m² o unidad)
    double horasBase = 0;
    double costoMaterial = 0;
    double costoGas = 0;

    switch (taller.id) {
      case 'cnc_router':
        horasBase = area * 1.5 * factorTotal;
        costoMaterial = area * _precioMaterialBase * (factorTotal * 0.4);
        break;
      case 'laser_co2':
        horasBase = area * 0.8 * factorTotal;
        costoMaterial = area * _precioMaterialBase * 0.5 * (factorTotal * 0.3);
        break;
      case 'laser_fibra':
        horasBase = area * 0.5 * factorTotal;
        costoMaterial = 0; // cliente pone la pieza
        break;
      case 'plasma_cnc':
        horasBase = area * 1.2 * factorTotal;
        costoGas = horasBase * 25; // gas de corte
        costoMaterial = area * 180 * (factorTotal * 0.2);
        break;
      case 'impresion_3d':
        horasBase = (volumen / 10) * factorTotal;
        costoMaterial = volumen * 0.08 * factorTotal * 15; // $/cm³
        break;
      case 'diseno':
        horasBase = 2.0 * factorTotal;
        costoMaterial = 0;
        break;
    }

    // Aplicar cantidad
    horasBase *= cantidad;
    costoMaterial *= cantidad;
    costoGas *= cantidad;

    // Economía de escala para cantidad > 5
    if (cantidad > 5) {
      final descEscala = 1 - ((cantidad - 5) * 0.02).clamp(0.0, 0.30);
      horasBase *= descEscala;
    }

    final costoMaquina = horasBase * _tarifaMaquina;
    final costoManoObra = horasBase * _tarifaManoObra * 0.5;
    final subtotal = costoMaterial + costoMaquina + costoManoObra + costoGas;
    final margen = subtotal * (_margenPct / 100);
    final total = subtotal + margen;

    // Descripción para cotización
    final tr2 = _trabajoSel!;
    final desc = '${taller.emoji} ${taller.nombre} — ${tr2.nombre}';

    setState(() {
      _resultado = ResultadoCosto(
        costoMaterial: costoMaterial,
        costoMaquina: costoMaquina,
        costoManoObra: costoManoObra,
        costoGas: costoGas,
        subtotal: subtotal,
        margen: margen,
        total: total,
        horasEstimadas: horasBase,
        descripcionTrabajo: desc,
      );
    });
  }

  // ── AGREGAR A COTIZACIÓN ─────────────────────────────
  void _agregarACotizacion(ResultadoCosto r, TipoTaller t) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CotizarScreen(
        itemInicial: ItemSimulador(
          nombre: r.descripcionTrabajo,
          precioUnitario: r.total,
          notas: 'Estimado: ${_fmt.format(r.costoMaterial)} mat + '
            '${_fmt.format(r.costoMaquina)} máquina + '
            '${_fmt.format(r.costoManoObra)} M.O. | '
            '${r.horasEstimadas.toStringAsFixed(1)} hrs estimadas',
        ))));
  }

  // ── EDITAR TARIFAS ───────────────────────────────────
  void _editarTarifas() {
    final maqCtrl = TextEditingController(text: _tarifaMaquina.toString());
    final moCtrl  = TextEditingController(text: _tarifaManoObra.toString());
    final disCtrl = TextEditingController(text: _tarifaDiseno.toString());
    final marCtrl = TextEditingController(text: _margenPct.toString());
    final matCtrl = TextEditingController(text: _precioMaterialBase.toString());

    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16, right: 16, top: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('⚙️ Configurar tarifas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Ajusta según los costos reales de tu taller',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 16),
          _campoTarifa(maqCtrl, '💰 Tarifa maquina (\$/hora)', '150'),
          _campoTarifa(moCtrl,  '👷 Mano de obra (\$/hora)', '80'),
          _campoTarifa(disCtrl, '✏️ Tarifa diseno (\$/hora)', '200'),
          _campoTarifa(matCtrl, '📦 Material base (\$/m2)', '350'),
          _campoTarifa(marCtrl, '📈 Margen de ganancia (%)', '30'),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _tarifaMaquina     = double.tryParse(maqCtrl.text) ?? _tarifaMaquina;
                  _tarifaManoObra    = double.tryParse(moCtrl.text)  ?? _tarifaManoObra;
                  _tarifaDiseno      = double.tryParse(disCtrl.text) ?? _tarifaDiseno;
                  _precioMaterialBase= double.tryParse(matCtrl.text) ?? _precioMaterialBase;
                  _margenPct         = double.tryParse(marCtrl.text) ?? _margenPct;
                });
                Navigator.pop(context);
                if (_resultado != null) _calcular(); // recalcular
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azul,
                padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('Guardar tarifas',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        ])));
  }

  Widget _campoTarifa(TextEditingController ctrl, String label, String hint) =>
    Padding(padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true)));
}

// ── Clase para pasar item del simulador a CotizarScreen ──
class ItemSimulador {
  final String nombre;
  final double precioUnitario;
  final String? notas;
  const ItemSimulador({
    required this.nombre, required this.precioUnitario, this.notas});
}
