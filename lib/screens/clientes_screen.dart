import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';
import '../i18n/tr.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Cliente> _clientes = [];
  List<Cliente> _filtrados = [];
  bool _cargando = true;
  String _busqueda = '';
  String _tipoFiltro = 'Todos';

  final _tipos = ['Todos', 'Cliente activo', 'Cliente frecuente', 'Cliente potencial', 'Distribuidor'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final lista = await SupabaseService.getClientes();
      setState(() {
        _clientes = lista;
        _aplicarFiltros();
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    _filtrados = _clientes.where((c) {
      final matchBusqueda = _busqueda.isEmpty ||
          c.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          (c.empresa?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false) ||
          (c.telefono?.contains(_busqueda) ?? false);
      final matchTipo = _tipoFiltro == 'Todos' || c.tipoCliente == _tipoFiltro;
      return matchBusqueda && matchTipo;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Text(tr('CRM Clientes')),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: [Tab(text: tr('Clientes')), Tab(text: tr('Nuevo cliente'))],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _listaClientes(),
        _formNuevoCliente(),
      ]),
    );
  }

  Widget _listaClientes() => Column(children: [
    Container(color: Colors.white, padding: const EdgeInsets.all(12), child: Column(children: [
      TextField(
        decoration: InputDecoration(hintText: tr('Buscar por nombre, empresa, teléfono...'), prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: AppColors.gris,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12)),
        onChanged: (v) => setState(() { _busqueda = v; _aplicarFiltros(); }),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _tipos.map((t) =>
        GestureDetector(
          onTap: () => setState(() { _tipoFiltro = t; _aplicarFiltros(); }),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _tipoFiltro == t ? AppColors.azul : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _tipoFiltro == t ? AppColors.azul : AppColors.grisBorde)),
            child: Text(tr(t), style: TextStyle(fontSize: 11, color: _tipoFiltro == t ? Colors.white : AppColors.textoSecundario)),
          ),
        )).toList())),
    ])),
    Expanded(child: _cargando
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _cargar,
          child: _filtrados.isEmpty
            ? Center(child: Text(tr('No hay clientes'), style: TextStyle(color: AppColors.textoSecundario)))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filtrados.length,
                itemBuilder: (_, i) => _TarjetaCliente(
                  cliente: _filtrados[i],
                  onEditar: () => _mostrarFormEditar(_filtrados[i]),
                  onEliminar: () => _eliminarCliente(_filtrados[i]),
                ),
              ),
        )),
  ]);

  Widget _formNuevoCliente() => _FormCliente(
    onGuardado: () {
      _cargar();
      _tabs.animateTo(0);
    },
  );

  void _mostrarFormEditar(Cliente cliente) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: _FormCliente(cliente: cliente, onGuardado: () { Navigator.pop(context); _cargar(); }),
      ),
    );
  }

  Future<void> _eliminarCliente(Cliente cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Eliminar cliente')),
        content: Text(trf('¿Eliminar a "{0}"? Se borrarán también sus cotizaciones y datos relacionados.', [(cliente.nombre)])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: Text(tr('Eliminar'), style: TextStyle(color: Colors.white))),
        ]));
    if (confirmar == true && cliente.id != null) {
      try {
        await SupabaseService.eliminarCliente(cliente.id!);
        await _cargar();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Cliente eliminado')),
          backgroundColor: AppColors.rojo));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }
}


// ══════════════════════════════════════════════════════
// PANTALLA DE HISTORIAL DEL CLIENTE
// ══════════════════════════════════════════════════════
class HistorialClienteScreen extends StatefulWidget {
  final Cliente cliente;
  const HistorialClienteScreen({super.key, required this.cliente});
  @override
  State<HistorialClienteScreen> createState() => _HistorialClienteScreenState();
}

