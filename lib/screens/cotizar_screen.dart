import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/archivo_cad_service.dart';
import 'simulador_screen.dart';
import '../simulador2/simulador2_screen.dart';
import '../simulador2/simulador2_data.dart';
import 'envios_screen.dart';
import 'crm_seguimiento_screen.dart';
import '../services/crm_service.dart';
import '../services/auth_service.dart';
import '../i18n/tr.dart';

class CotizarScreen extends StatefulWidget {
  final dynamic itemInicial;
  final List<dynamic>? carritoSimulador;
  const CotizarScreen({super.key, this.itemInicial, this.carritoSimulador});
  @override
  State<CotizarScreen> createState() => _CotizarScreenState();
}

class _CotizarScreenState extends State<CotizarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Text(tr('Cotizador')),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: [
            Tab(text: tr('Nueva')),
            Tab(text: tr('Mis cotizaciones')),
            Tab(text: tr('Catálogo')),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _NuevaCotizacion(itemInicial: widget.itemInicial, carritoSimulador: widget.carritoSimulador, onGuardada: () => _tabs.animateTo(1)),
        _ListaCotizaciones(),
        const _CatalogoPDFs(),
      ]),
    );
  }
}

═══════════════════════════════════════════
// LISTA DE COTIZACIONES — con búsqueda + filtro de fechas
═══════════════════════════════════════════
