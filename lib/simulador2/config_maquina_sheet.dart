// lib/simulador2/config_maquina_sheet.dart
// HETNA CNC — Hojas de captura del Simulador 2.0:
//   configMaquinaSheet    tipo de máquina, mesa, preparación, perforación y la
//                         tabla de velocidades de esa máquina por material.
//   editarVelocidadSheet  una sola velocidad (máquina + material + espesor).
//   configTallerSheet     margen, mano de obra, gastos fijos y referencia de
//                         mercado, con enlace a la pantalla completa de costos.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../i18n/tr.dart';
import '../screens/config_costos_screen.dart';
import 'motor.dart';
import 'simulador2_data.dart';
import 'velocidades_hetna.dart';

final _fmt = NumberFormat(r'$#,##0', 'es_MX');

InputDecoration _dec(String label, [String? suf]) => InputDecoration(labelText: label, suffixText: suf, isDense: true, border: const OutlineInputBorder());
double? _p(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

/// Tipo, mesa, preparación y velocidades de una máquina.
Future<void> configMaquinaSheet(BuildContext context, {required Maquina2 maquina, required List<Material2> materiales}) async {
  String tipo = maquina.tipo;
  final prep = TextEditingController(text: maquina.preparacionMin.toStringAsFixed(0));
  final perf = TextEditingController(text: maquina.perforacionSeg.toStringAsFixed(0));
  final ml = TextEditingController(text: maquina.mesaLargo > 0 ? maquina.mesaLargo.toStringAsFixed(0) : '');
  final ma = TextEditingController(text: maquina.mesaAncho > 0 ? maquina.mesaAncho.toStringAsFixed(0) : '');
  final mz = TextEditingController(text: maquina.mesaAlto > 0 ? maquina.mesaAlto.toStringAsFixed(0) : '');
  final rem = TextEditingController(text: maquina.remocionCm3Min > 0 ? maquina.remocionCm3Min.toStringAsFixed(1) : '');
  final imp = TextEditingController(text: maquina.impresionCm3H > 0 ? maquina.impresionCm3H.toStringAsFixed(0) : '');
  final costo = TextEditingController(text: '');
  final dr = Simulador2Data.datosReceta(maquina);
  final potencia = TextEditingController(text: dr.potencia > 0 ? (dr.potencia % 1 == 0 ? dr.potencia.toInt().toString() : dr.potencia.toString()) : '');
  final rpmMax = TextEditingController(text: dr.rpmMax > 0 ? dr.rpmMax.toStringAsFixed(0) : '');
  final rpmMin = TextEditingController(text: dr.rpmMin > 0 ? dr.rpmMin.toStringAsFixed(0) : '');
  final avMax = TextEditingController(text: dr.avanceMax > 0 ? dr.avanceMax.toStringAsFixed(0) : '');
  bool guardado = false;

  await showModalBottomSheet<void>(context: context, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
      final tiposRel = materialesParaMaquina(tipo).map((t) => t.clave).toSet();
      final mats = materiales.where((m) => tiposRel.contains(m.tipo)).toList();
      return DraggableScrollableSheet(expand: false, initialChildSize: 0.9, maxChildSize: 0.95, builder: (ctx, sc) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(controller: sc, children: [
          Row(children: [
            Expanded(child: Text('${maquina.emoji} ${maquina.nombre}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            Text('${_fmt.format(maquina.costoHora)}/h', style: const TextStyle(fontSize: 13, color: AppColors.verde, fontWeight: FontWeight.w700)),
          ]),
          Text(tr('Lo que el simulador necesita saber de esta máquina. El costo por hora se calcula en Costos del taller.'), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: tipo, isExpanded: true, decoration: _dec(tr('Tipo de máquina')),
            items: nombresTipoMaquina.entries.map((e) => DropdownMenuItem(value: e.key, child: Text('${emojiTipoMaquina[e.key]} ${tr(e.value)}', style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setM(() => tipo = v ?? tipo)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: ml, keyboardType: TextInputType.number, decoration: _dec(tr('Mesa: largo'), 'mm'))), const SizedBox(width: 6),
            Expanded(child: TextField(controller: ma, keyboardType: TextInputType.number, decoration: _dec(tr('Mesa: ancho'), 'mm'))), const SizedBox(width: 6),
            Expanded(child: TextField(controller: mz, keyboardType: TextInputType.number, decoration: _dec(tr('Alto Z'), 'mm'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: prep, keyboardType: TextInputType.number, decoration: _dec(tr('Preparación por pedido'), 'min'))), const SizedBox(width: 6),
            Expanded(child: TextField(controller: perf, keyboardType: TextInputType.number, decoration: _dec(tr('Cada perforación'), 's'))),
          ]),
          const SizedBox(height: 4),
          Text(tr('Preparación: montar el material, poner el cero, cambiar fresa. Se cobra una vez por pedido.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
          if (tipo == 'router' || tipo == 'router_3d' || tipo == 'torno') ...[
            const SizedBox(height: 8),
            TextField(controller: rem, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec(tr('Remoción 3D (si no hay dato por material)'), 'cm³/min')),
          ],
          if (tipo == 'impresora_3d') ...[
            const SizedBox(height: 8),
            TextField(controller: imp, keyboardType: TextInputType.number, decoration: _dec(tr('Velocidad de impresión (si no hay dato por material)'), 'cm³/h')),
          ],
          const SizedBox(height: 10),
          Text(tr('Para la receta técnica'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (tipo == 'router' || tipo == 'router_3d' || tipo == 'torno') ...[
            Row(children: [
              Expanded(child: TextField(controller: potencia, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec(tr('Spindle'), 'kW'))), const SizedBox(width: 6),
              Expanded(child: TextField(controller: rpmMax, keyboardType: TextInputType.number, decoration: _dec(tr('RPM máx.')))), const SizedBox(width: 6),
              Expanded(child: TextField(controller: rpmMin, keyboardType: TextInputType.number, decoration: _dec(tr('RPM mín.')))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: avMax, keyboardType: TextInputType.number, decoration: _dec(tr('Avance máximo de corte'), 'mm/min')),
            const SizedBox(height: 4),
            Text(tr('Típico: spindle 2.2 kW, 24,000 RPM máx., 6,000 RPM mín., avance 6,000 mm/min.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
          ],
          if (tipo == 'laser_co2') TextField(controller: potencia, keyboardType: TextInputType.number, decoration: _dec(tr('Potencia del tubo'), 'W')),
          if (tipo == 'plasma') TextField(controller: potencia, keyboardType: TextInputType.number, decoration: _dec(tr('Amperaje de la fuente'), 'A')),
          if (tipo == 'laser_fibra') TextField(controller: potencia, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec(tr('Potencia de la fuente'), 'kW')),
          if (tipo == 'impresora_3d') Text(tr('La receta usa boquilla 0.4, capa 0.2 y 60 mm/s; ajústala desde el simulador.'), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 8),
          TextField(controller: costo, keyboardType: TextInputType.number, decoration: _dec(tr('Costo por hora a mano (vacío = calculado)'), '\$/h')),
          const SizedBox(height: 14),
          Text(tr('Velocidades por material'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          Text(tr('Toca una fila para corregirla. "Sugerido" = valor de HETNA que todavía no confirmas.'), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 6),
          if (mats.isEmpty) Text(tr('No hay materiales de este tipo en tu inventario.'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          for (final m in mats) _filaVelocidad(ctx, maquina, tipo, m, () => setM(() {})),
          const SizedBox(height: 14),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cerrar'))),
            const Spacer(),
            ElevatedButton(onPressed: () async {
              try {
                await Simulador2Data.guardarMaquina(maquina.id, {
                  'tipo': tipo,
                  'mesa_largo_mm': _p(ml), 'mesa_ancho_mm': _p(ma), 'mesa_alto_mm': _p(mz),
                  'preparacion_min': _p(prep) ?? 15, 'perforacion_seg': _p(perf) ?? 2,
                  'remocion_cm3_min': _p(rem), 'impresion_cm3_h': _p(imp),
                  'costo_hora_manual': _p(costo),
                  'potencia': _p(potencia), 'rpm_max': _p(rpmMax)?.round(), 'rpm_min': _p(rpmMin)?.round(), 'avance_max': _p(avMax),
                });
                guardado = true;
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(trf('No se guardó: {0}. ¿Ya corriste simulador2.sql?', [e])), backgroundColor: AppColors.rojo));
              }
            }, child: Text(tr('Guardar máquina'))),
          ]),
        ])));
    }));
  if (guardado && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Máquina guardada.')), backgroundColor: AppColors.verde));
  }
}

Widget _filaVelocidad(BuildContext ctx, Maquina2 maq, String tipo, Material2 m, VoidCallback refrescar) {
  final maqTipo = Maquina2(id: maq.id, nombre: maq.nombre, tipo: tipo, costoHora: maq.costoHora, remocionCm3Min: maq.remocionCm3Min, impresionCm3H: maq.impresionCm3H);
  final v = Simulador2Data.velocidad(maqTipo, m);
  final partes = <String>[];
  if (v.corteMMin > 0) partes.add('${tr('corte')} ${v.corteMMin.toStringAsFixed(2)} m/min');
  if (v.grabadoCm2Min > 0) partes.add('${tr('grabado')} ${v.grabadoCm2Min.toStringAsFixed(0)} cm²/min');
  if (v.remocionCm3Min > 0) partes.add('3D ${v.remocionCm3Min.toStringAsFixed(1)} cm³/min');
  if (v.impresionCm3H > 0) partes.add('${v.impresionCm3H.toStringAsFixed(0)} cm³/h');
  final color = v.origen == 'ninguno' ? AppColors.rojo : v.sugerido ? AppColors.naranja : AppColors.verde;
  return InkWell(
    onTap: () async {
      final ok = await editarVelocidadSheet(ctx, maquina: maqTipo, material: m, servicio: serviciosDeMaquina(tipo).first, actual: v);
      if (ok == true) { await Simulador2Data.cargarVelocidades(); refrescar(); }
    },
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      if (m.esRetazo) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.content_cut, size: 12, color: AppColors.ambar)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.nombre, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        Text(partes.isEmpty ? tr('Sin velocidad: toca para capturarla') : partes.join(' · '), style: TextStyle(fontSize: 11, color: color)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Text(v.origen == 'ninguno' ? tr('falta') : v.sugerido ? tr('sugerido') : v.origen == 'tiempo_real' ? tr('aprendido') : tr('tuyo'), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700))),
      const Icon(Icons.chevron_right, size: 18, color: AppColors.textoSecundario),
    ])));
}

/// Una velocidad: máquina + material + espesor. Devuelve true si se guardó.
Future<bool?> editarVelocidadSheet(BuildContext context, {required Maquina2 maquina, required Material2 material,
    required Servicio2 servicio, required Velocidad2 actual}) async {
  final corte = TextEditingController(text: actual.corteMMin > 0 ? actual.corteMMin.toStringAsFixed(2) : '');
  final grab = TextEditingController(text: actual.grabadoCm2Min > 0 ? actual.grabadoCm2Min.toStringAsFixed(0) : '');
  final rem = TextEditingController(text: actual.remocionCm3Min > 0 ? actual.remocionCm3Min.toStringAsFixed(1) : '');
  final imp = TextEditingController(text: actual.impresionCm3H > 0 ? actual.impresionCm3H.toStringAsFixed(0) : '');
  final tipoMaq = maquina.tipo == 'router_3d' ? 'router' : maquina.tipo;
  final sugCorte = velocidadCorteSugerida(tipoMaq, material.tipo, material.espesorMm);
  final sugGrab = velocidadGrabadoSugerida(tipoMaq, material.tipo);
  final sugRem = remocionSugerida(maquina.tipo, material.tipo);
  final sugImp = maquina.tipo == 'impresora_3d' ? impresionSugerida(material.tipo) : 0.0;
  final es3D = maquina.tipo == 'router_3d' || maquina.tipo == 'torno' || maquina.tipo == 'router';
  final esImp = maquina.tipo == 'impresora_3d';
  final esCorte = maquina.tipo != 'impresora_3d' && maquina.tipo != 'torno';

  return showModalBottomSheet<bool>(context: context, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${maquina.emoji} ${maquina.nombre} · ${material.nombre}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        Text(trf('{0}{1}. Velocidad EFECTIVA ya con las pasadas que lleva ese espesor, no el avance del G-code.',
          [tipoMaterialPorClave(material.tipo)?.nombre ?? material.tipo, material.espesorMm > 0 ? ' ${material.espesorMm} mm' : '']),
          style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
        const SizedBox(height: 10),
        if (esCorte) _campoVel(corte, tr('Corte'), 'm/min', sugCorte, 2),
        if (esCorte) const SizedBox(height: 8),
        if (esCorte) _campoVel(grab, tr('Grabado (opcional)'), 'cm²/min', sugGrab, 0),
        if (es3D) const SizedBox(height: 8),
        if (es3D) _campoVel(rem, tr('Relieve 3D: remoción'), 'cm³/min', sugRem, 1),
        if (esImp) _campoVel(imp, tr('Impresión'), 'cm³/h', sugImp, 0),
        const SizedBox(height: 6),
        Text(tr('¿Cómo saberla? Corta una pieza de prueba, mide los metros de corte y el tiempo: metros ÷ minutos. O usa "Ajustar" en el simulador con el tiempo real y se guarda sola.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
        const SizedBox(height: 12),
        Row(children: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
          const Spacer(),
          ElevatedButton(onPressed: () async {
            final vel = Velocidad2(corteMMin: _p(corte) ?? 0, grabadoCm2Min: _p(grab) ?? 0, remocionCm3Min: _p(rem) ?? 0, impresionCm3H: _p(imp) ?? 0, sugerido: false, origen: 'taller');
            if (vel.corteMMin <= 0 && vel.grabadoCm2Min <= 0 && vel.remocionCm3Min <= 0 && vel.impresionCm3H <= 0) { Navigator.pop(ctx, false); return; }
            try {
              await Simulador2Data.guardarVelocidad(maq: maquina, mat: material, vel: vel);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(trf('No se guardó: {0}. ¿Ya corriste simulador2.sql?', [e])), backgroundColor: AppColors.rojo));
            }
          }, child: Text(tr('Guardar'))),
        ]),
      ])));
}

Widget _campoVel(TextEditingController c, String label, String unidad, double sugerido, int dec) => Row(children: [
  Expanded(child: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec(label, unidad))),
  if (sugerido > 0) TextButton(onPressed: () => c.text = sugerido.toStringAsFixed(dec), child: Text('${tr('HETNA')}: ${sugerido.toStringAsFixed(dec)}', style: const TextStyle(fontSize: 11))),
]);

