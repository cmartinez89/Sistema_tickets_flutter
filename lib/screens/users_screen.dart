import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../services/api_service.dart';

class UsersScreen extends StatefulWidget {
  final List<Usuario> usuarios;
  final ApiService api;
  final VoidCallback onRefresh;

  const UsersScreen({
    super.key,
    required this.usuarios,
    required this.api,
    required this.onRefresh,
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  // ── Dialogo alta/edición ───────────────────────────────────────────────────

  void _abrirDialogo({Usuario? editar}) {
    final nombreCtrl = TextEditingController(text: editar?.nombreCompleto ?? '');
    final usernameCtrl = TextEditingController(text: editar?.username ?? '');
    final emailCtrl = TextEditingController(text: editar?.email ?? '');
    final passCtrl = TextEditingController();
    String rol = editar?.rol ?? 'Técnico';
    bool guardando = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(editar == null ? 'Nuevo usuario' : 'Editar usuario'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre completo', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: usernameCtrl,
                    enabled: editar == null,
                    decoration: InputDecoration(
                      labelText: 'Nombre de usuario',
                      border: const OutlineInputBorder(),
                      helperText: editar == null ? 'Ej: jperez (sin espacios, minúsculas)' : null,
                      filled: editar != null,
                      fillColor: editar != null ? Colors.grey.shade100 : null,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (v.contains(' ')) return 'Sin espacios';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: rol,
                    decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'Técnico', child: Text('Técnico')),
                      DropdownMenuItem(value: 'Técnico Sr.', child: Text('Técnico Sr.')),
                      DropdownMenuItem(value: 'Desarrollador Sr.', child: Text('Desarrollador Sr.')),
                      DropdownMenuItem(value: 'Desarrollador', child: Text('Desarrollador')),
                    ],
                    onChanged: (v) => setLocal(() => rol = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: editar == null ? 'Contraseña' : 'Nueva contraseña (opcional)',
                      border: const OutlineInputBorder(),
                      helperText: editar != null ? 'Deja en blanco para no cambiar' : null,
                    ),
                    validator: editar == null
                        ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: guardando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setLocal(() => guardando = true);
                      try {
                        if (editar == null) {
                          await widget.api.crearUsuario(
                            username: usernameCtrl.text.trim().toLowerCase(),
                            email: emailCtrl.text.trim().toLowerCase(),
                            nombreCompleto: nombreCtrl.text.trim(),
                            rol: rol,
                            password: passCtrl.text.trim(),
                          );
                        } else {
                          await widget.api.actualizarUsuario(
                            username: editar.username,
                            nombreCompleto: nombreCtrl.text.trim(),
                            email: emailCtrl.text.trim().toLowerCase(),
                            rol: rol,
                            password: passCtrl.text.trim().isEmpty ? null : passCtrl.text.trim(),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        widget.onRefresh();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setLocal(() => guardando = false);
                      }
                    },
              child: guardando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(editar == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(Usuario u) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a ${u.nombreCompleto}? Esta acción no se puede deshacer.'),
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
    if (confirmar == true && mounted) {
      try {
        await widget.api.eliminarUsuario(u.username);
        widget.onRefresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Text(
                  'Gestión de Usuarios',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _abrirDialogo(),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Nuevo usuario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: widget.usuarios.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group_off_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No hay usuarios registrados', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${widget.usuarios.length} usuario${widget.usuarios.length != 1 ? 's' : ''} registrados',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                      ...widget.usuarios.map((u) => _TarjetaUsuario(
                            usuario: u,
                            primary: primary,
                            onEditar: () => _abrirDialogo(editar: u),
                            onEliminar: () => _confirmarEliminar(u),
                          )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta usuario ──────────────────────────────────────────────────────────

class _TarjetaUsuario extends StatelessWidget {
  final Usuario usuario;
  final Color primary;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _TarjetaUsuario({
    required this.usuario,
    required this.primary,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final esAdmin = usuario.rol == 'Admin';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: primary.withValues(alpha: 0.12),
              child: Text(
                usuario.inicial,
                style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(usuario.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: esAdmin ? primary.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          usuario.rol,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: esAdmin ? primary : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${usuario.username}  ·  ${usuario.email}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              tooltip: 'Editar',
              onPressed: onEditar,
              color: Colors.grey.shade600,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: 'Eliminar',
              onPressed: onEliminar,
              color: Colors.red.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
