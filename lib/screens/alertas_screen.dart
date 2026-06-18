// ============================================
// lib/screens/alertas_screen.dart
// Pantalla de alertas y seguimiento automático
// ============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  List<Alerta> _alertas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final alertas = await SupabaseService.getAlertasPendientes();
      setState(() => _alertas = alertas);
    } catch (e) {
      _mostrarError('Error al cargar alertas: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimientos pendientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _alertas.isEmpty
              ? _sinAlertas()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      ..._alertas.map((a) => _TarjetaAlerta(
                            alerta: a,
                            onEnviado: () => _marcarCompletada(a),
                          )),
                    ],
                  ),
                ),
    );
  }

  Widget _sinAlertas() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 64, color: Color(0xFF1d9e75)),
            const SizedBox(height: 12),
            const Text('¡Todo al día!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('No hay seguimientos pendientes por ahora.',
                style: TextStyle(color: AppColors.textoSecundario)),
          ],
        ),
      );

  Future<void> _marcarCompletada(Alerta alerta) async {
    await SupabaseService.marcarAlertaCompletada(alerta.id);
    setState(() => _alertas.remove(alerta));
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─── TARJETA DE ALERTA ──────────────────────
class _TarjetaAlerta extends StatelessWidget {
  final Alerta alerta;
  final VoidCallback onEnviado;

  const _TarjetaAlerta({required this.alerta, required this.onEnviado});

  @override
  Widget build(BuildContext context) {
    final cfg = _config();
    final fmt = NumberFormat('#,##0.00', 'es_MX');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cfg['color'] as Color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(children: [
              Icon(cfg['icono'] as IconData,
                  size: 16, color: cfg['color'] as Color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(cfg['titulo'] as String,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cfg['color'] as Color)),
              ),
            ]),
            const SizedBox(height: 6),

            // Cliente y folio
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF111827)),
                children: [
                  TextSpan(
                      text: alerta.clienteNombre ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (alerta.clienteEmpresa != null)
                    TextSpan(
                        text: ' — ${alerta.clienteEmpresa}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280))),
                ],
              ),
            ),
            if (alerta.cotizacionFolio != null) ...[
              const SizedBox(height: 2),
              Text(
                '${alerta.cotizacionFolio} · \$${fmt.format(alerta.cotizacionTotal ?? 0)} MXN',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],

            // Mensaje preview
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFf0f7f4),
                borderRadius: BorderRadius.circular(6),
                border: const Border(
                  left: BorderSide(color: Color(0xFF25D366), width: 2),
                ),
              ),
              child: Text(
                _mensajePreview(),
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF1a3a5c), height: 1.5),
              ),
            ),

            const SizedBox(height: 10),

            // Botones
            Row(children: [
              Expanded(
                child: _BotonWA(
                  label: cfg['botonTexto'] as String,
                  color: cfg['color'] as Color,
                  onTap: () => _enviarWA(context),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEnviado,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.gris,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.grisBorde),
                  ),
                  child: const Text('Hecho',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _config() {
    switch (alerta.tipo) {
      case 'seguimiento_dia3':
        return {
          'titulo': 'Día 3 sin respuesta',
          'icono': Icons.access_time,
          'color': AppColors.rojo,
          'botonTexto': 'Abrir WhatsApp',
        };
      case 'seguimiento_dia5':
        return {
          'titulo': 'Día 5 — Urgencia',
          'icono': Icons.warning_amber_outlined,
          'color': AppColors.rojo,
          'botonTexto': 'Abrir WhatsApp',
        };
      case 'cupon_dia7':
        return {
          'titulo': 'Día 7 — Enviar cupón',
          'icono': Icons.local_offer_outlined,
          'color': AppColors.ambar,
          'botonTexto': 'Enviar cupón WA',
        };
      case 'post_entrega_redes':
        return {
          'titulo': 'Post-entrega — Enviar redes',
          'icono': Icons.share_outlined,
          'color': AppColors.verde,
          'botonTexto': 'Enviar redes WA',
        };
      default:
        return {
          'titulo': alerta.titulo,
          'icono': Icons.notifications_outlined,
          'color': const Color(0xFF185fa5),
          'botonTexto': 'Abrir WhatsApp',
        };
    }
  }

  String _mensajePreview() {
    final nombre = alerta.clienteNombre?.split(' ').first ?? 'Cliente';
    final folio = alerta.cotizacionFolio ?? '';
    final fmt = NumberFormat('#,##0.00', 'es_MX');
    final total = fmt.format(alerta.cotizacionTotal ?? 0);

    switch (alerta.tipo) {
      case 'seguimiento_dia3':
        return '💬 "Hola $nombre, ¿pudo revisar la cotización $folio? Estoy disponible para cualquier ajuste. — HETNA CNC"';
      case 'seguimiento_dia5':
        return '⏰ "Hola $nombre, la cotización $folio por \$$total MXN está por vencer. ¿Hay algo que podamos ajustar? — HETNA CNC"';
      case 'cupon_dia7':
        return '🎁 "Hola $nombre, tenemos un 5% adicional para usted si confirma esta semana. Código: ${WhatsAppService.generarCodigoCupon(folio)}"';
      case 'post_entrega_redes':
        return '🎉 "¡Gracias $nombre! Síguenos: @hetna_cnc · Al seguirnos recibe 3% en su próxima compra 🎁"';
      default:
        return alerta.mensajeWa ?? '';
    }
  }

  Future<void> _enviarWA(BuildContext context) async {
    final wa = alerta.clienteWhatsapp ?? '';
    if (wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cliente no tiene WhatsApp registrado')),
      );
      return;
    }

    try {
      switch (alerta.tipo) {
        case 'seguimiento_dia3':
          await WhatsAppService.enviarSeguimientoDia3(
            whatsapp: wa,
            nombreCliente: alerta.clienteNombre ?? '',
            folio: alerta.cotizacionFolio ?? '',
            total: alerta.cotizacionTotal ?? 0,
          );
          break;
        case 'seguimiento_dia5':
          await WhatsAppService.enviarSeguimientoDia5(
            whatsapp: wa,
            nombreCliente: alerta.clienteNombre ?? '',
            folio: alerta.cotizacionFolio ?? '',
            total: alerta.cotizacionTotal ?? 0,
            vencimiento:
                DateTime.now().add(const Duration(days: 2)),
          );
          break;
        case 'cupon_dia7':
          await WhatsAppService.enviarCuponCierre(
            whatsapp: wa,
            nombreCliente: alerta.clienteNombre ?? '',
            folio: alerta.cotizacionFolio ?? '',
            codigoCupon: WhatsAppService.generarCodigoCupon(
                alerta.cotizacionFolio ?? ''),
          );
          break;
        case 'post_entrega_redes':
          await WhatsAppService.enviarRedesSociales(
            whatsapp: wa,
            nombreCliente: alerta.clienteNombre ?? '',
            instagram: '@hetna_cnc',
            facebook: 'HETNA CNC',
            tiktok: '@hetnacnc',
          );
          break;
      }
      onEnviado();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

class _BotonWA extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BotonWA(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.chat, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}
