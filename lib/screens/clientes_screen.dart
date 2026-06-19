import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';

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
    _tabs.addListener(() {
      if (_tabs.index == 0) _cargar();
    });
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
        title: const Text('CRM Clientes'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: const [Tab(text: 'Clientes'), Tab(text: 'Nuevo cliente')],
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
        decoration: InputDecoration(hintText: 'Buscar por nombre, empresa, teléfono...', prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: AppColors.gris,
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
            child: Text(t, style: TextStyle(fontSize: 11, color: _tipoFiltro == t ? Colors.white : AppColors.textoSecundario)),
          ),
        )).toList())),
    ])),
    Expanded(child: _cargando
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _cargar,
          child: _filtrados.isEmpty
            ? const Center(child: Text('No hay clientes', style: TextStyle(color: AppColors.textoSecundario)))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filtrados.length,
                itemBuilder: (_, i) => _TarjetaCliente(
                  cliente: _filtrados[i],
                  onEditar: () => _mostrarFormEditar(_filtrados[i]),
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
}

class _TarjetaCliente extends StatelessWidget {
  final Cliente cliente;
  final VoidCallback onEditar;
  const _TarjetaCliente({required this.cliente, required this.onEditar});

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
              onPressed: () => WhatsAppService.abrirChat(numero: cliente.whatsappNumero, nombre: cliente.nombre),
            ),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textoSecundario), onPressed: onEditar),
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
        title: Text(widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente'),
        leading: widget.cliente != null ? IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)) : null,
        actions: [
          TextButton(onPressed: _guardar, child: _guardando
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(14), children: [
        _campo('Nombre completo *', _nombre, obligatorio: true),
        _campo('Empresa', _empresa),
        _campo('RFC', _rfc),
        _campo('Domicilio (calle y número)', _domicilio),
        Row(children: [
          Expanded(child: _campo('Ciudad', _ciudad)),
          const SizedBox(width: 8),
          Expanded(child: _campo('Estado', _estado)),
        ]),
        Row(children: [
          Expanded(child: _campo('Código Postal', _cp, tipo: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: _campo('Teléfono', _tel, tipo: TextInputType.phone)),
        ]),
        Row(children: [
          Expanded(child: _campo('WhatsApp', _wa, tipo: TextInputType.phone)),
          const SizedBox(width: 8),
          Expanded(child: _campo('Correo', _correo, tipo: TextInputType.emailAddress)),
        ]),
        const SizedBox(height: 4),
        const Text('Tipo de cliente', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _tipo,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _tipo = v!),
        ),
        const SizedBox(height: 8),
        _campo('Notas internas', _notas, lineas: 3),
        ElevatedButton(onPressed: _guardar, child: Text(widget.cliente == null ? 'Guardar cliente' : 'Actualizar cliente')),
      ])),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, {bool obligatorio = false, TextInputType tipo = TextInputType.text, int lineas = 1}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl, keyboardType: tipo, maxLines: lineas,
        validator: obligatorio ? (v) => v?.isEmpty == true ? 'Requerido' : null : null,
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
