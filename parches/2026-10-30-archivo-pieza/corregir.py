# Corrige dos líneas del parche resto.patch (se transcribió a mano) y lo deja listo para git apply
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
a = "               child: pw.Text(mm(ancho), style: estilo, textAlign: pw.TextAlign.center))),"
b = "               child: pw.Text(mm(ancho), style: estilo, textAlign: pw.TextAlign.right))),"
assert a in s, 'linea 1 no encontrada'
s = s.replace(a, b, 1)
c = "+              if (cotizacion.ivaPct > 0) _tR(_tf('IVA {0}%', [pctTexto(cotizacion.ivaPct)]), '\\$${_fmt.format(cotizacion.montoIva)}', grisTexto),"
d = "+              if (cotizacion.ivaPct > 0) _tR('${_etqIva(empresa)} ${pctTexto(cotizacion.ivaPct)}%', '\\$${_fmt.format(cotizacion.montoIva)}', grisTexto),"
assert c in s, 'linea 2 no encontrada'
s = s.replace(c, d, 1)
open(p, 'w', encoding='utf-8').write(s)
print('parche corregido')
