import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/supabase_service.dart';
import '../i18n/tr.dart';

class CuponesScreen extends StatefulWidget {
  const CuponesScreen({super.key});
  @override
  State<CuponesScreen> createState() => _CuponesScreenState();
}

class _CuponesScreenState extends State<CuponesScreen> {
  List<Map<String, dynamic>> _cupones = [];
  bool _cargando = true;
  final _fmt = NumberFormat('#,##0.00', 'es_MX');
  final _fmtFecha = DateFormat(enIngles ? 'MM/dd/yyyy' : 'dd/MM/yyyy');

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await SupabaseService.getCupones();
      if (mounted) setState(() { _cupones = res; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  Future<void> _editarCupon([Map<String, dynamic>? cupon]) async {
    final result = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => _FormCupon(cupon: cupon)));
    if (result == true) await _cargar();
  }

  Future<void> _eliminarCupon(Map<String, dynamic> cupon) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Eliminar cupón')),
        content: Text(trf('¿Eliminar el cupón "{0}"?', [(cupon['codigo'])])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: Text(tr('Eliminar'), style: TextStyle(color: Colors.white))),
        ]));
    if (ok == true) {
      await SupabaseService.eliminarCupon(cupon['id'] as String);
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(tr('Cupones de descuento'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.azul),
            onPressed: () => _editarCupon()),
        ]),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _cupones.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.discount_outlined, size: 48, color: AppColors.grisBorde),
              const SizedBox(height: 12),
              Text(tr('Sin cupones aún'), style: TextStyle(fontSize: 14, color: AppColors.textoSecundario)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _editarCupon(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(tr('Crear primer cupón'), style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _cupones.length,
              itemBuilder: (_, i) {
                final c = _cupones[i];
                final activo = c['activo'] as bool? ?? true;
                final tipo = c['tipo'] as String? ?? 'porcentaje';
                final valor = (c['valor'] as num?)?.toDouble() ?? 0;
                final usos = c['usos_actuales'] as int? ?? 0;
                final maxUsos = c['maximo_usos'] as int?;
                final fechaFin = c['fecha_fin'] != null
                  ? DateTime.tryParse(c['fecha_fin'] as String)
                  : null;
                final vencido = fechaFin != null && fechaFin.isBefore(DateTime.now());

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !activo || vencido ? AppColors.grisBorde : AppColors.azul.withOpacity(0.2),
                      width: 0.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                  child: Column(children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: (!activo || vencido) ? AppColors.gris : AppColors.azulClaro,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (!activo || vencido) ? AppColors.textoSecundario : AppColors.azul,
                            borderRadius: BorderRadius.circular(8)),
                          child: Text(tr(c['codigo'] as String? ?? ''),
                            style: const TextStyle(color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w900, letterSpacing: 1))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            tr(tipo == 'porcentaje'
                              ? trf('{0}% de descuento', [(valor.toStringAsFixed(0))])
                              : trf('\${0} de descuento', [(_fmt.format(valor))])),
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: (!activo || vencido) ? AppColors.textoSecundario : AppColors.azul)),
                          if (c['descripcion'] != null)
                            Text(tr(c['descripcion'] as String),
                              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                        ])),
                        // Estado badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: vencido ? AppColors.rojo.withOpacity(0.1)
                              : !activo ? AppColors.grisBorde
                              : AppColors.verde.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            tr(vencido ? tr('Vencido') : !activo ? tr('Inactivo') : tr('Activo')),
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: vencido ? AppColors.rojo
                                : !activo ? AppColors.textoSecundario
                                : AppColors.verde))),
                      ])),
                    // Detalles
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _detalle(tr('Usos'), maxUsos != null ? '$usos / $maxUsos' : '$usos / ∞'),
                          if (c['minimo_compra'] != null && (c['minimo_compra'] as num) > 0)
                            _detalle(tr('Mínimo'), '\$${_fmt.format(c['minimo_compra'])}'),
                          if (fechaFin != null)
                            _detalle(tr('Vence'), _fmtFecha.format(fechaFin)),
                        ])),
                        // Acciones
                        Row(children: [
                          // Copiar código
                          IconButton(
                            icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.azul),
                            tooltip: tr('Copiar código'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: c['codigo'] as String));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(trf('Código "{0}" copiado', [(c['codigo'])]))));
                            }),
                          // Toggle activo
                          IconButton(
                            icon: Icon(
                              activo ? Icons.toggle_on : Icons.toggle_off,
                              size: 28,
                              color: activo ? AppColors.verde : AppColors.grisBorde),
                            onPressed: () async {
                              await SupabaseService.actualizarCupon(
                                c['id'] as String, {'activo': !activo});
                              await _cargar();
                            }),
                          // Editar
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.azul),
                            onPressed: () => _editarCupon(c)),
                          // Eliminar
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rojo),
                            onPressed: () => _eliminarCupon(c)),
                        ]),
                      ])),
                  ]));
              }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editarCupon(),
        backgroundColor: AppColors.azul,
        child: const Icon(Icons.add, color: Colors.white)));
  }

  Widget _detalle(String label, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Text('${tr(label)}: ', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      Text(tr(valor), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textoPrincipal)),
    ]));
}

