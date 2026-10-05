import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/avatar/avatar.dart';
import 'package:pulperia_mobile/ui/avatar/avatar_characters.dart';
import 'package:pulperia_mobile/ui/avatar/hex_color.dart';

const _size = 96;

Future<ByteData> _render(String characterId, Color skin) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  AvatarCharacters.of(characterId).paint(canvas, const Size(96, 96), skin);
  final image = await recorder.endRecording().toImage(_size, _size);
  return (await image.toByteData())!;
}

Color _pixel(ByteData data, int x, int y) {
  final i = (y * _size + x) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const prototypes = ['char-01', 'char-02', 'char-03'];

  test('hexColor lee colores #RRGGBB', () {
    expect(hexColor('#F9DCC4'), const Color(0xFFF9DCC4));
  });

  test('los 3 personajes de prueba existen y llevan su identificador', () {
    for (final id in prototypes) {
      expect(AvatarCharacters.of(id).id, id);
      expect(AvatarCharacters.hasArt(id), isTrue);
    }
  });

  test('un personaje aún sin ilustración usa un marcador, sin fallar', () {
    expect(AvatarCharacters.hasArt('char-24'), isFalse);
    expect(AvatarCharacters.of('char-24').id, 'char-24');
  });

  test('cada personaje pinta su cara con el tono de piel elegido', () async {
    for (final id in prototypes) {
      for (final skin in AvatarPalette.skinTones) {
        final data = await _render(id, hexColor(skin.hex));
        // El centro de la cara no lleva rasgos: es piel pura.
        expect(
          _pixel(data, _size ~/ 2, _size ~/ 2),
          hexColor(skin.hex),
          reason: '$id con ${skin.id}',
        );
      }
    }
  });

  test('los personajes de prueba se distinguen entre sí', () async {
    final skin = hexColor(AvatarPalette.skinTones.first.hex);
    final renders = <List<int>>[
      for (final id in prototypes)
        (await _render(id, skin)).buffer.asUint8List().toList(),
    ];

    expect(renders[0], isNot(renders[1]));
    expect(renders[0], isNot(renders[2]));
    expect(renders[1], isNot(renders[2]));
  });

  test('el fondo queda sin pintar: el personaje no lo cubre', () async {
    final data = await _render('char-01', const Color(0xFFF9DCC4));
    expect(_pixel(data, 0, 0).a, 0);
  });
}
