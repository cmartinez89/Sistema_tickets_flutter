import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/session_model.dart';

class AiScreen extends StatefulWidget {
  final ApiService api;
  final Session session;

  const AiScreen({super.key, required this.api, required this.session});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Asistente tab
  final _preguntaCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _mensajes = [];
  bool _consultando = false;

  // Anomalías tab
  Map<String, dynamic>? _resultAnomalias;
  bool _cargandoAnomalias = false;
  String? _errorAnomalias;

  static const _sugerencias = [
    '¿Cuántos tickets pendientes hay?',
    '¿Qué técnico tiene más carga de trabajo?',
    '¿Qué equipos no tienen respaldo reciente?',
    '¿Cuál es el área con más incidencias?',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _preguntaCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarPregunta() async {
    final pregunta = _preguntaCtrl.text.trim();
    if (pregunta.isEmpty || _consultando) return;
    setState(() {
      _mensajes.add(_ChatMsg(texto: pregunta, esUsuario: true));
      _consultando = true;
    });
    _preguntaCtrl.clear();
    _scrollToBottom();
    try {
      final respuesta = await widget.api.fetchAiConsulta(pregunta);
      if (mounted) {
        setState(() {
          _mensajes.add(_ChatMsg(texto: respuesta, esUsuario: false));
          _consultando = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajes.add(_ChatMsg(texto: 'Error: $e', esUsuario: false, esError: true));
          _consultando = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _cargarAnomalias() async {
    setState(() {
      _cargandoAnomalias = true;
      _errorAnomalias = null;
    });
    try {
      final result = await widget.api.fetchAiAnomalias();
      if (mounted) {
        setState(() {
          _resultAnomalias = result;
          _cargandoAnomalias = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorAnomalias = e.toString();
          _cargandoAnomalias = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Material(
          color: primary.withValues(alpha: 0.08),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primary,
            tabs: const [
              Tab(icon: Icon(Icons.smart_toy_rounded), text: 'Asistente IA'),
              Tab(icon: Icon(Icons.radar_rounded), text: 'Anomalías'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildAsistente(), _buildAnomalias()],
          ),
        ),
      ],
    );
  }

  Widget _buildAsistente() {
    return Column(
      children: [
        if (_mensajes.isEmpty)
          Expanded(child: _buildAsistenteVacio())
        else
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(14),
              itemCount: _mensajes.length + (_consultando ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _mensajes.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      SizedBox(width: 8),
                      SizedBox(width: 60, child: LinearProgressIndicator()),
                    ]),
                  );
                }
                return _buildBurbuja(_mensajes[i]);
              },
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _preguntaCtrl,
                  enabled: !_consultando,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu pregunta...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _enviarPregunta(),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: 'fab_ai_send',
                onPressed: _consultando ? null : _enviarPregunta,
                tooltip: 'Enviar',
                child: _consultando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAsistenteVacio() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Asistente IA de Soporte',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(
              'Pregunta sobre tickets, equipos, estadísticas\no cualquier aspecto del sistema.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _sugerencias.map((q) => ActionChip(
                avatar: const Icon(Icons.bolt_rounded, size: 14),
                label: Text(q, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  _preguntaCtrl.text = q;
                  _enviarPregunta();
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBurbuja(_ChatMsg msg) {
    final primary = Theme.of(context).colorScheme.primary;
    final isUser = msg.esUsuario;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? primary
              : msg.esError ? Colors.red.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: msg.esError ? Border.all(color: Colors.red.shade200) : null,
        ),
        child: SelectableText(
          msg.texto,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : msg.esError ? Colors.red.shade700 : Colors.black87,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAnomalias() {
    if (_cargandoAnomalias) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analizando datos del sistema...'),
            SizedBox(height: 4),
            Text('Esto puede tardar unos segundos',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    if (_errorAnomalias != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 52, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text('Error al analizar', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(_errorAnomalias!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _cargarAnomalias,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_resultAnomalias == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radar_rounded, size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Detección de Anomalías',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Text(
                'Claude analizará tickets, equipos y tiempos de resolución\npara identificar patrones y situaciones de riesgo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _cargarAnomalias,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Analizar sistema ahora'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ],
          ),
        ),
      );
    }

    final anomalias = (_resultAnomalias!['anomalias'] as List?) ?? [];
    final resumen = _resultAnomalias!['resumen'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.summarize_rounded, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Resumen ejecutivo',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700, fontSize: 13)),
                      const SizedBox(height: 4),
                      SelectableText(resumen, style: TextStyle(color: Colors.blue.shade900, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (anomalias.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.check_circle_rounded, size: 52, color: Colors.green.shade400),
                  const SizedBox(height: 10),
                  const Text('Sin anomalías significativas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${anomalias.length} anomalía${anomalias.length == 1 ? '' : 's'} detectada${anomalias.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          ...anomalias.map<Widget>((a) => _buildAnomaliaCard(a as Map<String, dynamic>)),
        ],
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: _cargarAnomalias,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reanálisis'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAnomaliaCard(Map<String, dynamic> a) {
    final sev = a['severidad'] as String? ?? 'baja';
    final Color sevColor;
    final Color sevBg;
    final IconData sevIcon;
    switch (sev) {
      case 'alta':
        sevColor = Colors.red.shade700;
        sevBg = Colors.red.shade50;
        sevIcon = Icons.warning_rounded;
        break;
      case 'media':
        sevColor = Colors.orange.shade700;
        sevBg = Colors.orange.shade50;
        sevIcon = Icons.info_rounded;
        break;
      default:
        sevColor = Colors.blue.shade700;
        sevBg = Colors.blue.shade50;
        sevIcon = Icons.lightbulb_outline_rounded;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: sevColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: sevBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sevIcon, size: 12, color: sevColor),
                      const SizedBox(width: 4),
                      Text(sev.toUpperCase(),
                          style: TextStyle(color: sevColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(a['titulo'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(a['descripcion'] as String? ?? '', style: const TextStyle(fontSize: 13)),
            if ((a['recomendacion'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_rounded, size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(a['recomendacion'] as String,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatMsg {
  final String texto;
  final bool esUsuario;
  final bool esError;
  const _ChatMsg({required this.texto, required this.esUsuario, this.esError = false});
}
