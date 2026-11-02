// lib/services/entrar_tienda.dart
// Entrar a la app con la cuenta de hetnacnc.com (una sola cuenta).
//
// En la web el botón lleva a la tienda y regresa con la sesión. En Android no
// hay a dónde regresar, así que aquí se pide el correo y la contraseña de la
// tienda y se manda a hetnacnc.com/api/app/entrar-tienda, que:
//   - valida la cuenta de la tienda,
//   - encuentra (o crea, con 14 días de prueba) el taller vinculado,
//   - y devuelve un token de un solo uso de Supabase (token_hash).
// Con ese token se pide la sesión a Supabase (/auth/v1/verify) y la app queda
// adentro como el administrador de su taller, sin otra contraseña.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n/tr.dart';
import '../main.dart' show AppColors, supabaseKey, supabaseUrl;
import 'auth_service.dart';
import 'hetna_api.dart';

class _Respuesta {
  final String? tokenHash;
  final Map<String, dynamic>? activar;
  final String? mensaje;
  const _Respuesta({this.tokenHash, this.activar, this.mensaje});
}

Future<_Respuesta> _pedirEntrada(String correo, String clave, {String? taller, String? telefono}) async {
  try {
    final r = await http
        .post(Uri.parse('${HetnaApi.base}/api/app/entrar-tienda'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': correo,
              'password': clave,
              if (taller != null) 'taller': taller,
              if (telefono != null) 'telefono': telefono,
            }))
        .timeout(const Duration(seconds: 30));
    final d = (jsonDecode(r.body.isEmpty ? '{}' : r.body) as Map).cast<String, dynamic>();
    if (r.statusCode == 200 && d['token_hash'] is String) return _Respuesta(tokenHash: d['token_hash'] as String);
    if (r.statusCode == 200 && d['activar'] is Map) {
      return _Respuesta(activar: (d['activar'] as Map).cast<String, dynamic>());
    }
    return _Respuesta(mensaje: (d['message'] as String?) ?? tr('No se pudo entrar. Intenta de nuevo.'));
  } catch (_) {
    return _Respuesta(mensaje: tr('Error de conexión. Verifica tu internet.'));
  }
}

/// Cambia el token de un solo uso por la sesión de Supabase. null = listo.
Future<String?> _abrirSesion(String tokenHash) async {
  try {
    final r = await http
        .post(Uri.parse('$supabaseUrl/auth/v1/verify'),
            headers: {'Content-Type': 'application/json', 'apikey': supabaseKey},
            body: jsonEncode({'type': 'magiclink', 'token_hash': tokenHash}))
        .timeout(const Duration(seconds: 30));
    final d = (jsonDecode(r.body.isEmpty ? '{}' : r.body) as Map).cast<String, dynamic>();
    final refresh = d['refresh_token'];
    if (r.statusCode != 200 || refresh is! String) return tr('La liga de acceso ya no sirve. Intenta de nuevo.');
    await Supabase.instance.client.auth.setSession(refresh);
    final ok = await AuthService.restaurarSesion();
    if (!ok) {
      await AuthService.logout();
      return tr('Tu cuenta no tiene un taller en la app. Escríbenos por WhatsApp.');
    }
    return null;
  } catch (_) {
    return tr('No se pudo abrir la sesión. Intenta de nuevo.');
  }
}

/// Muestra el formulario. Devuelve true si la app ya quedó con la sesión abierta.
Future<bool> entrarConCuentaTienda(BuildContext context) async {
  final correoCtrl = TextEditingController();
  final claveCtrl = TextEditingController();
  final tallerCtrl = TextEditingController();
  final telCtrl = TextEditingController();
  bool cargando = false;
  bool pideTaller = false;
  bool verClave = false;
  String? error;

  final resultado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
      Future<void> enviar() async {
        final correo = correoCtrl.text.trim();
        final clave = claveCtrl.text;
        if (!correo.contains('@') || clave.isEmpty) {
          setS(() => error = tr('Escribe tu correo y tu contraseña de hetnacnc.com.'));
          return;
        }
        if (pideTaller && tallerCtrl.text.trim().length < 2) {
          setS(() => error = tr('Escribe el nombre de tu taller.'));
          return;
        }
        setS(() { cargando = true; error = null; });
        final r = await _pedirEntrada(correo, clave,
            taller: pideTaller ? tallerCtrl.text.trim() : null,
            telefono: pideTaller ? telCtrl.text.trim() : null);
        if (r.tokenHash != null) {
          final fallo = await _abrirSesion(r.tokenHash!);
          if (fallo == null) {
            if (ctx.mounted) Navigator.pop(ctx, true);
            return;
          }
          setS(() { cargando = false; error = fallo; });
          return;
        }
        if (r.activar != null) {
          // La cuenta de la tienda todavía no tiene taller en la app: se crea
          // ahora (14 días de prueba) con su nombre y teléfono.
          tallerCtrl.text = (r.activar!['taller'] as String?) ?? tallerCtrl.text;
          telCtrl.text = (r.activar!['telefono'] as String?) ?? telCtrl.text;
          setS(() { cargando = false; pideTaller = true; });
          return;
        }
        setS(() { cargando = false; error = r.mensaje; });
      }

      return AlertDialog(
        title: Text(pideTaller ? tr('Crea tu taller en la app') : tr('Entrar con hetnacnc.com')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              pideTaller
                  ? tr('Tu cuenta de la tienda todavía no tiene taller en la app. Ponle nombre y empieza con 14 días de prueba.')
                  : tr('Usa el mismo correo y contraseña con los que entras a la tienda.'),
              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(height: 14),
            if (!pideTaller) ...[
              TextField(
                controller: correoCtrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: tr('Correo electrónico'), isDense: true, border: const OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: claveCtrl,
                obscureText: !verClave,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => cargando ? null : enviar(),
                decoration: InputDecoration(
                  labelText: tr('Contraseña'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(verClave ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setS(() => verClave = !verClave)))),
            ] else ...[
              TextField(
                controller: tallerCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: tr('Nombre del taller'), isDense: true, border: const OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('Teléfono (opcional)'), isDense: true, border: const OutlineInputBorder())),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(fontSize: 12, color: AppColors.rojo)),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: cargando ? null : () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: cargando ? null : enviar,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
            child: cargando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(pideTaller ? tr('Crear y entrar') : tr('Entrar'), style: const TextStyle(color: Colors.white))),
        ],
      );
    }),
  );
  return resultado == true;
}
