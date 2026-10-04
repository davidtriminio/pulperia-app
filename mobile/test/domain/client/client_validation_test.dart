import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/client/client_validation.dart';

import '../../support/shared_vectors.dart';

ClientDraft draft({
  String name = 'Ana López',
  String? note,
  String? phone,
  String? address,
  String? characterId = 'char-01',
  String? skinId = 'skin-1',
  String? backgroundId = 'bg-01',
}) => ClientDraft(
  name: name,
  note: note,
  phone: phone,
  address: address,
  characterId: characterId,
  skinId: skinId,
  backgroundId: backgroundId,
);

List<(ClientField, String)> issuesOf(ClientValidationResult result) =>
    switch (result) {
      ValidClient() => const [],
      InvalidClient(:final issues) => [
        for (final i in issues) (i.field, i.code),
      ],
    };

void main() {
  group('nombre y nota con los vectores compartidos (RF-15, RF-74)', () {
    final cases = loadVectorCases('client-validation.json');

    test('hay al menos 25 casos', () {
      expect(cases.length, greaterThanOrEqualTo(25));
    });

    for (final c in cases) {
      test(c.name, () {
        final result = validateClient(
          draft(
            name: c.input['name'] as String,
            note: c.input['note'] as String?,
          ),
        );

        expect([
          for (final (_, code) in issuesOf(result)) code,
        ], c.expected['errors']);
      });
    }
  });

  group('teléfono con los vectores compartidos (RF-77)', () {
    final cases = loadVectorCases('phone.json');

    test('hay al menos 25 casos', () {
      expect(cases.length, greaterThanOrEqualTo(25));
    });

    for (final c in cases) {
      test(c.name, () {
        final result = validateClient(draft(phone: c.input['phone'] as String));

        if (c.expected['valid'] == true) {
          expect(issuesOf(result), isEmpty);
        } else {
          expect(issuesOf(result), [(ClientField.phone, c.expected['error'])]);
        }
      });
    }
  });

  group('teléfono opcional (RF-73)', () {
    test('sin teléfono es válido', () {
      expect(issuesOf(validateClient(draft())), isEmpty);
    });

    test('un teléfono vacío cuenta como ausente', () {
      expect(issuesOf(validateClient(draft(phone: ''))), isEmpty);
    });
  });

  group('avatar completo (RF-16)', () {
    test('sin nada elegido, indica qué falta: personaje, tono y fondo', () {
      final result = validateClient(
        draft(characterId: null, skinId: null, backgroundId: null),
      );

      expect(issuesOf(result), [
        (ClientField.avatarCharacter, 'avatar_character_required'),
        (ClientField.avatarSkin, 'avatar_skin_required'),
        (ClientField.avatarBackground, 'avatar_background_required'),
      ]);
    });

    test('falta solo el personaje', () {
      expect(issuesOf(validateClient(draft(characterId: null))), [
        (ClientField.avatarCharacter, 'avatar_character_required'),
      ]);
    });

    test('falta solo el tono de piel', () {
      expect(issuesOf(validateClient(draft(skinId: null))), [
        (ClientField.avatarSkin, 'avatar_skin_required'),
      ]);
    });

    test('falta solo el fondo', () {
      expect(issuesOf(validateClient(draft(backgroundId: null))), [
        (ClientField.avatarBackground, 'avatar_background_required'),
      ]);
    });

    test('un identificador vacío cuenta como no elegido', () {
      expect(issuesOf(validateClient(draft(characterId: ''))), [
        (ClientField.avatarCharacter, 'avatar_character_required'),
      ]);
    });
  });

  group('varios problemas a la vez', () {
    test(
      'se reportan en orden: nombre, nota, teléfono, personaje, tono, fondo',
      () {
        final result = validateClient(
          draft(
            name: '  ',
            note: 'x' * 301,
            phone: '12345',
            characterId: null,
            skinId: null,
            backgroundId: null,
          ),
        );

        expect(issuesOf(result), [
          (ClientField.name, 'name_required'),
          (ClientField.note, 'note_too_long'),
          (ClientField.phone, 'phone_invalid_format'),
          (ClientField.avatarCharacter, 'avatar_character_required'),
          (ClientField.avatarSkin, 'avatar_skin_required'),
          (ClientField.avatarBackground, 'avatar_background_required'),
        ]);
      },
    );
  });

  group('lo que no valida', () {
    test('la dirección es opcional y no tiene regla en la spec', () {
      expect(issuesOf(validateClient(draft(address: ''))), isEmpty);
      expect(
        issuesOf(validateClient(draft(address: 'Frente a la iglesia'))),
        isEmpty,
      );
    });
  });

  group('cliente válido', () {
    test('devuelve el borrador sin modificarlo', () {
      final original = draft(
        name: '  Ana  ',
        note: 'Paga los viernes',
        phone: '90000000',
      );

      final result = validateClient(original);

      expect((result as ValidClient).draft, same(original));
    });
  });
}
