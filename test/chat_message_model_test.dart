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

  test('respuestaA se parsea desde el map cuando viene presente', () {
    final msg = ChatMessage.fromMap({
      'id': '2',
      'deUsuario': 'jdoe',
      'nombreCompleto': 'John Doe',
      'texto': 'respondiendo',
      'fecha': '2026-07-01T20:32:15.000000',
      'respuestaA': 1,
    });
    expect(msg.respuestaA, 1);

    final sinRespuesta = ChatMessage.fromMap({
      'id': '3',
      'deUsuario': 'jdoe',
      'nombreCompleto': 'John Doe',
      'texto': 'normal',
      'fecha': '2026-07-01T20:32:15.000000',
    });
    expect(sinRespuesta.respuestaA, null);
  });
}