// ══════════════════════════════════════════════════
// FORMULARIO DE CUPÓN
// ══════════════════════════════════════════════════
class _FormCupon extends StatefulWidget {
  final Map<String, dynamic>? cupon;
  const _FormCupon({this.cupon});
  @override
  State<_FormCupon> createState() => _FormCuponState();
}

class _FormCuponState extends State<_FormCupon> {
  final _codigoCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _valorCtrl       = TextEditingController();
  final _minimoCtrl      = TextEditingController();
  final _maxUsosCtrl     = TextEditingController();
  String _tipo = 'porcentaje';
  DateTime? _fechaFin;
  bool _guardando = false;
  final _fmt = DateFormat(enIngles ? 'MM/dd/yyyy' : 'dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final c = widget.cupon;
    if (c != null) {
      _codigoCtrl.text      = c['codigo'] ?? '';
      _descripcionCtrl.text = c['descripcion'] ?? '';
      _valorCtrl.text       = c['valor']?.toString() ?? '';
      _minimoCtrl.text      = c['minimo_compra']?.toString() ?? '';
      _maxUsosCtrl.text     = c['maximo_usos']?.toString() ?? '';
      _tipo                 = c['tipo'] ?? 'porcentaje';
      if (c['fecha_fin'] != null) {
        _fechaFin = DateTime.tryParse(c['fecha_fin'] as String);
      }
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose(); _descripcionCtrl.dispose();
    _valorCtrl.dispose(); _minimoCtrl.dispose(); _maxUsosCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_codigoCtrl.text.trim().isEmpty || _valorCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Código y valor son obligatorios'))));
      return;
    }
    setState(() => _guardando = true);
    try {
      final datos = {
        'codigo'        : _codigoCtrl.text.trim().toUpperCase(),
        'descripcion'   : _descripcionCtrl.text.trim(),
        'tipo'          : _tipo,
        'valor'         : double.tryParse(_valorCtrl.text.trim()) ?? 0,
        'minimo_compra' : double.tryParse(_minimoCtrl.text.trim()) ?? 0,
        'maximo_usos'   : _maxUsosCtrl.text.trim().isEmpty
          ? null : int.tryParse(_maxUsosCtrl.text.trim()),
        'fecha_fin'     : _fechaFin?.toIso8601String().split('T')[0],
        'activo'        : true,
      };
      if (widget.cupon != null) {
        await SupabaseService.actualizarCupon(widget.cupon!['id'] as String, datos);
      } else {
        await SupabaseService.crearCupon(datos);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(tr(widget.cupon == null ? tr('Nuevo cupón') : tr('Editar cupón')),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(tr(_guardando ? tr('Guardando...') : tr('Guardar')),
              style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700))),
        ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Código
        TextField(
          controller: _codigoCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: tr('Código del cupón *'),
            hintText: tr('Ej: HETNA10'),
            prefixIcon: const Icon(Icons.discount_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            helperText: tr('El cliente escribe este código al cotizar')),
          style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        // Descripción
        TextField(
          controller: _descripcionCtrl,
          decoration: InputDecoration(
            labelText: tr('Descripción (opcional)'),
            hintText: tr('Ej: 10% de descuento por temporada'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          textCapitalization: TextCapitalization.sentences),
        const SizedBox(height: 16),

        // Tipo de descuento
        Text(tr('Tipo de descuento'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _tipo = 'porcentaje'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _tipo == 'porcentaje' ? AppColors.azulClaro : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _tipo == 'porcentaje' ? AppColors.azul : AppColors.grisBorde,
                  width: _tipo == 'porcentaje' ? 2 : 0.5)),
              child: Column(children: [
                Icon(Icons.percent, size: 28,
                  color: _tipo == 'porcentaje' ? AppColors.azul : AppColors.textoSecundario),
                const SizedBox(height: 6),
                Text(tr('Porcentaje'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _tipo == 'porcentaje' ? AppColors.azul : AppColors.textoSecundario)),
                Text(tr('Ej: 10%'),
                  style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              ])))),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _tipo = 'monto_fijo'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _tipo == 'monto_fijo' ? AppColors.azulClaro : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _tipo == 'monto_fijo' ? AppColors.azul : AppColors.grisBorde,
                  width: _tipo == 'monto_fijo' ? 2 : 0.5)),
              child: Column(children: [
                Icon(Icons.attach_money, size: 28,
                  color: _tipo == 'monto_fijo' ? AppColors.azul : AppColors.textoSecundario),
                const SizedBox(height: 6),
                Text(tr('Monto fijo'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _tipo == 'monto_fijo' ? AppColors.azul : AppColors.textoSecundario)),
                Text(tr('Ej: \$100'),
                  style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              ])))),
        ]),
        const SizedBox(height: 14),

        // Valor
        TextField(
          controller: _valorCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _tipo == 'porcentaje' ? tr('Porcentaje de descuento *') : tr('Monto de descuento *'),
            prefixText: _tipo == 'porcentaje' ? '' : '\$',
            suffixText: _tipo == 'porcentaje' ? '%' : '',
            hintText: _tipo == 'porcentaje' ? '10' : '100',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 12),

        // Mínimo de compra
        TextField(
          controller: _minimoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tr('Mínimo de compra'),
            prefixText: '\$',
            hintText: tr('0 = sin mínimo'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 12),

        // Máximo de usos
        TextField(
          controller: _maxUsosCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('Límite de usos'),
            hintText: tr('Vacío = ilimitado'),
            prefixIcon: const Icon(Icons.repeat_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 12),

        // Fecha de vencimiento
        GestureDetector(
          onTap: () async {
            final f = await showDatePicker(
              context: context,
              initialDate: _fechaFin ?? DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 730)));
            if (f != null) setState(() => _fechaFin = f);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gris,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.grisBorde)),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.azul),
              const SizedBox(width: 10),
              Expanded(child: Text(
                tr(_fechaFin != null
                  ? trf('Vence el {0}', [(_fmt.format(_fechaFin!))])
                  : tr('Sin fecha de vencimiento')),
                style: TextStyle(fontSize: 13,
                  color: _fechaFin != null ? AppColors.textoPrincipal : AppColors.textoSecundario))),
              if (_fechaFin != null)
                GestureDetector(
                  onTap: () => setState(() => _fechaFin = null),
                  child: const Icon(Icons.clear, size: 18, color: AppColors.rojo)),
              if (_fechaFin == null)
                const Icon(Icons.chevron_right, size: 16, color: AppColors.textoSecundario),
            ]))),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.azul,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(tr(_guardando ? tr('Guardando...') : tr('Guardar cupón')),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]));
  }
}