class _HistorialClienteScreenState extends State<HistorialClienteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Cotizacion> _cotizaciones = [];
  List<Pedido> _pedidos = [];
  bool _cargando = true;

  final _fmt = NumberFormat(r'$#,##0', 'es_MX');
  final _fmtFecha = DateFormat('dd/MM/yyyy', 'es_MX');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final cots = await SupabaseService.getCotizacionesByCliente(widget.cliente.id!);
      final peds = await SupabaseService.getPedidosByCliente(widget.cliente.id!);
      if (mounted) setState(() {
        _cotizaciones = cots;
        _pedidos = peds;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  double get _totalHistorico =>
    _pedidos.where((p) => p.estado == 'Entregado')
      .fold(0, (s, p) => s + (p.total ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.cliente.nombre,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.azul)),
          if (widget.cliente.empresa != null)
            Text(widget.cliente.empresa!,
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ]),
        actions: [
          // Botón WhatsApp
          if ((widget.cliente.whatsapp ?? widget.cliente.telefono) != null)
            IconButton(
              icon: const Icon(Icons.chat_outlined, color: AppColors.verde),
              onPressed: () {
                final n = widget.cliente.whatsappNumero;
                if (n.isNotEmpty) {
                  final num = n.length == 10 ? '521$n' : n;
                  launchUrl(Uri.parse('https://wa.me/$num'),
                    mode: LaunchMode.externalApplication);
                }
              }),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: [
            Tab(text: trf('Cotizaciones ({0})', [(_cotizaciones.length)])),
            Tab(text: trf('Pedidos ({0})', [(_pedidos.length)])),
          ])),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // KPIs del cliente
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                _kpi(tr('Cotizaciones'), '${_cotizaciones.length}', AppColors.azul),
                _kpi(tr('Pedidos'), '${_pedidos.length}', AppColors.naranja),
                _kpi(tr('Total histórico'), _fmt.format(_totalHistorico), AppColors.verde),
              ])),
            Expanded(child: TabBarView(controller: _tabs, children: [
              _tabCotizaciones(),
              _tabPedidos(),
            ])),
          ]));
  }

  Widget _tabCotizaciones() => _cotizaciones.isEmpty
    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 48, color: AppColors.grisBorde),
          SizedBox(height: 8),
          Text(tr('Sin cotizaciones'), style: TextStyle(color: AppColors.textoSecundario)),
        ]))
    : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _cotizaciones.length,
        itemBuilder: (_, i) => _cardCotizacion(_cotizaciones[i]));

  Widget _tabPedidos() => _pedidos.isEmpty
    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 48, color: AppColors.grisBorde),
          SizedBox(height: 8),
          Text(tr('Sin pedidos'), style: TextStyle(color: AppColors.textoSecundario)),
        ]))
    : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pedidos.length,
        itemBuilder: (_, i) => _cardPedido(_pedidos[i]));

  Widget _cardCotizacion(Cotizacion c) {
    final color = _colorEstado(c.estado);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3),
          top: BorderSide(color: AppColors.grisBorde, width: 0.5),
          right: BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(tr(c.folio ?? tr('Sin folio')),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.azul)),
            const SizedBox(height: 2),
            Text(tr(c.createdAt != null ? _fmtFecha.format(c.createdAt!) : ''),
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(c.estado,
                style: TextStyle(fontSize: 10, color: color,
                  fontWeight: FontWeight.w600))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt.format(c.total),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: AppColors.azul)),
            const SizedBox(height: 4),
            if (c.pdfUrl != null)
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(c.pdfUrl!),
                  mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.rojo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf_outlined,
                      size: 14, color: AppColors.rojo),
                    SizedBox(width: 4),
                    Text(tr('Ver PDF'), style: TextStyle(
                      fontSize: 10, color: AppColors.rojo,
                      fontWeight: FontWeight.w600)),
                  ]))),
          ]),
        ])));
  }

  Widget _cardPedido(Pedido p) {
    const etapas = ['Pedido','Pago','Produccion','Pruebas','Entrega','Entregado'];
    final idx = etapas.indexOf(p.estado);
    final pct = idx < 0 ? 0.0 : (idx + 1) / etapas.length;
    final color = p.estado == 'Entregado' ? AppColors.verde
      : p.estado == 'Produccion' ? AppColors.naranja : AppColors.azul;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(p.folio, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
            Text(tr(p.createdAt != null ? _fmtFecha.format(p.createdAt!) : ''),
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt.format(p.total ?? 0),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: AppColors.azul)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(p.estado,
                style: TextStyle(fontSize: 10, color: color,
                  fontWeight: FontWeight.w600))),
          ]),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: AppColors.grisBorde,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: etapas.map((e) => Text(e.substring(0, 3),
            style: TextStyle(fontSize: 8,
              color: etapas.indexOf(e) <= idx ? color : AppColors.grisBorde,
              fontWeight: etapas.indexOf(e) == idx
                ? FontWeight.w700 : FontWeight.normal))).toList()),
      ]));
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'Aprobada': return AppColors.verde;
      case 'Pedido': return AppColors.azul;
      case 'Enviada': return AppColors.naranja;
      case 'Rechazada': case 'Vencida': return AppColors.rojo;
      default: return AppColors.textoSecundario;
    }
  }

  Widget _kpi(String label, String val, Color color) =>
    Expanded(child: Column(children: [
      Text(tr(val), style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      Text(tr(label), style: const TextStyle(
        fontSize: 9, color: AppColors.textoSecundario)),
    ]));
}

