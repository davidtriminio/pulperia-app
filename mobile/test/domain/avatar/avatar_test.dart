import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/avatar/avatar.dart';

List<(AvatarComponent, String)> issuesOf(AvatarValidationResult result) =>
    switch (result) {
      ValidAvatar() => const [],
      InvalidAvatar(:final issues) => [
        for (final i in issues) (i.component, i.code),
      ],
    };

void main() {
  final shared = jsonDecode(
    File('../shared/vectors/avatar-palette.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group(
    'la paleta del móvil coincide con la compartida en shared/ (RF-72)',
    () {
      test('personajes', () {
        final expected = [
          for (final c in shared['characters'] as List<dynamic>)
            (c as Map)['id'],
        ];

        expect(AvatarPalette.characterIds, expected);
      });

      test('tonos de piel, con su color', () {
        final expected = [
          for (final s in shared['skinTones'] as List<dynamic>)
            ((s as Map)['id'] as String, s['hex'] as String),
        ];

        expect([
          for (final s in AvatarPalette.skinTones) (s.id, s.hex),
        ], expected);
      });

      test('fondos, con su color', () {
        final expected = [
          for (final b in shared['backgrounds'] as List<dynamic>)
            ((b as Map)['id'] as String, b['hex'] as String),
        ];

        expect([
          for (final b in AvatarPalette.backgrounds) (b.id, b.hex),
        ], expected);
      });

      test('hay 24 personajes, 6 tonos y 12 fondos: 1728 combinaciones', () {
        expect(AvatarPalette.characterIds.length, 24);
        expect(AvatarPalette.skinTones.length, 6);
        expect(AvatarPalette.backgrounds.length, 12);
        expect(AvatarPalette.combinationCount, 1728);
      });
    },
  );

  group('validateAvatar con identificadores de la paleta (RF-14, RF-72)', () {
    test('una combinación válida se acepta y se conserva', () {
      final result = validateAvatar(
        characterId: 'char-07',
        skinId: 'skin-3',
        backgroundId: 'bg-12',
      );

      final avatar = (result as ValidAvatar).avatar;
      expect(avatar.characterId, 'char-07');
      expect(avatar.skinId, 'skin-3');
      expect(avatar.backgroundId, 'bg-12');
    });

    test('las 1728 combinaciones son válidas', () {
      var count = 0;
      for (final character in AvatarPalette.characterIds) {
        for (final skin in AvatarPalette.skinTones) {
          for (final background in AvatarPalette.backgrounds) {
            final result = validateAvatar(
              characterId: character,
              skinId: skin.id,
              backgroundId: background.id,
            );

            expect(
              result,
              isA<ValidAvatar>(),
              reason: '$character ${skin.id} ${background.id}',
            );
            count++;
          }
        }
      }

      expect(count, 1728);
    });

    test('los extremos de la paleta se aceptan', () {
      expect(
        validateAvatar(
          characterId: 'char-01',
          skinId: 'skin-1',
          backgroundId: 'bg-01',
        ),
        isA<ValidAvatar>(),
      );
      expect(
        validateAvatar(
          characterId: 'char-24',
          skinId: 'skin-6',
          backgroundId: 'bg-12',
        ),
        isA<ValidAvatar>(),
      );
    });
  });

  group('validateAvatar rechaza lo que falta o está fuera de la paleta', () {
    test('sin nada elegido, indica qué falta (RF-16)', () {
      final result = validateAvatar(
        characterId: null,
        skinId: null,
        backgroundId: null,
      );

      expect(issuesOf(result), [
        (AvatarComponent.character, 'avatar_character_required'),
        (AvatarComponent.skin, 'avatar_skin_required'),
        (AvatarComponent.background, 'avatar_background_required'),
      ]);
    });

    test('un identificador vacío cuenta como no elegido', () {
      final result = validateAvatar(
        characterId: '',
        skinId: 'skin-1',
        backgroundId: 'bg-01',
      );

      expect(issuesOf(result), [
        (AvatarComponent.character, 'avatar_character_required'),
      ]);
    });

    test('personajes fuera de la paleta', () {
      for (final id in [
        'char-00',
        'char-25',
        'char-1',
        'char-001',
        'CHAR-01',
        ' char-01',
        'char-01 ',
        'skin-1',
        'x',
      ]) {
        final result = validateAvatar(
          characterId: id,
          skinId: 'skin-1',
          backgroundId: 'bg-01',
        );

        expect(issuesOf(result), [
          (AvatarComponent.character, 'avatar_character_unknown'),
        ], reason: id);
      }
    });

    test('tonos de piel fuera de la paleta', () {
      for (final id in [
        'skin-0',
        'skin-7',
        'skin-01',
        'SKIN-1',
        'bg-01',
        'x',
      ]) {
        final result = validateAvatar(
          characterId: 'char-01',
          skinId: id,
          backgroundId: 'bg-01',
        );

        expect(issuesOf(result), [
          (AvatarComponent.skin, 'avatar_skin_unknown'),
        ], reason: id);
      }
    });

    test('fondos fuera de la paleta', () {
      for (final id in ['bg-00', 'bg-13', 'bg-1', 'BG-01', 'char-01', 'x']) {
        final result = validateAvatar(
          characterId: 'char-01',
          skinId: 'skin-1',
          backgroundId: id,
        );

        expect(issuesOf(result), [
          (AvatarComponent.background, 'avatar_background_unknown'),
        ], reason: id);
      }
    });

    test(
      'un identificador de otro componente no sirve (un fondo como personaje)',
      () {
        final result = validateAvatar(
          characterId: 'bg-01',
          skinId: 'char-01',
          backgroundId: 'skin-1',
        );

        expect(issuesOf(result), [
          (AvatarComponent.character, 'avatar_character_unknown'),
          (AvatarComponent.skin, 'avatar_skin_unknown'),
          (AvatarComponent.background, 'avatar_background_unknown'),
        ]);
      },
    );

    test('se reportan faltantes y desconocidos a la vez, en orden', () {
      final result = validateAvatar(
        characterId: null,
        skinId: 'skin-9',
        backgroundId: 'bg-01',
      );

      expect(issuesOf(result), [
        (AvatarComponent.character, 'avatar_character_required'),
        (AvatarComponent.skin, 'avatar_skin_unknown'),
      ]);
    });
  });
}
