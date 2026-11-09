// lib/screens/descontar_material_sheet.dart
// HETNA CNC — Inventario conectado a pedidos (ver services/inventario_pedido_service.dart)
//
//   descontarMaterialSheet  al empezar el maquinado: qué material sale de la
//                           bodega (propuesto por la cotización o elegido a mano)
//   retazoSheet             al terminar: ¿sobró un retazo? se guarda con su medida
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/inventario_pedido_service.dart';
import '../i18n/tr.dart';

/// Devuelve true si se descontó algo, false si se saltó.
Future<bool> descontarMaterialSheet(BuildContext context, {required String pedidoId, required String folio}) async {
  if (await InventarioPedidoService.yaDescontado(pedidoId)) return false;
  List<MaterialPorDescontar> lista;
  List<Map<String, dynamic>> bodega;
  try {
    lista = await InventarioPedidoService.propuesta(pedidoId);
    bodega = await InventarioPedidoService.materiales();
  } catch (_) {
    return false; // sin SQL corrido o sin inventario: no estorba
  }
  if (bodega.isEmpty) return false;
  if (!context.mounted) return false;
  final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
      String? agregarId;
      return Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trf('Material para {0}', [folio]), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(tr('Se descuenta de la bodega y queda como costo real del pedido.'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          if (lista.isEmpty) Text(tr('La cotización no trae material del inventario. Elige abajo lo que se va a usar.'), style: const TextStyle(fontSize: 12.5, color: AppColors.ambar)),
          ...lista.map((m) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.nombre, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              Text(trf('En bodega: {0} {1}', [m.stock, m.unidad]), style: TextStyle(fontSize: 11, color: m.stock < m.cantidad ? AppColors.rojo : AppColors.textoSecundario)),
            ])),
            SizedBox(width: 90, child: TextFormField(initialValue: m.cantidad % 1 == 0 ? m.cantidad.toInt().toString() : m.cantidad.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center,
              decoration: InputDecoration(suffixText: m.unidad, isDense: true, border: const OutlineInputBorder()),
              onChanged: (v) => m.cantidad = double.tryParse(v.replaceAll(',', '.')) ?? 0)),
            IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.textoSecundario), onPressed: () => setM(() => lista.remove(m))),
          ]))),
          DropdownButtonFormField<String>(value: agregarId, isExpanded: true,
            decoration: InputDecoration(labelText: tr('Agregar otro material de la bodega'), isDense: true, border: const OutlineInputBorder()),
            items: bodega.where((b) => !lista.any((x) => x.materialId == b['id'])).map((b) => DropdownMenuItem(value: b['id'] as String,
              child: Text('${b['nombre']} (${b['stock_actual'] ?? 0} ${b['unidad'] ?? ''})', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (id) {
              final b = bodega.firstWhere((x) => x['id'] == id);
              setM(() => lista.add(MaterialPorDescontar(materialId: id!, nombre: (b['nombre'] ?? '').toString(), unidad: (b['unidad'] ?? 'pzas').toString(),
                costoUnitario: (b['costo_unitario'] as num?)?.toDouble() ?? 0, stock: (b['stock_actual'] as num?)?.toInt() ?? 0, cantidad: 1)));
            }),
          const SizedBox(height: 12),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Sin material / después'))),
            const Spacer(),
            ElevatedButton(onPressed: lista.isEmpty ? null : () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde),
              child: Text(tr('Descontar de la bodega'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          ]),
        ]));
    }));
  if (ok != true) return false;
  try {
    await InventarioPedidoService.descontar(pedidoId, folio, lista);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Material descontado de la bodega.')), backgroundColor: AppColors.verde));
    return true;
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('No se pudo descontar: {0}', [e])), backgroundColor: AppColors.rojo));
    return false;
  }
}

/// Al terminar el maquinado: ¿sobró un retazo útil? Se guarda en la bodega.
Future<void> retazoSheet(BuildContext context, {required String folio}) async {
  List<Map<String, dynamic>> bodega;
  try {
    bodega = (await InventarioPedidoService.materiales()).where((b) => b['es_retazo'] != true).toList();
  } catch (_) {
    return;
  }
  if (bodega.isEmpty || !context.mounted) return;
  String? padreId;
  final largo = TextEditingController(), ancho = TextEditingController(), hojaL = TextEditingController(), hojaA = TextEditingController();
  final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('¿Sobró un retazo?'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        Text(tr('Se guarda en la bodega con su medida para usarlo en el siguiente trabajo.'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: padreId, isExpanded: true,
          decoration: InputDecoration(labelText: tr('De qué material'), isDense: true, border: const OutlineInputBorder()),
          items: bodega.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text('${b['nombre']}', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setM(() {
            padreId = v;
            final b = bodega.firstWhere((x) => x['id'] == v);
            if (b['largo_mm'] != null) hojaL.text = '${b['largo_mm']}';
            if (b['ancho_mm'] != null) hojaA.text = '${b['ancho_mm']}';
          })),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: largo, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Largo del retazo'), suffixText: 'mm', isDense: true, border: const OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: ancho, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Ancho del retazo'), suffixText: 'mm', isDense: true, border: const OutlineInputBorder()))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: hojaL, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Hoja completa: largo'), suffixText: 'mm', isDense: true, border: const OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: hojaA, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Hoja completa: ancho'), suffixText: 'mm', isDense: true, border: const OutlineInputBorder()))),
        ]),
        Text(tr('La medida de la hoja sirve para calcular cuánto vale el retazo.'), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        const SizedBox(height: 12),
        Row(children: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('No sobró'))),
          const Spacer(),
          ElevatedButton(onPressed: () {
              if (padreId == null || (double.tryParse(largo.text) ?? 0) <= 0 || (double.tryParse(ancho.text) ?? 0) <= 0) return;
              Navigator.pop(ctx, true);
            }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
            child: Text(tr('Guardar retazo'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      ]))));
  if (ok != true) return;
  final b = bodega.firstWhere((x) => x['id'] == padreId);
  try {
    await InventarioPedidoService.guardarRetazo(materialPadreId: padreId!, nombrePadre: (b['nombre'] ?? '').toString(),
      costoPadre: (b['costo_unitario'] as num?)?.toDouble() ?? 0, largoMm: double.parse(largo.text), anchoMm: double.parse(ancho.text),
      espesorMm: (b['espesor_mm'] as num?)?.toDouble(), largoHojaMm: double.tryParse(hojaL.text), anchoHojaMm: double.tryParse(hojaA.text), folio: folio);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Retazo guardado en la bodega.')), backgroundColor: AppColors.verde));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('No se pudo guardar el retazo: {0}', [e])), backgroundColor: AppColors.rojo));
  }
}
