// lib/screens/permisos_screen.dart
// HETNA CNC — Permisos personalizables por rol
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';

class PermisosScreen extends StatefulWidget {
  const PermisosScreen({super.key});
  @override
  State<PermisosScreen> createState() => _PermisosScreenState();
}

class _PermisosScreenState extends State<PermisosScreen> {
  String _rolSel = 'vendedor';
  Set<String> _modulosActivos = {};
  bool _cargando = true;
  bool _guardando = false;

  final _etiquetasRol = {
    'vendedor': '💼 Vendedor',
    'operador_cnc': '⚙️ Operador CNC',
    'almacenista': '📦 Almacenista',
    'contador': '🧮 Contador',
  };

  final _etiquetasModulo = {
    'clientes': ('👥 CRM Clientes', 'Ver y editar clientes'),
    'productos': ('🛒 Productos y Catálogo', 'Ver y editar productos'),
    'inventario': ('📦 Inventario Bodega', 'Movimientos de materiales'),
    'gastos': ('🧾 Gastos y Compras', 'Registrar gastos'),
    'marketing': ('📢 Marketing', 'Campañas de WhatsApp'),
    'equipo': ('👤 Mi Equipo', 'Ver e invitar personal'),
    'reportes': ('📊 Reportes Excel', 'Exportar reportes'),
    'config': ('⚙️ Configuración', 'Datos del taller'),
    'simulador': ('🧮 Simulador de Costos', 'Calcular precios'),
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final permisos = await AuthService.leerPermisosDeRol(_rolSel);
    if (mounted) setState(() {
      // Si el rol nunca se configuró, por default se le dan todos
      // marcados (así el admin decide qué QUITAR, no qué agregar)
      _modulosActivos = permisos.isEmpty
        ? AuthService.modulosDisponibles.toSet()
        : permisos;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final error = await AuthService.guardarPermisosDeRol(_rolSel, _modulosActivos);
    if (mounted) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? '✅ Permisos guardados para ${_etiquetasRol[_rolSel]}'),
        backgroundColor: error != null ? AppColors.rojo : AppColors.verde));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Permisos por rol',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul))),
        ]),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Selecciona un rol para configurar',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8,
              children: AuthService.rolesConfigurables.map((r) {
                final sel = _rolSel == r;
                return GestureDetector(
                  onTap: () { setState(() => _rolSel = r); _cargar(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.azul : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
                    child: Text(_etiquetasRol[r] ?? r,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.textoPrincipal))));
              }).toList()),
          ])),
        const Divider(height: 1),
        Expanded(child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(14), children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.azul),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Los usuarios con rol "${_etiquetasRol[_rolSel]}" solo verán los módulos marcados abajo.',
                    style: const TextStyle(fontSize: 11, color: AppColors.azul))),
                ])),
              const SizedBox(height: 12),
              ...AuthService.modulosDisponibles.map((m) {
                final info = _etiquetasModulo[m]!;
                final activo = _modulosActivos.contains(m);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                  child: SwitchListTile(
                    value: activo,
                    onChanged: (v) => setState(() {
                      if (v) { _modulosActivos.add(m); } else { _modulosActivos.remove(m); }
                    }),
                    activeColor: AppColors.azul,
                    title: Text(info.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(info.$2, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                  ));
              }),
              const SizedBox(height: 20),
            ])),
      ]));
  }
}
