import 'package:flutter/rendering.dart';

/// Un personaje del avatar: un dibujo vectorial hecho en código, sin imágenes
/// externas, con el tono de piel como parámetro (RF-72). Solo pinta al
/// personaje; el fondo lo pone quien lo muestra.
///
/// Todo dibujo se hace en proporción al [Size] recibido, de modo que un mismo
/// personaje sirve para cualquier tamaño. El centro de la cara no lleva
/// rasgos encima, así el tono de piel se ve limpio.
abstract interface class AvatarCharacter {
  /// Identificador de la paleta (`char-01`...).
  String get id;

  void paint(Canvas canvas, Size size, Color skin);
}

/// Los 24 personajes de la paleta (RF-72). Cada uno combina un peinado, un
/// color de pelo, una prenda, un accesorio y un gesto sobre la misma base de
/// cabeza y hombros, de modo que todos se leen bien con cualquier tono de piel
/// y con cualquier fondo.
abstract final class AvatarCharacters {
  static final Map<String, AvatarCharacter> _art = {
    for (final spec in _specs) spec.id: _SpecCharacter(spec),
  };

  /// ¿Tiene ya dibujo este personaje?
  static bool hasArt(String id) => _art.containsKey(id);

  /// El personaje con ese id; si no existe en la paleta, un marcador sencillo
  /// con el mismo tono de piel, para que la app nunca falle por un id
  /// desconocido.
  static AvatarCharacter of(String id) => _art[id] ?? _Placeholder(id);
}

enum _Hair {
  none,
  buzz,
  short,
  sidePart,
  bob,
  long,
  bun,
  ponytail,
  braids,
  curly,
}

enum _Accessory {
  none,
  glassesRound,
  glassesSquare,
  beard,
  mustache,
  headband,
  earrings,
  cap,
  strawHat,
  beanie,
}

enum _Neckline { crew, vNeck, collar }

enum _Mouth { smile, grin, neutral }

class _Spec {
  const _Spec(
    this.id, {
    required this.hair,
    required this.hairColor,
    required this.shirt,
    this.neckline = _Neckline.crew,
    this.accessory = _Accessory.none,
    this.accessoryColor,
    this.mouth = _Mouth.smile,
  });

  final String id;
  final _Hair hair;
  final Color hairColor;
  final Color shirt;
  final _Neckline neckline;
  final _Accessory accessory;

  /// Color de la gorra, el sombrero, la cinta o los aretes; si es null se usa
  /// uno por defecto según el accesorio.
  final Color? accessoryColor;
  final _Mouth mouth;
}

// Colores de pelo.
const _black = Color(0xFF1E1A1A);
const _darkBrown = Color(0xFF4E342E);
const _brown = Color(0xFF795548);
const _auburn = Color(0xFFA1452B);
const _blond = Color(0xFFE2B341);
const _gray = Color(0xFFB0B7BC);

