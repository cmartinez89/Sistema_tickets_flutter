import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminScreen extends StatelessWidget {
  final ApiService api;
  const AdminScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: const Text(
            'Administración de Catálogos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.category_rounded, size: 18), text: 'Categorías'),
              Tab(icon: Icon(Icons.apartment_rounded, size: 18), text: 'Áreas'),
              Tab(icon: Icon(Icons.devices_rounded, size: 18), text: 'Tipos de Equipo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CatalogoManager(
              titulo: 'Categorías de Ticket',
              icono: Icons.label_rounded,
              color: Colors.indigo,
              onFetch: api.fetchCategorias,
              onCreate: (nombre) => api.crearCategoria(nombre),
              onUpdate: (id, nombre) => api.actualizarCategoria(id, nombre),
              onDelete: (id) => api.eliminarCategoria(id),
            ),
            _CatalogoManager(
              titulo: 'Áreas / Departamentos',
              icono: Icons.business_rounded,
              color: const Color(0xFF1A2B72),
              onFetch: api.fetchAreas,
              onCreate: (nombre) => api.crearArea(nombre),
              onUpdate: (id, nombre) => api.actualizarArea(id, nombre),
              onDelete: (id) => api.eliminarArea(id),
            ),
            _CatalogoManager(
              titulo: 'Tipos de Equipo',
              icono: Icons.computer_rounded,
              color: Colors.blueGrey,
              onFetch: api.fetchTiposEquipo,
              onCreate: (nombre) => api.crearTipoEquipo(nombre),
              onUpdate: (id, nombre) => api.actualizarTipoEquipo(id, nombre),
              onDelete: (id) => api.eliminarTipoEquipo(id),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogoManager extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final Color color;
  final Future<List<Map<String, dynamic>>> Function() onFetch;
  final Future<void> Function(String nombre) onCreate;
  final Future<void> Function(int id, String nombre) onUpdate;
  final Future<void> Function(int id) onDelete;

  const _CatalogoManager({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.onFetch,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_CatalogoManager> createState() => _CatalogoManagerState();
}

class _CatalogoManagerState extends State<_CatalogoManager> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _cargando = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = null; });
    try {
      final lista = await widget.onFetch();
      if (mounted) setState(() { _items = lista; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  Future<void> _mostrarDialogo({Map<String, dynamic>? item}) async {
    final ctrl = TextEditingController(text: item?['nombre'] ?? '');
    final esEdicion = item != null;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(esEdicion ? Icons.edit_rounded : Icons.add_circle_rounded, color: widget.color, size: 20),
          const SizedBox(width: 8),
          Text(esEdicion ? 'Editar' : 'Nuevo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nombre',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(widget.icono, size: 18),
            ),
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(esEdicion ? 'Guardar' : 'Agregar'),
          ),
        ],
      ),
    );
    if (result != true || ctrl.text.trim().isEmpty) return;
    try {
      if (esEdicion) {
        await widget.onUpdate(item!['id'] as int, ctrl.text.trim());
      } else {
        await widget.onCreate(ctrl.text.trim());
      }
      _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: Text('¿Eliminar "${item['nombre']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.onDelete(item['id'] as int);
      _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icono, color: widget.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800)),
                      Text('${_items.length} registros', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ]),
                ElevatedButton.icon(
                  onPressed: () => _mostrarDialogo(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Body
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text('Error al cargar', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reintentar'),
          ),
        ]),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icono, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No hay registros.', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Presiona Agregar para añadir el primero.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ]),
      );
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 1,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(widget.icono, color: widget.color, size: 16),
            ),
            title: Text(
              item['nombre']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_rounded, size: 18, color: widget.color),
                  tooltip: 'Editar',
                  onPressed: () => _mostrarDialogo(item: item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                  tooltip: 'Eliminar',
                  onPressed: () => _confirmarEliminar(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
