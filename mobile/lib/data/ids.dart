import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

/// Forma de los generadores de ids que reciben los repositorios (D-21).
typedef IdGenerator = String Function();

const _uuid = Uuid();
int _lastMillis = 0;

/// Id nuevo: UUID v7 (RFC 9562) en minúsculas. Ordenable por tiempo, lo que
/// favorece los índices de PostgreSQL. Es el único generador de ids de la app;
/// los repositorios lo reciben por inyección y los tests usan uno
/// determinista.
///
/// El paquete `uuid` no garantiza el orden dentro del mismo milisegundo, así
/// que el tiempo nunca retrocede ni se repite: si el reloj no avanzó (o
/// retrocedió), se usa el milisegundo siguiente al último emitido (RFC 9562,
/// §6.2). Los bits aleatorios los sigue poniendo el paquete.
String newId() {
  final now = DateTime.timestamp().millisecondsSinceEpoch;
  _lastMillis = now > _lastMillis ? now : _lastMillis + 1;
  return _uuid.v7(config: V7Options(_lastMillis, null)).toLowerCase();
}
