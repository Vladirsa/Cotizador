// lib/simulador2/receta_widget.dart
// HETNA CNC — Tarjeta "Receta técnica" del simulador y hoja para editarla.
//
// Muestra la broca/boquilla y los parámetros con los que se haría el trabajo
// (recetas.dart). El taller toca "Ajustar" y cambia RPM, avance, pasadas,
// potencia, amperaje… Se guarda como SU receta (sim2_recetas) y el simulador
// recalcula el tiempo con ella. "Calculadora" abre la Calculadora CNC completa.
import 'package:flutter/material.dart';
import '../main.dart';
import '../i18n/tr.dart';
import '../screens/calculadora_cnc_screen.dart';
import 'motor.dart';
import 'recetas.dart';
import 'simulador2_data.dart';

class RecetaCard extends StatefulWidget {
  final Receta receta;
  final Maquina2 maquina;
  final Material2 material;
  final String servicio;        // Servicio2.name
  final bool tallerLaEdito;
  final VoidCallback onCambio;  // recargar y recalcular
  const RecetaCard({super.key, required this.receta, required this.maquina, required this.material, required this.servicio,
    required this.tallerLaEdito, required this.onCambio});
  @override
  State<RecetaCard> createState() => _RecetaCardState();
}

class _RecetaCardState extends State<RecetaCard> {
  bool _abierta = true;

  @override
  Widget build(BuildContext context) {
    final r = widget.receta;
    final virtual = widget.maquina.id.startsWith('ref_');
    final color = widget.tallerLaEdito ? AppColors.verde : AppColors.naranja;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grisBorde)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(onTap: () => setState(() => _abierta = !_abierta), child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 8, 10), child: Row(children: [
          const Text('🔧', style: TextStyle(fontSize: 16)), const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Receta técnica'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            Text(r.titulo, style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(widget.tallerLaEdito ? tr('tu receta') : tr('sugerida HETNA'), style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700))),
          Icon(_abierta ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.textoSecundario),
        ]))),
        if (_abierta) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (r.faltan.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(
            '${tr('Para afinarla falta de tu máquina')}: ${r.faltan.join(', ')} (${tr('engrane de la máquina')})',
            style: const TextStyle(fontSize: 11, color: AppColors.naranja))),
          Wrap(spacing: 10, runSpacing: 6, children: [
            for (final p in r.parametros)
              if (p.nombre.startsWith('—')) SizedBox(width: double.infinity, child: Text(p.nombre, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.azul)))
              else _param(p),
          ]),
          const SizedBox(height: 8),
          for (final a in r.avisos.where((a) => a.isNotEmpty)) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• $a', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
          const SizedBox(height: 6),
          Row(children: [
            TextButton.icon(onPressed: virtual ? null : () => _ajustar(context), icon: const Icon(Icons.tune, size: 16), label: Text(tr('Ajustar y guardar'))),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculadoraCncScreen())), icon: const Icon(Icons.calculate_outlined, size: 16), label: Text(tr('Calculadora'))),
            if (widget.tallerLaEdito) TextButton(onPressed: () async {
              await Simulador2Data.borrarReceta(widget.maquina, widget.material, Simulador2Data.operacionDe(widget.maquina.tipo, widget.servicio));
              widget.onCambio();
            }, child: Text(tr('Volver a HETNA'), style: const TextStyle(fontSize: 12))),
          ]),
          if (virtual) Text(tr('Registra tu máquina para guardar tu receta.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
        ])),
      ]));
  }

  Widget _param(Parametro p) => ConstrainedBox(constraints: const BoxConstraints(minWidth: 120), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Text(tr(p.nombre), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
    Row(mainAxisSize: MainAxisSize.min, children: [
      Text(p.valor, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: p.editable ? AppColors.azul : AppColors.textoPrincipal)),
      if (p.unidad != null) Text(' ${p.unidad}', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
    ]),
    if (p.nota != null) Text(p.nota!, style: const TextStyle(fontSize: 9.5, color: AppColors.textoSecundario)),
  ]));

  Future<void> _ajustar(BuildContext context) async {
    final r = widget.receta;
    final ctrls = <String, TextEditingController>{};
    final etiquetas = <String, String>{};
    for (final p in r.parametros) {
      if (!p.editable || !r.ajustables.containsKey(p.clave)) continue;
      final v = r.ajustables[p.clave]!;
      ctrls[p.clave] = TextEditingController(text: v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2));
      etiquetas[p.clave] = '${p.nombre}${p.unidad != null ? ' (${p.unidad})' : ''}';
    }
    // Campos editables que no son numéricos (tipo de fresa) se quedan como texto en la nota
    final nota = TextEditingController();
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Ajustar receta'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(r.titulo, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          Text(tr('Pon los valores con los que de verdad corres este trabajo. El tiempo y el precio se recalculan con ellos, y quedan guardados para este material en esta máquina.'), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in ctrls.entries) SizedBox(width: 150, child: TextField(controller: e.value, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr(etiquetas[e.key]!), isDense: true, border: const OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: nota, decoration: InputDecoration(labelText: tr('Nota (fresa que usas, truco del material…)'), isDense: true, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
            const Spacer(),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Guardar mi receta'))),
          ]),
        ]))));
    if (ok != true) return;
    final ajustes = <String, double>{};
    ctrls.forEach((k, c) { final v = double.tryParse(c.text.trim().replaceAll(',', '.')); if (v != null && v > 0) ajustes[k] = v; });
    try {
      await Simulador2Data.guardarReceta(maq: widget.maquina, mat: widget.material,
        operacion: Simulador2Data.operacionDe(widget.maquina.tipo, widget.servicio), ajustes: ajustes, nota: nota.text.trim().isEmpty ? null : nota.text.trim());
      widget.onCambio();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Receta guardada. El simulador ya la usa.')), backgroundColor: AppColors.verde));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('No se guardó: {0}. ¿Ya corriste simulador2.sql?', [e])), backgroundColor: AppColors.rojo));
    }
  }
}
