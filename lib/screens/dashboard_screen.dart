import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../models/session_model.dart';

class DashboardScreen extends StatelessWidget {
  final List<Ticket> tickets;
  final List<Equipo> inventario;
  final Session session;

  const DashboardScreen({
    super.key, 
    required this.tickets, 
    required this.inventario, 
    required this.session,
  });

  Color statusColor(String estado) {
    switch (estado) {
      case 'Pendiente': return Colors.red.shade700;
      case 'En Proceso': return Colors.orange.shade800;
      case 'Resuelto': return Colors.green.shade700;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibles = session.rol == 'Admin'
        ? tickets
        : tickets.where((t) => t.asignadoA.toLowerCase() == session.username.toLowerCase()).toList();

    final total = visibles.length;
    final pendientes = visibles.where((t) => t.estado == 'Pendiente').length;
    final enProceso = visibles.where((t) => t.estado == 'En Proceso').length;
    final resueltos = visibles.where((t) => t.estado == 'Resuelto').length;
    final alta = visibles.where((t) => t.prioridad == 'Alta' && t.estado != 'Resuelto').length;

    final totalEquipos = inventario.length;
    final asignados = inventario.where((e) => e.estatus == 'Asignado').length;
    final disponibles = inventario.where((e) => e.estatus == 'Disponible').length;
    final valorTotal = inventario.fold<double>(0, (s, e) => s + e.valorActual);

    final conRespaldo = inventario.where((e) => e.ultimoRespaldo != null && DateTime.now().difference(e.ultimoRespaldo!).inDays < 15).length;
    final sinRespaldo = totalEquipos - conRespaldo;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculamos el número de columnas y la proporción según el ancho disponible
          int columnas = 1;
          double childAspectRatio = 2.3; // Proporción rectangular ideal para celular (evita que se estire hacia abajo)

          if (constraints.maxWidth >= 1100) {
            columnas = 4; // Laptops o monitores de PC
            childAspectRatio = 1.15;
          } else if (constraints.maxWidth >= 650) {
            columnas = 2; // Tablets o pantallas medianas
            childAspectRatio = 1.3;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.rol == 'Admin' ? 'Consola de Control Global' : 'Mis Tareas TI', 
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                ),
                Text('Resumen general del sistema', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 24),

                // ── SECCIÓN TICKETS ──
                _seccion('Tickets de Soporte', Icons.confirmation_number_rounded, Colors.indigo),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columnas,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _tarjetaDona(titulo: 'Pendientes', numero: '$pendientes', subtitulo: 'de $total tickets', valor: total > 0 ? pendientes / total : 0, colorActivo: Colors.red.shade600, icono: Icons.hourglass_top_rounded, enColumnaUnica: columnas == 1),
                    _tarjetaDona(titulo: 'En Proceso', numero: '$enProceso', subtitulo: 'de $total tickets', valor: total > 0 ? enProceso / total : 0, colorActivo: Colors.orange.shade700, icono: Icons.autorenew_rounded, enColumnaUnica: columnas == 1),
                    _tarjetaDona(titulo: 'Resueltos', numero: '$resueltos', subtitulo: 'de $total tickets', valor: total > 0 ? resueltos / total : 0, colorActivo: Colors.green.shade600, icono: Icons.check_circle_rounded, enColumnaUnica: columnas == 1),
                    _tarjetaDona(titulo: 'Prioridad Alta', numero: '$alta', subtitulo: 'sin resolver', valor: total > 0 ? alta / total : 0, colorActivo: Colors.deepOrange.shade700, icono: Icons.priority_high_rounded, enColumnaUnica: columnas == 1),
                  ],
                ),
                const SizedBox(height: 28),

