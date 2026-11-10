// Checklist de arranque (Inicio): 5 pasos con palomita. Al completarlos el
// servidor regala 15 días más de prueba (función completar_arranque() de
// supabase/arranque.sql). Se esconde solo cuando ya se dio el bono, o si el
// SQL todavía no se ha corrido.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../i18n/tr.dart';
import '../screens/alta_guiada_screen.dart';
import '../simulador2/pieza_ejemplo.dart';
import '../simulador2/simulador2_screen.dart';

class ChecklistArranque extends StatefulWidget {
  const ChecklistArranque({super.key});
  @override
  State<ChecklistArranque> createState() => _ChecklistArranqueState();
}

class _ChecklistArranqueState extends State<ChecklistArranque> {
  Map<String, dynamic>? _d;
  bool _oculto = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    try {
      final r = await Supabase.instance.client.rpc('completar_arranque');
      if (!mounted || r is! Map || r['error'] != null) return;
      final d = Map<String, dynamic>.from(r);
      final nuevo = d['bonus_nuevo'] == true;
      setState(() { _d = d; _oculto = d['bonus_dado'] == true && !nuevo; });
      if (d['referido_nuevo'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('🎁 Completaste tu arranque con invitación: tú y quien te invitó ganaron 1 mes.')), backgroundColor: AppColors.verde, duration: const Duration(seconds: 6)));
      }
      if (nuevo && mounted) {
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: Text(tr('🎉 ¡Arranque completo!')),
          content: Text(tr('Completaste los 5 pasos. Te regalamos 15 días más de prueba.')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Gracias')))]));
      }
    } catch (_) {/* SQL sin correr: no se muestra */}
  }

  @override
  Widget build(BuildContext context) {
    if (_oculto || _d == null) return const SizedBox.shrink();
    final p = Map<String, dynamic>.from(_d!['pasos'] as Map);
    final pasos = [
      ['maquina', tr('Registra tu máquina'), tr('Con su costo por hora')],
      ['material', tr('Agrega un material'), tr('Con tu precio real')],
      ['cotizacion', tr('Haz tu primera cotización'), tr('Sube un DXF o STL al simulador')],
      ['cliente', tr('Guarda tu primer cliente'), tr('Al mandar la cotización')],
      ['orden', tr('Convierte una cotización en orden'), tr('Con su código QR para el taller')],
    ];
    final hechos = pasos.where((x) => p[x[0]] == true).length;
    final sinConfig = p['maquina'] != true && p['material'] != true;
    return Container(
      margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.verde.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🚀', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('Arranca tu taller'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
          Text('$hechos / 5', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.verde)),
        ]),
        const SizedBox(height: 4),
        Text(tr('Completa los 5 pasos y te regalamos 15 días más de prueba.'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: hechos / 5, minHeight: 6, backgroundColor: AppColors.grisBorde, color: AppColors.verde)),
        const SizedBox(height: 8),
        ...pasos.map((x) {
          final ok = p[x[0]] == true;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
            Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: ok ? AppColors.verde : AppColors.grisBorde),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x[1], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, decoration: ok ? TextDecoration.lineThrough : null, color: ok ? AppColors.textoSecundario : AppColors.textoPrincipal)),
              if (!ok) Text(x[2], style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            ])),
          ]));
        }),
        const SizedBox(height: 8),
        Row(children: [
          if (sinConfig) Expanded(child: ElevatedButton(
            onPressed: () async {
              final r = await Navigator.push<String>(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AltaGuiadaScreen()));
              _cargar();
              if (!mounted) return;
              if (r == 'ejemplo') abrirPiezaEjemplo(context);
              if (r == 'simular') Navigator.push(context, MaterialPageRoute(builder: (_) => const Simulador2Screen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(tr('Configurar en 2 minutos'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)))),
          if (sinConfig) const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: () => abrirPiezaEjemplo(context),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul, side: const BorderSide(color: AppColors.azul), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(tr('Ver pieza de ejemplo'), style: const TextStyle(fontSize: 13)))),
        ]),
      ]));
  }
}
