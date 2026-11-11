// lib/services/pais.dart
// HETNA Cotizador — País del taller: moneda, impuesto, etiquetas fiscales,
// lada de WhatsApp, formato de dinero y valores de referencia.
//
// El país se guarda en configuracion_empresa.pais_factura ('MX', 'US', 'CO',
// 'PE', 'CL') y la moneda en configuracion_empresa.moneda. Los dos se leen al
// abrir la configuración (SupabaseService.getConfiguracion) y quedan aquí
// para toda la app:
//   Pais.actual       el país del taller (México por defecto)
//   Pais.moneda       'MXN', 'USD', 'COP', 'PEN' o 'CLP'
//   Pais.fmt()        NumberFormat con el símbolo y los decimales de la moneda
//   Pais.ref(350)     convierte un valor de referencia HETNA (pesos mexicanos)
//                     a la moneda del taller, redondeado
//
// Las referencias son aproximadas (tipo de cambio de noviembre de 2026); en la
// app siempre dicen "referencia" y el taller pone su precio real.
import 'dart:ui' show PlatformDispatcher;
import 'package:intl/intl.dart';

class InfoPais {
  final String codigo;          // ISO 3166: MX, US, CO, PE, CL
  final String nombre;          // en español; la pantalla lo pasa por tr()
  final String bandera;
  final String moneda;          // ISO 4217
  final double impuesto;        // % por defecto
  final String etqImpuesto;     // IVA, Sales tax, IGV
  final String etqId;           // RFC, Tax ID, NIT, RUC, RUT
  final String lada;            // código telefónico sin '+'
  final int digitosTel;         // dígitos de un celular nacional
  // Multiplicadores para pasar los valores de referencia HETNA (MXN) a la
  // moneda local. Máquina/operador y material por separado porque en EE. UU.
  // la hora de taller cuesta mucho más que el tipo de cambio.
  final double factorHora, factorMaterial;
  const InfoPais(this.codigo, this.nombre, this.bandera, this.moneda, this.impuesto, this.etqImpuesto,
      this.etqId, this.lada, this.digitosTel, this.factorHora, this.factorMaterial);
}

class Pais {
  // Tipo de cambio de referencia por dólar (6 nov 2026): MXN 18.63 · COP 3,246
  // · PEN 3.43 · CLP 977. Factor = moneda local por cada peso mexicano.
  static const lista = <InfoPais>[
    InfoPais('MX', 'México', '🇲🇽', 'MXN', 16, 'IVA', 'RFC', '52', 10, 1, 1),
    InfoPais('US', 'Estados Unidos', '🇺🇸', 'USD', 0, 'Sales tax', 'Tax ID', '1', 10, 0.2, 0.075),
    InfoPais('CO', 'Colombia', '🇨🇴', 'COP', 19, 'IVA', 'NIT', '57', 10, 174, 174),
    InfoPais('PE', 'Perú', '🇵🇪', 'PEN', 18, 'IGV', 'RUC', '51', 9, 0.184, 0.184),
    InfoPais('CL', 'Chile', '🇨🇱', 'CLP', 19, 'IVA', 'RUT', '56', 9, 52.5, 52.5),
  ];

  /// Monedas que el taller puede elegir para sus cotizaciones.
  static const monedas = ['MXN', 'USD', 'COP', 'PEN', 'CLP'];

  static InfoPais actual = lista.first;
  static String moneda = 'MXN';

  static InfoPais de(String? codigo) {
    final c = (codigo ?? '').trim().toUpperCase();
    return lista.firstWhere((p) => p.codigo == c, orElse: () => lista.first);
  }

  static bool esValido(String? codigo) => lista.any((p) => p.codigo == (codigo ?? '').trim().toUpperCase());

  /// País del teléfono o navegador, si es uno de los nuestros (para la alta guiada).
  static InfoPais delDispositivo() {
    try {
      final c = PlatformDispatcher.instance.locale.countryCode;
      if (esValido(c)) return de(c);
    } catch (_) {}
    return actual;
  }

  /// Lo llama SupabaseService al leer la configuración del taller.
  static void desdeConfig(Map<String, dynamic> cfg) {
    actual = de(cfg['pais_factura']?.toString());
    final m = (cfg['moneda'] ?? '').toString().trim().toUpperCase();
    moneda = monedas.contains(m) ? m : actual.moneda;
  }

  // ── Dinero ──
  static String simboloDe(String m) => m == 'PEN' ? 'S/ ' : r'$';
  static bool sinCentavosEn(String m) => m == 'COP' || m == 'CLP';
  static String get simbolo => simboloDe(moneda);
  static bool get sinCentavos => sinCentavosEn(moneda);

  /// Formato con símbolo. centavos:false para cantidades redondas en pantalla.
  static NumberFormat fmt({bool centavos = true, String? enMoneda}) {
    final m = enMoneda ?? moneda;
    return NumberFormat.currency(locale: 'es_MX', symbol: simboloDe(m),
        decimalDigits: (centavos && !sinCentavosEn(m)) ? 2 : 0);
  }

  /// Formato sin símbolo (PDF: el símbolo lo pone quien llama).
  static NumberFormat fmtNumero({String? enMoneda}) =>
      NumberFormat(sinCentavosEn(enMoneda ?? moneda) ? '#,##0' : '#,##0.00', 'es_MX');

  // ── Valores de referencia HETNA (vienen en pesos mexicanos) ──
  static double _redondear(double v) {
    if (v >= 100000) return (v / 1000).roundToDouble() * 1000;
    if (v >= 10000) return (v / 100).roundToDouble() * 100;
    if (v >= 1000) return (v / 10).roundToDouble() * 10;
    if (v >= 100) return v.roundToDouble();
    return (v * 100).roundToDouble() / 100;
  }

  // Las referencias salen en la moneda en que cotiza el taller (un taller de
  // México que cotiza en dólares ve las referencias de EE. UU.).
  static InfoPais get _deLaMoneda => lista.firstWhere((p) => p.moneda == moneda, orElse: () => actual);

  /// $/hora de máquina u operador de referencia, en la moneda de [p] (o del taller).
  static double refHora(double mxn, [InfoPais? p]) => _redondear(mxn * (p ?? _deLaMoneda).factorHora);

  /// Precio de material de referencia, en la moneda de [p] (o del taller).
  static double refMaterial(double mxn, [InfoPais? p]) => _redondear(mxn * (p ?? _deLaMoneda).factorMaterial);
}
