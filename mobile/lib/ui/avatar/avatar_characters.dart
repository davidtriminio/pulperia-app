import 'package:flutter/rendering.dart';

/// Un personaje del avatar: un dibujo vectorial hecho en código, sin imágenes
/// externas, con el tono de piel como parámetro (RF-72). Solo pinta al
/// personaje; el fondo lo pone quien lo muestra.
///
/// Todo dibujo se hace en proporción al [Size] recibido, de modo que un mismo
/// personaje sirve para cualquier tamaño. La cara ocupa el centro sin rasgos
/// encima, así el tono de piel se ve limpio.
abstract interface class AvatarCharacter {
  /// Identificador de la paleta (`char-01`...).
  String get id;

  void paint(Canvas canvas, Size size, Color skin);
}

/// Los personajes disponibles. Hay 3 de prueba (T102); los 24 finales llegan
/// con T103.
abstract final class AvatarCharacters {
  static final Map<String, AvatarCharacter> _art = {
    for (final c in const [_ShortHair(), _LongHair(), _Cap()]) c.id: c,
  };

  /// ¿Tiene ya ilustración este personaje?
  static bool hasArt(String id) => _art.containsKey(id);

  /// El personaje con ese id; si aún no tiene ilustración, un marcador sencillo
  /// con el mismo tono de piel, para que la app nunca falle por falta de arte.
  static AvatarCharacter of(String id) => _art[id] ?? _Placeholder(id);
}

Paint _fill(Color color) => Paint()..color = color;

/// Cuerpo y cara comunes: hombros abajo y una cara redonda al centro.
void _paintBodyAndFace(Canvas canvas, Size size, Color skin, Color shirt) {
  final w = size.width;
  final h = size.height;
  canvas.drawOval(
    Rect.fromLTWH(w * 0.12, h * 0.78, w * 0.76, h * 0.5),
    _fill(shirt),
  );
  canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.3, _fill(skin));
}

void _paintEyes(Canvas canvas, Size size) {
  final w = size.width;
  final h = size.height;
  final eye = _fill(const Color(0xFF263238));
  canvas.drawCircle(Offset(w * 0.4, h * 0.42), w * 0.035, eye);
  canvas.drawCircle(Offset(w * 0.6, h * 0.42), w * 0.035, eye);
  canvas.drawArc(
    Rect.fromLTWH(w * 0.42, h * 0.55, w * 0.16, h * 0.1),
    0.2,
    2.7,
    false,
    Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round,
  );
}

class _ShortHair implements AvatarCharacter {
  const _ShortHair();

  @override
  String get id => 'char-01';

  @override
  void paint(Canvas canvas, Size size, Color skin) {
    final w = size.width;
    final h = size.height;
    _paintBodyAndFace(canvas, size, skin, const Color(0xFF1565C0));
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.32),
      3.14,
      3.14,
      true,
      _fill(const Color(0xFF4E342E)),
    );
    _paintEyes(canvas, size);
  }
}

class _LongHair implements AvatarCharacter {
  const _LongHair();

  @override
  String get id => 'char-02';

  @override
  void paint(Canvas canvas, Size size, Color skin) {
    final w = size.width;
    final h = size.height;
    final hair = _fill(const Color(0xFF212121));
    // El pelo largo va detrás de la cara.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.18, w * 0.68, h * 0.62),
        Radius.circular(w * 0.3),
      ),
      hair,
    );
    _paintBodyAndFace(canvas, size, skin, const Color(0xFFC62828));
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.31),
      3.4,
      2.6,
      true,
      hair,
    );
    _paintEyes(canvas, size);
  }
}

class _Cap implements AvatarCharacter {
  const _Cap();

  @override
  String get id => 'char-03';

  @override
  void paint(Canvas canvas, Size size, Color skin) {
    final w = size.width;
    final h = size.height;
    _paintBodyAndFace(canvas, size, skin, const Color(0xFF2E7D32));
    final cap = _fill(const Color(0xFFF9A825));
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.31),
      3.14,
      3.14,
      true,
      cap,
    );
    // Visera.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.5, h * 0.3, w * 0.38, h * 0.07),
        Radius.circular(w * 0.03),
      ),
      cap,
    );
    _paintEyes(canvas, size);
  }
}

/// Cabeza y hombros lisos, para los personajes que aún no tienen dibujo.
class _Placeholder implements AvatarCharacter {
  const _Placeholder(this.id);

  @override
  final String id;

  @override
  void paint(Canvas canvas, Size size, Color skin) {
    _paintBodyAndFace(canvas, size, skin, const Color(0xFF90A4AE));
  }
}

/// Pinta un [AvatarCharacter] dentro de un `CustomPaint`.
class AvatarCharacterPainter extends CustomPainter {
  const AvatarCharacterPainter(this.character, this.skin);

  final AvatarCharacter character;
  final Color skin;

  @override
  void paint(Canvas canvas, Size size) => character.paint(canvas, size, skin);

  @override
  bool shouldRepaint(AvatarCharacterPainter old) =>
      old.character.id != character.id || old.skin != skin;
}