const List<_Spec> _specs = [
  _Spec(
    'char-01',
    hair: _Hair.short,
    hairColor: _darkBrown,
    shirt: Color(0xFF1565C0),
  ),
  _Spec(
    'char-02',
    hair: _Hair.long,
    hairColor: _black,
    shirt: Color(0xFFC62828),
    accessory: _Accessory.earrings,
  ),
  _Spec(
    'char-03',
    hair: _Hair.short,
    hairColor: _blond,
    shirt: Color(0xFF2E7D32),
    accessory: _Accessory.cap,
    accessoryColor: Color(0xFFF9A825),
  ),
  _Spec(
    'char-04',
    hair: _Hair.bun,
    hairColor: _auburn,
    shirt: Color(0xFF6A1B9A),
    neckline: _Neckline.vNeck,
    accessory: _Accessory.glassesRound,
  ),
  _Spec(
    'char-05',
    hair: _Hair.curly,
    hairColor: _black,
    shirt: Color(0xFFEF6C00),
    mouth: _Mouth.grin,
  ),
  _Spec(
    'char-06',
    hair: _Hair.none,
    hairColor: _black,
    shirt: Color(0xFF00695C),
    neckline: _Neckline.collar,
    accessory: _Accessory.beard,
    mouth: _Mouth.neutral,
  ),
  _Spec(
    'char-07',
    hair: _Hair.ponytail,
    hairColor: _brown,
    shirt: Color(0xFFD81B60),
    neckline: _Neckline.vNeck,
    accessory: _Accessory.earrings,
  ),
  _Spec(
    'char-08',
    hair: _Hair.braids,
    hairColor: _black,
    shirt: Color(0xFFFBC02D),
    accessory: _Accessory.headband,
    accessoryColor: Color(0xFFD32F2F),
    mouth: _Mouth.grin,
  ),
  _Spec(
    'char-09',
    hair: _Hair.buzz,
    hairColor: _gray,
    shirt: Color(0xFF283593),
    neckline: _Neckline.collar,
    accessory: _Accessory.glassesSquare,
    mouth: _Mouth.neutral,
  ),
  _Spec(
    'char-10',
    hair: _Hair.bob,
    hairColor: _blond,
    shirt: Color(0xFF00897B),
  ),
  _Spec(
    'char-11',
    hair: _Hair.sidePart,
    hairColor: _auburn,
    shirt: Color(0xFF880E4F),
    neckline: _Neckline.vNeck,
    accessory: _Accessory.mustache,
  ),
  _Spec(
    'char-12',
    hair: _Hair.long,
    hairColor: _gray,
    shirt: Color(0xFF3949AB),
    accessory: _Accessory.glassesRound,
  ),
  _Spec(
    'char-13',
    hair: _Hair.short,
    hairColor: _black,
    shirt: Color(0xFF546E7A),
    neckline: _Neckline.collar,
    accessory: _Accessory.beard,
  ),
  _Spec(
    'char-14',
    hair: _Hair.curly,
    hairColor: _brown,
    shirt: Color(0xFFE53935),
    neckline: _Neckline.vNeck,
    accessory: _Accessory.headband,
    accessoryColor: Color(0xFFFFEB3B),
    mouth: _Mouth.grin,
  ),
  _Spec(
    'char-15',
    hair: _Hair.bun,
    hairColor: _black,
    shirt: Color(0xFF388E3C),
    accessory: _Accessory.earrings,
  ),
  _Spec(
    'char-16',
    hair: _Hair.short,
    hairColor: _brown,
    shirt: Color(0xFF6D4C41),
    neckline: _Neckline.collar,
    accessory: _Accessory.strawHat,
    accessoryColor: Color(0xFFE6C98A),
  ),
  _Spec(
    'char-17',
    hair: _Hair.short,
    hairColor: _blond,
    shirt: Color(0xFF0277BD),
    accessory: _Accessory.beanie,
    accessoryColor: Color(0xFFEF5350),
    mouth: _Mouth.grin,
  ),
  _Spec(
    'char-18',
    hair: _Hair.braids,
    hairColor: _brown,
    shirt: Color(0xFF7B1FA2),
    accessory: _Accessory.glassesSquare,
  ),
  _Spec(
    'char-19',
    hair: _Hair.ponytail,
    hairColor: _black,
    shirt: Color(0xFFF57C00),
    neckline: _Neckline.vNeck,
    mouth: _Mouth.grin,
  ),
  _Spec(
    'char-20',
    hair: _Hair.bob,
    hairColor: _black,
    shirt: Color(0xFF1976D2),
    neckline: _Neckline.collar,
    accessory: _Accessory.glassesRound,
    mouth: _Mouth.neutral,
  ),
  _Spec(
    'char-21',
    hair: _Hair.sidePart,
    hairColor: _blond,
    shirt: Color(0xFF689F38),
    accessory: _Accessory.beard,
  ),
  _Spec(
    'char-22',
    hair: _Hair.curly,
    hairColor: _auburn,
    shirt: Color(0xFFEC407A),
    accessory: _Accessory.earrings,
  ),
  _Spec(
    'char-23',
    hair: _Hair.buzz,
    hairColor: _black,
    shirt: Color(0xFF00ACC1),
    neckline: _Neckline.vNeck,
    accessory: _Accessory.mustache,
    mouth: _Mouth.grin,
  ),
  _Spec(
    'char-24',
    hair: _Hair.long,
    hairColor: _darkBrown,
    shirt: Color(0xFFECEFF1),
    accessory: _Accessory.strawHat,
    accessoryColor: Color(0xFFD7B56D),
  ),
];

/// Dibuja un personaje a partir de su [_Spec], sobre un lienzo de 100×100.
class _SpecCharacter implements AvatarCharacter {
  const _SpecCharacter(this.spec);

  final _Spec spec;

  @override
  String get id => spec.id;

  static const _ink = Color(0xFF263238);

  @override
  void paint(Canvas canvas, Size size, Color skin) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final shade = _shade(skin, 0.09);
    final hair = spec.hairColor;

    _backHair(canvas, hair);
    _torso(canvas, skin, shade);
    _head(canvas, skin, shade);
    _face(canvas, skin, shade);
    _frontHair(canvas, hair);
    _accessory(canvas, skin, hair);

