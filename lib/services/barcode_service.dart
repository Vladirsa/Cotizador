// lib/services/barcode_service.dart
// HETNA CNC — Escanear código de barras y buscar el producto en la web
//
// Usa la API gratuita de UPCitemdb (nivel "trial", sin necesidad de
// registrarte ni pagar, límite de ~100 búsquedas al día compartidas
// entre todos los que usan el nivel gratuito desde la misma IP/red).
//
// ⚠️ IMPORTANTE: la mayoría de materiales especializados de un taller
// CNC (madera, MDF, acrílico cortado, piezas hechas a la medida) NO
// van a tener resultado — no son productos de fábrica con código de
// barras comercial. Esto es normal y esperado, no es un error. Esta
// función sirve mejor para consumibles/herramientas de marca conocida
// (tornillos, brocas, pegamentos, etc.) que sí tienen UPC de fábrica.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

class ProductoEscaneado {
  final String? nombre;
  final String? descripcion;
  final String? marca;
  final String? imagenUrl;
  ProductoEscaneado({this.nombre, this.descripcion, this.marca, this.imagenUrl});
}

class BarcodeService {
  // Abre la cámara en pantalla completa y regresa el código detectado.
  // Regresa null si el usuario cancela sin escanear nada.
  static Future<String?> escanear(BuildContext context) {
    return Navigator.push<String>(context,
      MaterialPageRoute(builder: (_) => const _ScannerScreen()));
  }

  // Busca el código de barras en UPCitemdb. Regresa null si no hay
  // conexión, si la API falla, o si el producto no está en su base
  // de datos (lo más probable para materiales especializados).
  static Future<ProductoEscaneado?> buscarProducto(String codigo) async {
    try {
      final uri = Uri.parse(
        'https://api.upcitemdb.com/prod/trial/lookup?upc=$codigo');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = data['items'] as List?;
      if (items == null || items.isEmpty) return null;

      final item = items.first as Map<String, dynamic>;
      final imgs = item['images'] as List?;
      return ProductoEscaneado(
        nombre: item['title'] as String?,
        descripcion: item['description'] as String?,
        marca: item['brand'] as String?,
        imagenUrl: (imgs != null && imgs.isNotEmpty) ? imgs.first.toString() : null,
      );
    } catch (_) {
      return null;
    }
  }

  // Atajo: escanea Y busca en un solo paso. Devuelve null si el
  // usuario cancela, o si escaneó algo pero no se encontró nada —
  // en ese segundo caso, avísale al llamador para que muestre un
  // aviso apropiado ("no se encontró, llena los datos a mano").
  static Future<ProductoEscaneado?> escanearYBuscar(BuildContext context) async {
    final codigo = await escanear(context);
    if (codigo == null) return null;
    return buscarProducto(codigo);
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();
  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool _detectado = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanea el código de barras'),
      ),
      body: Stack(children: [
        MobileScanner(
          onDetect: (capture) {
            if (_detectado) return;
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _detectado = true;
              Navigator.pop(context, barcodes.first.rawValue);
            }
          }),
        // Marco visual para guiar dónde apuntar
        Center(child: Container(
          width: 260, height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(12)))),
        const Positioned(bottom: 40, left: 0, right: 0,
          child: Text('Apunta la cámara al código de barras',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14))),
      ]));
  }
}
