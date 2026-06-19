import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../models/session_model.dart';

class DashboardScreen extends StatelessWidget {
  final List<Ticket> tickets;
  final List<Equipo> inventario;
  final Session session;
  final void Function(int) onNavigate;

  const DashboardScreen({
    super.key,
    required this.tickets,
    required this.inventario,
    required this.session,
    required this.onNavigate,
  });

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

    final conRespaldo = inventario
        .where((e) => e.ultimoRespaldo != null && DateTime.now().difference(e.ultimoRespaldo!).inDays < 15)
        .length;
    final sinRespaldo = totalEquipos - conRespaldo;

    final recientes = session.rol == 'Admin'
        ? (List<Ticket>.from(tickets)..sort((a, b) => b.fecha.compareTo(a.fecha))).take(5).toList()
        : <Ticket>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int col = 1;
          double cardHeight = 88;
          if (constraints.maxWidth >= 1100) {
            col = 4;
            cardHeight = 132;
          } else if (constraints.maxWidth >= 650) {
            col = 2;
            cardHeight = 120;
          }
          final narrow = col == 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(),
                if (pendientes > 0 || alta > 0 || sinRespaldo > 0) ...[
                  const SizedBox(height: 14),
                  _alertStrip(pendientes: pendientes, alta: alta, sinRespaldo: sinRespaldo),
                ],
                const SizedBox(height: 28),

                _sectionHeader('Tickets de Soporte', Icons.confirmation_number_rounded, Colors.indigo),
                const SizedBox(height: 14),
                _cardGrid(col: col, cardHeight: cardHeight, children: [
                  _cardDonut(titulo: 'Pendientes', numero: '$pendientes', subtitulo: 'de $total tickets', progreso: total > 0 ? pendientes / total : 0, color: Colors.red.shade600, icono: Icons.hourglass_top_rounded, narrow: narrow, onTap: () => onNavigate(1)),
                  _cardDonut(titulo: 'En Proceso', numero: '$enProceso', subtitulo: 'de $total tickets', progreso: total > 0 ? enProceso / total : 0, color: Colors.orange.shade700, icono: Icons.autorenew_rounded, narrow: narrow, onTap: () => onNavigate(1)),
                  _cardDonut(titulo: 'Resueltos', numero: '$resueltos', subtitulo: 'de $total tickets', progreso: total > 0 ? resueltos / total : 0, color: Colors.green.shade600, icono: Icons.check_circle_rounded, narrow: narrow, onTap: () => onNavigate(1)),
                  _cardDonut(titulo: 'Prioridad Alta', numero: '$alta', subtitulo: 'sin resolver', progreso: total > 0 ? alta / total : 0, color: Colors.deepOrange.shade700, icono: Icons.priority_high_rounded, narrow: narrow, onTap: () => onNavigate(1)),
                ]),
                const SizedBox(height: 32),

                _sectionHeader('Inventario de Equipos', Icons.computer_rounded, Colors.teal),
                const SizedBox(height: 14),
                _cardGrid(col: col, cardHeight: cardHeight, children: [
                  _cardDonut(titulo: 'Asignados', numero: '$asignados', subtitulo: 'de $totalEquipos equipos', progreso: totalEquipos > 0 ? asignados / totalEquipos : 0, color: Colors.indigo.shade600, icono: Icons.person_rounded, narrow: narrow, onTap: () => onNavigate(2)),
                  _cardDonut(titulo: 'Disponibles', numero: '$disponibles', subtitulo: 'en almacén', progreso: totalEquipos > 0 ? disponibles / totalEquipos : 0, color: Colors.teal.shade600, icono: Icons.inventory_2_rounded, narrow: narrow, onTap: () => onNavigate(2)),
                  _cardStat(titulo: 'Valor del Inventario', numero: '\$${_formatMiles(valorTotal)}', subtitulo: 'MXN depreciado', color: Colors.blueGrey.shade700, icono: Icons.account_balance_wallet_rounded, narrow: narrow, onTap: () => onNavigate(2)),
                  _cardStat(titulo: 'Total de Equipos', numero: '$totalEquipos', subtitulo: 'registrados', color: Colors.blue.shade700, icono: Icons.devices_rounded, narrow: narrow, onTap: () => onNavigate(2)),
                ]),
                const SizedBox(height: 32),

                _sectionHeader('Estado de Respaldos', Icons.backup_rounded, Colors.purple),
                const SizedBox(height: 14),
                _cardGrid(col: col, cardHeight: cardHeight, children: [
                  _cardDonut(titulo: 'Al día', numero: '$conRespaldo', subtitulo: 'últimos 15 días', progreso: totalEquipos > 0 ? conRespaldo / totalEquipos : 0, color: Colors.green.shade600, icono: Icons.cloud_done_rounded, narrow: narrow, onTap: () => onNavigate(3)),
                  _cardDonut(titulo: 'Atrasados', numero: '$sinRespaldo', subtitulo: '+15 días sin respaldo', progreso: totalEquipos > 0 ? sinRespaldo / totalEquipos : 0, color: Colors.red.shade600, icono: Icons.cloud_off_rounded, narrow: narrow, onTap: () => onNavigate(3)),
                ]),