                // ── SECCIÓN EQUIPOS ──
                _seccion('Inventario de Equipos', Icons.computer_rounded, Colors.teal),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columnas,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _tarjetaDona(titulo: 'Asignados', numero: '$asignados', subtitulo: 'de $totalEquipos equipos', valor: totalEquipos > 0 ? asignados / totalEquipos : 0, colorActivo: Colors.indigo.shade600, icono: Icons.person_rounded, enColumnaUnica: columnas == 1),
                    _tarjetaDona(titulo: 'Disponibles', numero: '$disponibles', subtitulo: 'en almacén', valor: totalEquipos > 0 ? disponibles / totalEquipos : 0, colorActivo: Colors.teal.shade600, icono: Icons.inventory_2_rounded, enColumnaUnica: columnas == 1),
                    _tarjetaKPI(titulo: 'Valor del Inventario', numero: '\$${_formatMiles(valorTotal)}', subtitulo: 'MXN valor depreciado', color: Colors.blueGrey.shade700, icono: Icons.account_balance_wallet_rounded, enColumnaUnica: columnas == 1),
                    _tarjetaKPI(titulo: 'Total de Equipos', numero: '$totalEquipos', subtitulo: 'registrados en sistema', color: Colors.blue.shade700, icono: Icons.devices_rounded, enColumnaUnica: columnas == 1),
                  ],
                ),
                const SizedBox(height: 28),

                // ── SECCIÓN RESPALDOS ──
                _seccion('Estado de Respaldos', Icons.backup_rounded, Colors.purple),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columnas, crossAxisSpacing: 16, mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _tarjetaDona(titulo: 'Al día', numero: '$conRespaldo', subtitulo: 'últimos 15 días', valor: totalEquipos > 0 ? conRespaldo / totalEquipos : 0, colorActivo: Colors.green.shade600, icono: Icons.cloud_done_rounded, enColumnaUnica: columnas == 1),
                    _tarjetaDona(titulo: 'Atrasados', numero: '$sinRespaldo', subtitulo: '+15 días sin respaldo', valor: totalEquipos > 0 ? sinRespaldo / totalEquipos : 0, colorActivo: Colors.red.shade600, icono: Icons.cloud_off_rounded, enColumnaUnica: columnas == 1),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _seccion(String titulo, IconData icono, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6), 
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), 
          child: Icon(icono, color: color, size: 18)
        ),
        const SizedBox(width: 10),
        Text(titulo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _tarjetaDona({required String titulo, required String numero, required String subtitulo, required double valor, required Color colorActivo, required IconData icono, required bool enColumnaUnica}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: enColumnaUnica 
      ? Row( // DISEÑO HORIZONTAL ELEGANTE PARA CELULARES
          children: [
            SizedBox(
              width: 75, height: 75,
              child: Stack(
                alignment: Alignment.center, 
                children: [
                  CircularProgressIndicator(value: valor, strokeWidth: 7, color: colorActivo, backgroundColor: const Color(0xFFE8ECF0)), 
                  Text(numero, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorActivo))
                ]
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [Icon(icono, color: colorActivo, size: 16), const SizedBox(width: 6), Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 4),
                  Text(subtitulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            )
          ],
        )
      : Column( // DISEÑO VERTICAL DE DONA PARA LAPTOPS Y PC
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icono, color: colorActivo, size: 18), 
                const SizedBox(width: 6), 
                Expanded(child: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))
              ]
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: AspectRatio(
                    aspectRatio: 1, 
                    child: Stack(
                      alignment: Alignment.center, 
                      children: [
                        CircularProgressIndicator(value: valor, strokeWidth: 8, color: colorActivo, backgroundColor: const Color(0xFFE8ECF0)), 
                        Text(numero, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorActivo))
                      ]
                    ),
                  ),
                ),
              ),
            ),
            Center(child: Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
    );
  }

  Widget _tarjetaKPI({required String titulo, required String numero, required String subtitulo, required Color color, required IconData icono, required bool enColumnaUnica}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: enColumnaUnica
      ? Row( // DISEÑO HORIZONTAL EN CELULAR PARA TARJETAS CON MÉTRIICAS TEXTUALES
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icono, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(numero, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                  Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            )
          ],
        )
      : Column( // DISEÑO TRADICIONAL EN PC
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icono, color: color, size: 18), 
                const SizedBox(width: 6), 
                Expanded(child: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))
              ]
            ),
            Expanded(
              child: Center(
                child: Text(
                  numero, 
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              ),
            ),
            Center(child: Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
    );
  }

  String _formatMiles(double valor) {
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(1)}K';
    return valor.toStringAsFixed(0);
  }
}