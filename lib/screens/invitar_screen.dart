// Invitar a un taller: mi código, mi liga y el mensaje listo para WhatsApp.
// Cuando el invitado completa su arranque, los dos ganan 1 mes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../i18n/tr.dart';
import '../services/auth_service.dart';
import '../services/referidos_service.dart';

class InvitarScreen extends StatefulWidget {
  const InvitarScreen({super.key});
  @override
  State<InvitarScreen> createState() => _InvitarScreenState();
}

class _InvitarScreenState extends State<InvitarScreen> {
  Map<String, dynamic>? _d;
  bool _cargando = true;
  final _codigoC = TextEditingController();
  bool _aplicando = false;
  String? _msgCodigo;
  bool _okCodigo = false;

  @override
  void initState() { super.initState(); _cargar(); }
  @override
  void dispose() { _codigoC.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    final d = await ReferidosService.miCodigo();
    if (mounted) setState(() { _d = d; _cargando = false; });
  }

  String get _liga => ReferidosService.liga(_d?['codigo'] as String?);
  String get _mensaje => trf(
    'Te recomiendo el Cotizador de HETNA: subes tu DXF o STL y te da tiempo de máquina, costo y precio en 2 minutos. Yo lo uso en {0}.\n\nEntra con mi liga y los dos ganamos 1 mes gratis:\n{1}',
    [AuthService.marcaTaller, _liga]);

  Future<void> _whatsapp() async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_mensaje)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copiar(String texto, String aviso) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso), backgroundColor: AppColors.verde));
  }

  Future<void> _aplicar() async {
    final c = _codigoC.text.trim();
    if (c.isEmpty) return;
    setState(() { _aplicando = true; _msgCodigo = null; });
    try {
      final r = await ReferidosService.aplicar(c);
      if (!mounted) return;
      setState(() { _okCodigo = r['ok'] == true; _msgCodigo = (r['mensaje'] ?? '').toString(); _aplicando = false; });
      if (_okCodigo) { await AuthService.refrescarPerfil(); _cargar(); }
    } catch (e) {
      if (mounted) setState(() { _okCodigo = false; _msgCodigo = '$e'; _aplicando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(tr('Invitar a un taller')), backgroundColor: AppColors.azul, foregroundColor: Colors.white),
      body: _cargando ? const Center(child: CircularProgressIndicator())
        : _d == null ? Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(tr('Las invitaciones todavía no están activas. Vuelve a intentar más tarde.'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSecundario))))
        : ListView(padding: const EdgeInsets.all(16), children: [
            Container(padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)]), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🎁', style: TextStyle(fontSize: 30)),
                const SizedBox(height: 6),
                Text(tr('Invita a un taller: 1 mes gratis para los dos'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(tr('Cuando tu invitado termine su arranque (máquina, material, cotización, cliente y orden), cada uno gana 1 mes.'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
              ])),
            const SizedBox(height: 14),
            _tarjeta(children: [
              Text(tr('Tu código'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: SelectableText((_d!['codigo'] ?? '').toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4, color: AppColors.azul))),
                IconButton(onPressed: () => _copiar((_d!['codigo'] ?? '').toString(), tr('Código copiado')), icon: const Icon(Icons.copy, color: AppColors.azul)),
              ]),
              const Divider(),
              Text(tr('Tu liga'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: SelectableText(_liga, style: const TextStyle(fontSize: 13))),
                IconButton(onPressed: () => _copiar(_liga, tr('Liga copiada')), icon: const Icon(Icons.copy, color: AppColors.azul)),
              ]),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
                onPressed: _whatsapp,
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                label: Text(tr('Invitar por WhatsApp'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsapp, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
              const SizedBox(height: 6),
              Center(child: TextButton(onPressed: () => _copiar(_mensaje, tr('Mensaje copiado')), child: Text(tr('Copiar el mensaje')))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _numero('${_d!['invitados'] ?? 0}', tr('Invitados'))),
              const SizedBox(width: 8),
              Expanded(child: _numero('${_d!['completaron'] ?? 0}', tr('Completaron'))),
              const SizedBox(width: 8),
              Expanded(child: _numero('${_d!['meses_a_favor'] ?? 0}', tr('Meses a favor'))),
            ]),
            if (((_d!['meses_a_favor'] as num?) ?? 0) > 0) Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(tr('Tus meses a favor se aplican en tu siguiente renovación. Si tienes duda, escríbenos desde hetnacnc.com.'),
                style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario))),
            if (_d!['puede_aplicar'] == true || _okCodigo) ...[
              const SizedBox(height: 18),
              _tarjeta(children: [
                Text(tr('¿Te invitó otro taller o un distribuidor?'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _codigoC, textCapitalization: TextCapitalization.characters, enabled: !_okCodigo,
                    decoration: InputDecoration(isDense: true, hintText: tr('Escribe su código'), border: const OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _aplicando || _okCodigo ? null : _aplicar,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
                    child: _aplicando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr('Aplicar'), style: const TextStyle(color: Colors.white))),
                ]),
                if (_msgCodigo != null) Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text(_msgCodigo!, style: TextStyle(fontSize: 12.5, color: _okCodigo ? AppColors.verde : AppColors.rojo))),
              ]),
            ],
          ]),
    );
  }

  Widget _tarjeta({required List<Widget> children}) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grisBorde)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));

  Widget _numero(String n, String etiqueta) => Container(padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde)),
    child: Column(children: [
      Text(n, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.azul)),
      Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
    ]));
}