class _TarjetaCliente extends StatelessWidget {
  final Cliente cliente;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  const _TarjetaCliente({required this.cliente, required this.onEditar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final colores = {
      'Cliente potencial': AppColors.ambar, 'Cliente activo': AppColors.verde,
      'Cliente frecuente': AppColors.azul, 'Distribuidor': const Color(0xFF7c3aed),
    };
    final color = colores[cliente.tipoCliente] ?? AppColors.textoSecundario;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: cliente.id != null ? () => Navigator.push(context,
          MaterialPageRoute(builder: (_) =>
            HistorialClienteScreen(cliente: cliente))) : null,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Text(cliente.nombre.substring(0, 1).toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
        title: Text(cliente.nombreCompleto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (cliente.ciudad != null) Text(cliente.ciudad!, style: const TextStyle(fontSize: 11)),
          Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(cliente.tipoCliente, style: TextStyle(fontSize: 10, color: color))),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (cliente.whatsappNumero.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
              onPressed: () => WhatsAppService.abrirChat(
  numero: cliente.whatsappNumero,
  mensaje: trf('¡Hola {0}! Te contacto de *HETNA CNC*. ¿En qué podemos ayudarte?', [(cliente.nombre)])),
            ),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textoSecundario), onPressed: onEditar),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.rojo), onPressed: onEliminar),
        ]),
      ),
    );
  }
}

class _FormCliente extends StatefulWidget {
  final Cliente? cliente;
  final VoidCallback onGuardado;
  const _FormCliente({this.cliente, required this.onGuardado});
  @override
  State<_FormCliente> createState() => _FormClienteState();
}

