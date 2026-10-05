import 'dart:convert';
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
  final allCharacters = AvatarPalette.characterIds;

  test('hexColor lee colores #RRGGBB', () {
    expect(hexColor('#F9DCC4'), const Color(0xFFF9DCC4));
  });

  test('cada uno de los 24 personajes de la paleta tiene su dibujo', () {
    for (final id in allCharacters) {
      expect(AvatarCharacters.of(id).id, id);
      expect(AvatarCharacters.hasArt(id), isTrue);
    }
  });

  test('un id fuera de la paleta usa un marcador, sin fallar', () {
    expect(AvatarCharacters.hasArt('char-99'), isFalse);
    expect(AvatarCharacters.of('char-99').id, 'char-99');
  });

  test('cada personaje pinta su cara con el tono de piel elegido', () async {
    for (final id in allCharacters) {
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

  test('los 24 personajes se distinguen entre sí', () async {
    final skin = hexColor(AvatarPalette.skinTones.first.hex);
    final renders = <String>{};
    for (final id in allCharacters) {
      final bytes = (await _render(id, skin)).buffer.asUint8List();
      renders.add(base64.encode(bytes));
    }

    expect(renders, hasLength(24));
  });

  test(
    'el fondo queda sin pintar: ningún personaje cubre la esquina',
    () async {
      for (final id in allCharacters) {
        final data = await _render(id, const Color(0xFFF9DCC4));
        expect(_pixel(data, 0, 0).a, 0, reason: id);
      }
    },
  );

  test('cada personaje dibuja algo más que la cara', () async {
    final skin = hexColor(AvatarPalette.skinTones.first.hex);
    for (final id in allCharacters) {
      final data = await _render(id, skin);
      var other = 0;
      for (var y = 0; y < _size; y++) {
        for (var x = 0; x < _size; x++) {
          final p = _pixel(data, x, y);
          if (p.a > 0 && p != skin) {
            other++;
          }
        }
      }
      // Pelo, ropa y rasgos ocupan una parte apreciable del dibujo.
      expect(other, greaterThan(_size * _size ~/ 5), reason: id);
    }
  });
}
