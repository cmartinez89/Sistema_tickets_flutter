import 'dart:js_interop';
import 'package:web/web.dart' as web;

void printHtml(String html) {
  final ventana = web.window.open('', '_blank', 'width=850,height=700,scrollbars=yes');
  if (ventana == null) return;
  ventana.document.write(html.toJS);
  ventana.document.close();
}
