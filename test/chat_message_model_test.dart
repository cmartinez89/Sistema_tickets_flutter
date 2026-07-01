import 'package:flutter_test/flutter_test.dart';
import 'package:soporte_beta/models/chat_message_model.dart';

void main() {
  test('fecha sin sufijo de zona se interpreta como UTC, no como hora local', () {
    final msg = ChatMessage.fromMap({
      'id': '1',
      'deUsuario': 'jdoe',
      'nombreCompleto': 'John Doe',
      'texto': 'hola',
      'fecha': '2026-07-01T20:32:15.000000',
    });

    final esperado = DateTime.utc(2026, 7, 1, 20, 32, 15).toLocal();
    expect(msg.fecha, esperado);
  });
}