    canvas.restore();
  }

  // --- cuerpo y cabeza ------------------------------------------------------

  void _torso(Canvas canvas, Color skin, Color shade) {
    // Cuello.
    canvas.drawRRect(
      RRect.fromLTRBR(42, 60, 58, 82, const Radius.circular(5)),
      _fill(shade),
    );
    // Hombros y camiseta.
    final body = Path()
      ..moveTo(8, 101)
      ..cubicTo(8, 84, 24, 78, 38, 75)
      ..lineTo(62, 75)
      ..cubicTo(76, 78, 92, 84, 92, 101)
      ..close();
    canvas.drawPath(body, _fill(spec.shirt));

    switch (spec.neckline) {
      case _Neckline.crew:
        canvas.drawOval(const Rect.fromLTRB(40, 70, 60, 82), _fill(shade));
      case _Neckline.vNeck:
        final v = Path()
          ..moveTo(39, 75)
          ..lineTo(61, 75)
          ..lineTo(50, 92)
          ..close();
        canvas.drawPath(v, _fill(shade));
      case _Neckline.collar:
        canvas.drawOval(const Rect.fromLTRB(40, 70, 60, 82), _fill(shade));
        final left = Path()
          ..moveTo(38, 75)
          ..lineTo(50, 86)
          ..lineTo(41, 90)
          ..close();
        final right = Path()
          ..moveTo(62, 75)
          ..lineTo(50, 86)
          ..lineTo(59, 90)
          ..close();
        final collar = _fill(const Color(0xFFFFFFFF));
        canvas.drawPath(left, collar);
        canvas.drawPath(right, collar);
    }
  }

  void _head(Canvas canvas, Color skin, Color shade) {
    // Orejas.
    canvas.drawCircle(const Offset(28, 49), 4.6, _fill(skin));
    canvas.drawCircle(const Offset(72, 49), 4.6, _fill(skin));
    canvas.drawCircle(const Offset(28, 49), 2.2, _fill(shade));
    canvas.drawCircle(const Offset(72, 49), 2.2, _fill(shade));
    // Cara.
    canvas.drawOval(const Rect.fromLTRB(28, 21, 72, 71), _fill(skin));
  }

  void _face(Canvas canvas, Color skin, Color shade) {
    final ink = _fill(_ink);
    // Cejas.
    final brow = _stroke(
      spec.hair == _Hair.none ? _darkBrownBrow : spec.hairColor,
      1.8,
    );
    canvas.drawLine(const Offset(36, 39), const Offset(45, 38), brow);
    canvas.drawLine(const Offset(55, 38), const Offset(64, 39), brow);
    // Ojos.
    canvas.drawOval(const Rect.fromLTRB(38.6, 42.5, 43.4, 49.5), ink);
    canvas.drawOval(const Rect.fromLTRB(56.6, 42.5, 61.4, 49.5), ink);
    final glint = _fill(const Color(0xFFFFFFFF));
    canvas.drawCircle(const Offset(42, 44.2), 1.0, glint);
    canvas.drawCircle(const Offset(60, 44.2), 1.0, glint);
    // Rubor.
    final blush = _fill(const Color(0x33E57373));
    canvas.drawCircle(const Offset(35, 56), 4, blush);
    canvas.drawCircle(const Offset(65, 56), 4, blush);
    // Nariz, siempre por debajo del centro de la cara.
    canvas.drawArc(
      const Rect.fromLTRB(47, 53, 53, 58),
      0.3,
      2.5,
      false,
      _stroke(shade, 1.5),
    );
    // Boca.
    // Con pieles oscuras una boca oscura no se ve: se usa una rosada.
    final mouthColor = skin.computeLuminance() < 0.16
        ? const Color(0xFFF2B8B8)
        : const Color(0xFF8D3B3B);
    switch (spec.mouth) {
      case _Mouth.smile:
        canvas.drawArc(
          const Rect.fromLTRB(42, 56, 58, 68),
          0.35,
          2.45,
          false,
          _stroke(mouthColor, 1.9),
        );
      case _Mouth.grin:
        final grin = Path()
          ..moveTo(41, 61)
          ..cubicTo(44, 71, 56, 71, 59, 61)
          ..close();
        canvas.drawPath(grin, _fill(mouthColor));
        canvas.drawPath(
          Path()
            ..moveTo(43.5, 62)
            ..lineTo(56.5, 62)
            ..cubicTo(55, 65, 45, 65, 43.5, 62)
            ..close(),
          _fill(const Color(0xFFFFFFFF)),
        );
      case _Mouth.neutral:
        canvas.drawLine(
          const Offset(44, 64),
          const Offset(56, 64),
          _stroke(mouthColor, 1.9),
        );
    }
  }

  static const _darkBrownBrow = Color(0xFF4E342E);

  // --- pelo -----------------------------------------------------------------

  /// Lo que va detrás de la cabeza.
  void _backHair(Canvas canvas, Color hair) {
    final paint = _fill(hair);
    switch (spec.hair) {
      case _Hair.long:
        canvas.drawRRect(
          RRect.fromLTRBR(22, 17, 78, 92, const Radius.circular(26)),
          paint,
        );
      case _Hair.bob:
        canvas.drawRRect(
          RRect.fromLTRBR(22, 17, 78, 70, const Radius.circular(24)),
          paint,
        );
      case _Hair.curly:
        for (final c in const [
          Offset(50, 22),
          Offset(36, 26),
          Offset(64, 26),
          Offset(27, 38),
          Offset(73, 38),
          Offset(24, 52),
          Offset(76, 52),
        ]) {
          canvas.drawCircle(c, 12, paint);
        }
      case _Hair.ponytail:
        canvas.drawOval(const Rect.fromLTRB(70, 40, 88, 80), paint);
      case _Hair.braids:
        for (final x in const [26.0, 74.0]) {
          for (var i = 0; i < 4; i++) {
            canvas.drawCircle(Offset(x, 62 + i * 8.0), 4.6, paint);
          }
          canvas.drawCircle(Offset(x, 94), 3, _fill(const Color(0xFFE53935)));
        }
      case _Hair.none ||
          _Hair.buzz ||
          _Hair.short ||
          _Hair.sidePart ||
          _Hair.bun:
        break;
    }
  }

  /// Lo que va sobre la frente y la coronilla.
  void _frontHair(Canvas canvas, Color hair) {
    // Una gorra, un sombrero o un gorro sustituyen al flequillo.
    final covered = const {
      _Accessory.cap,
      _Accessory.strawHat,
      _Accessory.beanie,
    }.contains(spec.accessory);
    final paint = _fill(hair);

    switch (spec.hair) {
      case _Hair.none:
        return;
      case _Hair.buzz:
        if (covered) return;
        canvas.drawPath(
          Path()
            ..moveTo(28, 44)
            ..cubicTo(24, 8, 76, 8, 72, 44)
            ..cubicTo(68, 32, 60, 28, 50, 28)
            ..cubicTo(40, 28, 32, 32, 28, 44)
            ..close(),
          _fill(Color.lerp(hair, const Color(0xFFFFFFFF), 0.12)!),
        );
      case _Hair.curly:
        if (covered) return;
        canvas.drawPath(
          Path()
            ..moveTo(27, 46)
            ..cubicTo(22, 8, 78, 8, 73, 46)
            ..cubicTo(68, 34, 60, 30, 50, 30)
            ..cubicTo(40, 30, 32, 34, 27, 46)
            ..close(),
          paint,
        );
      case _Hair.sidePart || _Hair.bob:
        if (covered) return;
        canvas.drawPath(
          Path()
            ..moveTo(27, 50)
            ..cubicTo(21, 6, 79, 6, 73, 50)
            ..cubicTo(70, 38, 60, 27, 44, 33)
            ..cubicTo(34, 36, 29, 43, 27, 50)
            ..close(),
          paint,
        );
      case _Hair.short ||
          _Hair.long ||
          _Hair.ponytail ||
          _Hair.braids ||
          _Hair.bun:
        if (!covered) {
          canvas.drawPath(
            Path()
              ..moveTo(27, 50)
              ..cubicTo(21, 6, 79, 6, 73, 50)
              ..cubicTo(70, 38, 64, 33, 50, 32)
              ..cubicTo(36, 33, 30, 38, 27, 50)
              ..close(),
            paint,
          );
        }
        if (spec.hair == _Hair.bun) {
          canvas.drawCircle(const Offset(50, 14), 9, paint);
        }
        if (spec.hair == _Hair.ponytail) {
          canvas.drawCircle(
            const Offset(72, 40),
            3,
            _fill(const Color(0xFFE53935)),
          );
        }
    }
  }

  // --- accesorios -----------------------------------------------------------

  void _accessory(Canvas canvas, Color skin, Color hair) {
    final color = spec.accessoryColor;
    switch (spec.accessory) {
      case _Accessory.none:
        break;
      case _Accessory.glassesRound:
        final p = _stroke(_ink, 1.7);
        canvas.drawCircle(const Offset(41, 46), 7.2, p);
        canvas.drawCircle(const Offset(59, 46), 7.2, p);
        canvas.drawLine(const Offset(48, 45), const Offset(52, 45), p);
      case _Accessory.glassesSquare:
        final p = _stroke(_ink, 1.7);
        canvas.drawRRect(
          RRect.fromLTRBR(33, 41, 47.5, 51.5, const Radius.circular(3)),
          p,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(52.5, 41, 67, 51.5, const Radius.circular(3)),
          p,
        );
        canvas.drawLine(const Offset(47.5, 45), const Offset(52.5, 45), p);
      case _Accessory.beard:
        canvas.drawPath(
          Path()
            ..moveTo(29, 52)
            ..cubicTo(26, 90, 74, 90, 71, 52)
            ..lineTo(66, 58)
            ..cubicTo(60, 54, 40, 54, 34, 58)
            ..close(),
          _fill(hair),
        );
        // La boca se vuelve a pintar encima de la barba.
        canvas.drawArc(
          const Rect.fromLTRB(43, 59, 57, 70),
          0.35,
          2.45,
          false,
          _stroke(const Color(0xFFE8A0A0), 1.8),
        );
      case _Accessory.mustache:
        final path = Path()
          ..moveTo(50, 58.5)
          ..cubicTo(46, 54, 40, 56, 38, 60)
          ..cubicTo(43, 59, 46, 61, 50, 60.5)
          ..cubicTo(54, 61, 57, 59, 62, 60)
          ..cubicTo(60, 56, 54, 54, 50, 58.5)
          ..close();
        canvas.drawPath(path, _fill(hair));
      case _Accessory.headband:
        canvas.drawPath(
          Path()
            ..moveTo(28, 36)
            ..cubicTo(36, 28, 64, 28, 72, 36)
            ..lineTo(72, 41)
            ..cubicTo(64, 33, 36, 33, 28, 41)
            ..close(),
          _fill(color ?? const Color(0xFFD32F2F)),
        );
      case _Accessory.earrings:
        final gold = _fill(color ?? const Color(0xFFF9A825));
        canvas.drawCircle(const Offset(27, 57), 2.4, gold);
        canvas.drawCircle(const Offset(73, 57), 2.4, gold);
      case _Accessory.cap:
        final c = _fill(color ?? const Color(0xFFF9A825));
        canvas.drawPath(
          Path()
            ..moveTo(26, 40)
            ..cubicTo(24, 2, 76, 2, 74, 40)
            ..close(),
          c,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(44, 34, 90, 42, const Radius.circular(4)),
          _fill(_shade(color ?? const Color(0xFFF9A825), 0.12)),
        );
      case _Accessory.strawHat:
        final hat = color ?? const Color(0xFFE6C98A);
        canvas.drawPath(
          Path()
            ..moveTo(30, 34)
            ..cubicTo(30, 6, 70, 6, 70, 34)
            ..close(),
          _fill(hat),
        );
        canvas.drawRect(
          const Rect.fromLTRB(30, 26, 70, 32),
          _fill(const Color(0xFF8D6E63)),
        );
        canvas.drawOval(
          const Rect.fromLTRB(10, 28, 90, 42),
          _fill(_shade(hat, 0.05)),
        );
      case _Accessory.beanie:
        final c = color ?? const Color(0xFFEF5350);
        canvas.drawPath(
          Path()
            ..moveTo(27, 38)
            ..cubicTo(24, 0, 76, 0, 73, 38)
            ..close(),
          _fill(c),
        );
        canvas.drawRRect(
          RRect.fromLTRBR(26, 32, 74, 41, const Radius.circular(4)),
          _fill(_shade(c, 0.12)),
        );
        canvas.drawCircle(const Offset(50, 6), 4.5, _fill(_shade(c, 0.12)));
    }
  }
}

Paint _fill(Color color) => Paint()..color = color;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round;

/// El mismo color, algo más oscuro: sombra del cuello, de las orejas y de la
/// nariz.
Color _shade(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Cabeza y hombros lisos, para un id que no está en la paleta.
class _Placeholder implements AvatarCharacter {
  const _Placeholder(this.id);

  @override
  final String id;

  @override
  void paint(Canvas canvas, Size size, Color skin) {
    final w = size.width;
    final h = size.height;
    canvas.drawOval(
      Rect.fromLTWH(w * 0.12, h * 0.78, w * 0.76, h * 0.5),
      _fill(const Color(0xFF90A4AE)),
    );
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.3, _fill(skin));
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
