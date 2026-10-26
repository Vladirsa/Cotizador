// lib/i18n/tr.dart
// HETNA CNC — Idioma de la app (español / inglés)
//
// Los textos se escriben en español en el código y se envuelven con tr():
//   Text(tr('Guardar'))                       -> "Save" si la app está en inglés
//   Text(trf('Hola {0}, tienes {1}', [n, c])) -> "Hi {0}, you have {1}"
// El diccionario español -> inglés está en en.dart (mismo esquema que la web:
// apps/storefront/src/i18n/en.ts de hetnacnc). Si un texto no está en el
// diccionario, se muestra en español.
//
// El idioma: el que el usuario eligió en Configuración; si nunca eligió, el
// del teléfono o del navegador (inglés si está en inglés, si no, español).
import 'dart:ui' show Locale, PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'en.dart';

final ValueNotifier<Locale> idiomaActual = ValueNotifier(const Locale('es', 'MX'));

/// true si la app está en inglés
bool get enIngles => idiomaActual.value.languageCode == 'en';

/// 'en_US' o 'es_MX', para DateFormat y NumberFormat
String get localeFormato => enIngles ? 'en_US' : 'es_MX';

/// Cambia el idioma desde Configuración y lo recuerda en el dispositivo.
Future<void> cambiarIdioma(String codigo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('idioma', codigo);
  } catch (_) {}
  idiomaActual.value = codigo == 'en' ? const Locale('en', 'US') : const Locale('es', 'MX');
}

/// Al arrancar: el idioma guardado; si no hay, el del teléfono o navegador.
Future<void> cargarIdioma() async {
  String? codigo;
  try {
    codigo = (await SharedPreferences.getInstance()).getString('idioma');
  } catch (_) {}
  codigo ??= PlatformDispatcher.instance.locale.languageCode == 'en' ? 'en' : 'es';
  idiomaActual.value = codigo == 'en' ? const Locale('en', 'US') : const Locale('es', 'MX');
}

/// Traduce un texto escrito en español al idioma de la app.
String tr(String es) => enIngles ? (textosEn[es] ?? es) : es;

/// Igual que tr() pero con valores: trf('Hola {0}', [nombre])
String trf(String es, List<Object?> valores) => _rellenar(tr(es), valores);

/// Para documentos con su propio idioma (p. ej. el PDF de una cotización).
String trIdioma(String es, bool ingles) => ingles ? (textosEn[es] ?? es) : es;

String trfIdioma(String es, bool ingles, List<Object?> valores) => _rellenar(trIdioma(es, ingles), valores);

String _rellenar(String texto, List<Object?> valores) {
  var t = texto;
  for (var i = 0; i < valores.length; i++) {
    t = t.replaceAll('{$i}', '${valores[i] ?? ''}');
  }
  return t;
}

/// Un porcentaje sin decimales de sobra: 16 -> "16", 8.25 -> "8.25"
String pctTexto(num v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}