/// Lo mínimo del taller para que el precio salga: margen, operador, gastos
/// fijos, manejo y referencia de mercado. Lo demás vive en Costos del taller.
Future<void> configTallerSheet(BuildContext context, {required Taller2 taller}) async {
  final margen = TextEditingController(text: taller.margenPct.toStringAsFixed(0));
  final margenMin = TextEditingController(text: taller.margenMinPct.toStringAsFixed(0));
  final markup = TextEditingController(text: taller.markupMaterialPct.toStringAsFixed(0));
  final manejo = TextEditingController(text: taller.manejoMinPieza.toStringAsFixed(0));
  final mM2 = TextEditingController(text: taller.mercadoM2 > 0 ? taller.mercadoM2.toStringAsFixed(0) : '');
  final mH = TextEditingController(text: taller.mercadoHora > 0 ? taller.mercadoHora.toStringAsFixed(0) : '');
  final mCm3 = TextEditingController(text: taller.mercadoCm3 > 0 ? taller.mercadoCm3.toStringAsFixed(2) : '');
  await showModalBottomSheet<void>(context: context, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Costos del taller'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _dato(tr('Operador'), '${_fmt.format(taller.costoHoraOperador)}/h', taller.costoHoraOperador > 0 ? AppColors.verde : AppColors.rojo),
        _dato(tr('Gastos fijos'), '${_fmt.format(taller.gastosFijosHora)}/h', taller.gastosFijosHora > 0 ? AppColors.verde : AppColors.naranja),
        Padding(padding: const EdgeInsets.only(top: 2, bottom: 8), child: Text(tr('Se calculan con la nómina, la renta, la luz y las horas que trabaja el taller.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario))),
        OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigCostosScreen())); },
          icon: const Icon(Icons.open_in_new, size: 16), label: Text(tr('Abrir Costos del taller (máquinas, nómina, gastos)'))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: margen, keyboardType: TextInputType.number, decoration: _dec(tr('Margen normal'), '%'))), const SizedBox(width: 6),
          Expanded(child: TextField(controller: margenMin, keyboardType: TextInputType.number, decoration: _dec(tr('Margen mínimo'), '%'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: markup, keyboardType: TextInputType.number, decoration: _dec(tr('Ganancia sobre material'), '%'))), const SizedBox(width: 6),
          Expanded(child: TextField(controller: manejo, keyboardType: TextInputType.number, decoration: _dec(tr('Manejo por pieza'), 'min'))),
        ]),
        const SizedBox(height: 12),
        Text(tr('Referencia de mercado (opcional)'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        Text(tr('Lo que cobran otros talleres de tu zona. Sólo se muestra como comparación; tú decides.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(controller: mM2, keyboardType: TextInputType.number, decoration: _dec(tr('Corte 2D'), '\$/m²'))), const SizedBox(width: 6),
          Expanded(child: TextField(controller: mH, keyboardType: TextInputType.number, decoration: _dec(tr('Máquina'), '\$/h'))), const SizedBox(width: 6),
          Expanded(child: TextField(controller: mCm3, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec(tr('Impresión 3D'), '\$/cm³'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          const Spacer(),
          ElevatedButton(onPressed: () async {
            try {
              await Simulador2Data.guardarTaller({
                'margen_recomendado': _p(margen) ?? 35, 'margen_minimo': _p(margenMin) ?? 20,
                'markup_material_pct': _p(markup) ?? 20, 'manejo_min_pieza': _p(manejo) ?? 1,
                'mercado_m2': _p(mM2), 'mercado_hora': _p(mH), 'mercado_cm3': _p(mCm3),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(trf('No se guardó: {0}. ¿Ya corriste simulador2.sql?', [e])), backgroundColor: AppColors.rojo));
            }
          }, child: Text(tr('Guardar'))),
        ]),
      ]))));
}

Widget _dato(String k, String v, Color c) => Row(children: [
  Text('$k: ', style: const TextStyle(fontSize: 12.5)),
  Text(v, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c)),
]);