class _FormClienteState extends State<_FormCliente> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.cliente?.nombre);
  late final _empresa = TextEditingController(text: widget.cliente?.empresa);
  late final _rfc = TextEditingController(text: widget.cliente?.rfc);
  late final _domicilio = TextEditingController(text: widget.cliente?.domicilio);
  late final _ciudad = TextEditingController(text: widget.cliente?.ciudad);
  late final _estado = TextEditingController(text: widget.cliente?.estado);
  late final _cp = TextEditingController(text: widget.cliente?.codigoPostal);
  late final _tel = TextEditingController(text: widget.cliente?.telefono);
  late final _wa = TextEditingController(text: widget.cliente?.whatsapp);
  late final _correo = TextEditingController(text: widget.cliente?.correo);
  late final _notas = TextEditingController(text: widget.cliente?.notas);
  String _tipo = 'Cliente potencial';
  bool _guardando = false;

  final _tipos = ['Cliente potencial', 'Cliente activo', 'Cliente frecuente', 'Distribuidor'];

  @override
  void initState() {
    super.initState();
    _tipo = widget.cliente?.tipoCliente ?? 'Cliente potencial';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(tr(widget.cliente == null ? tr('Nuevo cliente') : tr('Editar cliente'))),
        leading: widget.cliente != null ? IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)) : null,
        actions: [
          TextButton(onPressed: _guardar, child: _guardando
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(tr('Guardar'), style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(14), children: [
        _campo(tr('Nombre completo *'), _nombre, obligatorio: true),
        _campo(tr('Empresa'), _empresa),
        _campo('RFC', _rfc),
        _campo(tr('Domicilio (calle y número)'), _domicilio),
        Row(children: [
          Expanded(child: _campo(tr('Ciudad'), _ciudad)),
          const SizedBox(width: 8),
          Expanded(child: _campo(tr('Estado'), _estado)),
        ]),
        Row(children: [
          Expanded(child: _campo(tr('Código Postal'), _cp, tipo: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: _campo(tr('Teléfono'), _tel, tipo: TextInputType.phone)),
        ]),
        Row(children: [
          Expanded(child: _campo(tr('WhatsApp'), _wa, tipo: TextInputType.phone)),
          const SizedBox(width: 8),
          Expanded(child: _campo(tr('Correo'), _correo, tipo: TextInputType.emailAddress)),
        ]),
        const SizedBox(height: 4),
        Text(tr('Tipo de cliente'), style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _tipo,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(tr(t), style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _tipo = v!),
        ),
        const SizedBox(height: 8),
        _campo(tr('Notas internas'), _notas, lineas: 3),
        ElevatedButton(onPressed: _guardar, child: Text(tr(widget.cliente == null ? tr('Guardar cliente') : tr('Actualizar cliente')))),
      ])),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, {bool obligatorio = false, TextInputType tipo = TextInputType.text, int lineas = 1}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(label), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl, keyboardType: tipo, maxLines: lineas,
        validator: obligatorio ? (v) => v?.isEmpty == true ? tr('Requerido') : null : null,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        style: const TextStyle(fontSize: 13),
      ),
    ]));

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final cliente = Cliente(
        id: widget.cliente?.id,
        nombre: _nombre.text.trim(),
        empresa: _empresa.text.trim().isEmpty ? null : _empresa.text.trim(),
        rfc: _rfc.text.trim().isEmpty ? null : _rfc.text.trim(),
        domicilio: _domicilio.text.trim().isEmpty ? null : _domicilio.text.trim(),
        ciudad: _ciudad.text.trim().isEmpty ? null : _ciudad.text.trim(),
        estado: _estado.text.trim().isEmpty ? null : _estado.text.trim(),
        codigoPostal: _cp.text.trim().isEmpty ? null : _cp.text.trim(),
        telefono: _tel.text.trim().isEmpty ? null : _tel.text.trim(),
        whatsapp: _wa.text.trim().isEmpty ? null : _wa.text.trim(),
        correo: _correo.text.trim().isEmpty ? null : _correo.text.trim(),
        tipoCliente: _tipo,
        notas: _notas.text.trim().isEmpty ? null : _notas.text.trim(),
      );
      if (widget.cliente == null) {
        await SupabaseService.crearCliente(cliente);
      } else {
        await SupabaseService.actualizarCliente(cliente);
      }
      widget.onGuardado();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ══════════════════════════════════════════════
// Widget selector de etiquetas
// ══════════════════════════════════════════════
class SelectorEtiquetasCliente extends StatefulWidget {
  final String? clienteId;
  const SelectorEtiquetasCliente({super.key, this.clienteId});
  @override
  State<SelectorEtiquetasCliente> createState() => _SelectorEtiquetasClienteState();
}

class _SelectorEtiquetasClienteState extends State<SelectorEtiquetasCliente> {
  List<Map<String, dynamic>> _todas = [];
  List<String> _selIds = [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    if (widget.clienteId == null) { setState(() => _cargando = false); return; }
    try {
      final results = await Future.wait([
        SupabaseService.getEtiquetas(),
        SupabaseService.getEtiquetasCliente(widget.clienteId!),
      ]);
      final todas = results[0] as List<Map<String, dynamic>>;
      final nombres = results[1] as List<String>;
      if (mounted) setState(() {
        _todas = todas;
        _selIds = todas.where((e) => nombres.contains(e['nombre'])).map((e) => e['id'] as String).toList();
        _cargando = false;
      });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  Future<void> _toggle(String id) async {
    final nueva = List<String>.from(_selIds);
    if (nueva.contains(id)) nueva.remove(id); else nueva.add(id);
    setState(() { _selIds = nueva; _guardando = true; });
    try {
      await SupabaseService.setEtiquetasCliente(widget.clienteId!, nueva);
    } catch (_) {}
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox(height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    if (_todas.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(tr('Etiquetas'), style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        if (_guardando) ...[
          const SizedBox(width: 8),
          const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
        ],
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: _todas.map((et) {
        final id = et['id'] as String;
        final sel = _selIds.contains(id);
        final hex = (et['color_hex'] as String? ?? '#1a3a5c').replaceAll('#', '');
        final color = Color(int.parse('FF$hex', radix: 16));
        return GestureDetector(
          onTap: widget.clienteId != null ? () => _toggle(id) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? color : AppColors.grisBorde)),
            child: Text(tr(et['nombre'] as String? ?? ''),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AppColors.textoSecundario))));
      }).toList()),
    ]);
  }
}
