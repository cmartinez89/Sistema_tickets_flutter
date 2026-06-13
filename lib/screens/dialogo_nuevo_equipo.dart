import 'package:flutter/material.dart';
import '../models/equipo_model.dart';
import '../services/api_service.dart';

void abrirDialogoNuevoEquipo({
  required BuildContext context,
  required ApiService api,
  required VoidCallback onRefresh,
}) {
  final formKey = GlobalKey<FormState>();
  final tipoCtrl = TextEditingController(text: 'Laptop');
  final marcaCtrl = TextEditingController();
  final modeloCtrl = TextEditingController();
  final noSerieCtrl = TextEditingController();
  final accesoriosCtrl = TextEditingController();
  final anoCtrl = TextEditingController(text: DateTime.now().year.toString());
  final valorCtrl = TextEditingController(text: '0');
  final specsCtrl = TextEditingController();
  final ubicacionCtrl = TextEditingController(text: 'Beta');
  final anydeskCtrl = TextEditingController();
  final rustdeskCtrl = TextEditingController();
  final comentariosCtrl = TextEditingController();

  bool guardando = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDs) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.computer_rounded, color: Color(0xFF00695C)),
            SizedBox(width: 8),
            Text('Dar de Alta Equipo Nuevo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: tipoCtrl.text,
                    decoration: const InputDecoration(labelText: 'Tipo de Equipo', border: OutlineInputBorder()),
                    items: ['Laptop', 'Desktop', 'Servidor'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => tipoCtrl.text = v!,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: marcaCtrl,
                          decoration: const InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: modeloCtrl,
                          decoration: const InputDecoration(labelText: 'Modelo', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noSerieCtrl,
                    decoration: const InputDecoration(labelText: 'Número de Serie', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: specsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Especificaciones', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: accesoriosCtrl,
                    decoration: const InputDecoration(labelText: 'Accesorios', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: anoCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Año Adquisición', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: valorCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Valor Compra (MXN)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: anydeskCtrl,
                          decoration: const InputDecoration(labelText: 'AnyDesk ID', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: rustdeskCtrl,
                          decoration: const InputDecoration(labelText: 'RustDesk ID', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ubicacionCtrl,
                    decoration: const InputDecoration(labelText: 'Ubicación Inicial', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: comentariosCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Comentarios adicionales', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C), foregroundColor: Colors.white),
            onPressed: guardando ? null : () async {
              if (!formKey.currentState!.validate()) return;
              setDs(() => guardando = true);

              final nuevoEq = Equipo(
                id: '',
                folioResponsiva: '---',
                tipo: tipoCtrl.text,
                marca: marcaCtrl.text.trim(),
                modelo: modeloCtrl.text.trim(),
                noSerie: noSerieCtrl.text.trim(),
                accesorios: accesoriosCtrl.text.trim(),
                anoAdquisicion: int.tryParse(anoCtrl.text) ?? DateTime.now().year,
                valorAdquisicion: double.tryParse(valorCtrl.text) ?? 0.0,
                specifications: specsCtrl.text.trim(),
                estatus: 'Disponible',
                ubicacion: ubicacionCtrl.text.trim().isEmpty ? 'Beta' : ubicacionCtrl.text.trim(),
                anydesk: anydeskCtrl.text.trim(),
                rustdesk: rustdeskCtrl.text.trim(),
                comentarios: comentariosCtrl.text.trim(),
              );

              try {
                await api.crearEquipo(nuevoEq);
                if (ctx.mounted) Navigator.pop(ctx);
                onRefresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al registrar activo: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              } finally {
                setDs(() => guardando = false);
              }
            },
            child: guardando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Guardar Equipo'),
          ),
        ],
      ),
    ),
  );
}