                if (recientes.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _sectionHeader('Últimos Tickets Registrados', Icons.history_rounded, Colors.blueGrey),
                  const SizedBox(height: 14),
                  _recentTicketsCard(recientes),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerCard() {
    final now = DateTime.now();
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final fecha = '${now.day} ${meses[now.month - 1]} ${now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00796B), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00695C).withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.rol == 'Admin' ? 'Consola de Control Global' : 'Mis Tareas TI',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(session.nombreCompleto, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                Text(fecha, style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(session.rol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _alertStrip({required int pendientes, required int alta, required int sinRespaldo}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (pendientes > 0) _alertChip('$pendientes pendiente${pendientes > 1 ? 's' : ''}', Colors.red.shade600, Icons.hourglass_top_rounded, () => onNavigate(1)),
                if (alta > 0) _alertChip('$alta prioridad alta', Colors.deepOrange.shade700, Icons.priority_high_rounded, () => onNavigate(1)),
                if (sinRespaldo > 0) _alertChip('$sinRespaldo sin respaldo', Colors.amber.shade800, Icons.cloud_off_rounded, () => onNavigate(3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertChip(String label, Color color, IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String titulo, IconData icono, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icono, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(titulo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
      ],
    );
  }

  Widget _cardGrid({required int col, required double cardHeight, required List<Widget> children}) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const spacing = 14.0;
        final itemW = (constraints.maxWidth - spacing * (col - 1)) / col;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((c) => SizedBox(width: itemW, height: cardHeight, child: c)).toList(),
        );
      },
    );
  }

  Widget _cardShell({required Color color, required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        mouseCursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 4, color: color),
                Expanded(
                  child: Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardDonut({
    required String titulo,
    required String numero,
    required String subtitulo,
    required double progreso,
    required Color color,
    required IconData icono,
    required bool narrow,
    VoidCallback? onTap,
  }) {
    return _cardShell(
      onTap: onTap,
      color: color,
      child: narrow
          ? Row(children: [
              _ring(numero, progreso, color, 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Icon(icono, color: color, size: 13),
                      const SizedBox(width: 5),
                      Expanded(child: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 4),
                    Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icono, color: color, size: 13),
                  const SizedBox(width: 5),
                  Expanded(child: Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const Spacer(),
                Center(child: _ring(numero, progreso, color, 52)),
                const SizedBox(height: 6),
                Center(child: Text(subtitulo, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }

  Widget _ring(String numero, double progreso, Color color, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progreso,
            strokeWidth: size > 55 ? 6.5 : 5.5,
            color: color,
            backgroundColor: color.withValues(alpha: 0.13),
          ),
          Text(numero, style: TextStyle(fontSize: size > 55 ? 17 : 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _cardStat({
    required String titulo,
    required String numero,
    required String subtitulo,
    required Color color,
    required IconData icono,
    required bool narrow,
    VoidCallback? onTap,
  }) {
    return _cardShell(
      onTap: onTap,
      color: color,
      child: narrow
          ? Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icono, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(numero, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icono, color: color, size: 13),
                  const SizedBox(width: 5),
                  Expanded(child: Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const Spacer(),
                Text(numero, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitulo, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
    );
  }

  Widget _recentTicketsCard(List<Ticket> recientes) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: recientes.asMap().entries.map((entry) {
            return _ticketRow(entry.value, isLast: entry.key == recientes.length - 1, onTap: () => onNavigate(1));
          }).toList(),
        ),
      ),
    );
  }

  Widget _ticketRow(Ticket t, {required bool isLast, VoidCallback? onTap}) {
    final estadoColor = switch (t.estado) {
      'Pendiente' => Colors.red.shade600,
      'En Proceso' => Colors.orange.shade700,
      'Resuelto' => Colors.green.shade600,
      _ => Colors.grey,
    };
    final prioColor = t.prioridad == 'Alta'
        ? Colors.deepOrange.shade700
        : (t.prioridad == 'Media' ? Colors.amber.shade700 : Colors.grey.shade500);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: estadoColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.confirmation_number_rounded, color: estadoColor, size: 15),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.descripcion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${t.usuario} · ${t.departamento}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusChip(t.estado, estadoColor),
                  const SizedBox(height: 3),
                  Text(t.prioridad, style: TextStyle(fontSize: 10, color: prioColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  String _formatMiles(double valor) {
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(1)}K';
    return valor.toStringAsFixed(0);
  }
}
