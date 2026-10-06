import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/avatar/avatar.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/avatar/avatar_characters.dart';
import 'package:pulperia_mobile/ui/avatar/avatar_picker.dart';
import 'package:pulperia_mobile/ui/avatar/hex_color.dart';
import 'package:pulperia_mobile/ui/theme.dart';

void main() {
  Avatar? confirmed;

  Future<void> pumpPicker(WidgetTester tester, {Avatar? initial}) async {
    confirmed = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: AvatarPicker(
            initial: initial,
            onContinue: (avatar) => confirmed = avatar,
          ),
        ),
      ),
    );
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String key) {
    final widget = tester.widget(find.byKey(ValueKey(key)));
    return switch (widget) {
      FilledButton(:final onPressed) => onPressed != null,
      _ => throw StateError('no es un botón relleno'),
    };
  }

  AvatarCharacterPainter painterIn(WidgetTester tester, String key) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as AvatarCharacterPainter;

  bool selected(WidgetTester tester, String key) =>
      find.byKey(ValueKey('selected-$key')).evaluate().isNotEmpty;

  group('paso 1: personaje', () {
    testWidgets('empieza en el paso del personaje con los 24 personajes', (
      tester,
    ) async {
      await pumpPicker(tester);

      for (final id in AvatarPalette.characterIds) {
        expect(find.byKey(ValueKey('pick-$id')), findsOne);
      }
      for (final s in AvatarPalette.skinTones) {
        expect(find.byKey(ValueKey('pick-${s.id}')), findsNothing);
      }
      expect(find.byKey(const ValueKey('avatar-back')), findsNothing);
    });

    testWidgets('muestra los tres pasos con su nombre', (tester) async {
      await pumpPicker(tester);

      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('avatar-step-$i')), findsOne);
      }
      expect(find.text(Strings.avatarStepCharacter), findsWidgets);
      expect(find.text(Strings.avatarStepSkin), findsWidgets);
      expect(find.text(Strings.avatarStepBackground), findsWidgets);
    });

    testWidgets('sin personaje no se puede seguir y se avisa', (tester) async {
      await pumpPicker(tester);

      expect(enabled(tester, 'avatar-next'), isFalse);
      expect(find.text(Strings.avatarChooseCharacterHint), findsOne);
    });

    testWidgets('al elegir un personaje se habilita el siguiente paso', (
      tester,
    ) async {
      await pumpPicker(tester);

      await tapKey(tester, 'pick-char-05');

      expect(enabled(tester, 'avatar-next'), isTrue);
      expect(find.text(Strings.avatarChooseCharacterHint), findsNothing);
    });

    testWidgets('solo hay un personaje elegido a la vez', (tester) async {
      await pumpPicker(tester);

      await tapKey(tester, 'pick-char-05');
      await tapKey(tester, 'pick-char-07');

      expect(selected(tester, 'pick-char-07'), isTrue);
      expect(selected(tester, 'pick-char-05'), isFalse);
    });
  });

  group('valores por defecto', () {
    testWidgets('el tono y el fondo ya vienen elegidos', (tester) async {
      await pumpPicker(tester);
      await tapKey(tester, 'pick-char-01');

      await tapKey(tester, 'avatar-next');
      expect(selected(tester, 'pick-${AvatarPalette.skinTones[1].id}'), isTrue);

      await tapKey(tester, 'avatar-next');
      expect(
        selected(tester, 'pick-${AvatarPalette.backgrounds[7].id}'),
        isTrue,
      );
    });

    testWidgets('con solo elegir el personaje se puede terminar', (
      tester,
    ) async {
      await pumpPicker(tester);

      await tapKey(tester, 'pick-char-02');
      await tapKey(tester, 'avatar-next');
      await tapKey(tester, 'avatar-next');
      await tapKey(tester, 'avatar-continue');

      expect(
        confirmed,
        Avatar(
          characterId: 'char-02',
          skinId: AvatarPalette.skinTones[1].id,
          backgroundId: AvatarPalette.backgrounds[7].id,
        ),
      );
    });

    testWidgets('sin tono elegido las miniaturas usan el tono por defecto', (
      tester,
    ) async {
      await pumpPicker(tester);

      final fallback = hexColor(AvatarPalette.skinTones[1].hex);
      expect(painterIn(tester, 'pick-char-05').skin, fallback);
      expect(painterIn(tester, 'pick-char-24').skin, fallback);
    });
  });

  group('paso 2: tono de piel y paso 3: fondo', () {
    testWidgets('el segundo paso ofrece los 6 tonos', (tester) async {
      await pumpPicker(tester);
      await tapKey(tester, 'pick-char-01');

      await tapKey(tester, 'avatar-next');

      for (final s in AvatarPalette.skinTones) {
        expect(find.byKey(ValueKey('pick-${s.id}')), findsOne);
      }
      expect(find.byKey(const ValueKey('pick-char-01')), findsNothing);
    });

    testWidgets('el tercer paso ofrece los 12 fondos', (tester) async {
      await pumpPicker(tester);
      await tapKey(tester, 'pick-char-01');
      await tapKey(tester, 'avatar-next');

      await tapKey(tester, 'avatar-next');

      for (final b in AvatarPalette.backgrounds) {
        expect(find.byKey(ValueKey('pick-${b.id}')), findsOne);
      }
    });

    testWidgets('el último paso muestra "Listo" en lugar de "Siguiente"', (
      tester,
    ) async {
      await pumpPicker(tester);
      await tapKey(tester, 'pick-char-01');
      await tapKey(tester, 'avatar-next');
      expect(find.byKey(const ValueKey('avatar-continue')), findsNothing);

      await tapKey(tester, 'avatar-next');

      expect(find.byKey(const ValueKey('avatar-next')), findsNothing);
      expect(find.byKey(const ValueKey('avatar-continue')), findsOne);
    });

    testWidgets('se puede volver atrás sin perder lo elegido', (tester) async {
      await pumpPicker(tester);
      await tapKey(tester, 'pick-char-09');
      await tapKey(tester, 'avatar-next');
      await tapKey(tester, 'pick-skin-5');

      await tapKey(tester, 'avatar-back');

      expect(selected(tester, 'pick-char-09'), isTrue);
      final skin = hexColor(AvatarPalette.skinTones[4].hex);
      expect(painterIn(tester, 'pick-char-05').skin, skin);
    });
  });

  group('vista previa', () {
    testWidgets('refleja el personaje, el tono y el fondo elegidos', (
      tester,
    ) async {
      await pumpPicker(tester);
      await tapKey(tester, 'pick-char-03');
      await tapKey(tester, 'avatar-next');
      await tapKey(tester, 'pick-skin-4');
      await tapKey(tester, 'avatar-next');
      await tapKey(tester, 'pick-bg-11');

      final preview = painterIn(tester, 'avatar-preview');
      expect(preview.character.id, 'char-03');
      expect(preview.skin, hexColor(AvatarPalette.skinTones[3].hex));
    });
  });

  group('navegar por los pasos de arriba', () {
    testWidgets('sin personaje no se puede saltar a otro paso', (tester) async {
      await pumpPicker(tester);

      await tapKey(tester, 'avatar-step-2');

      expect(find.byKey(const ValueKey('pick-char-01')), findsOne);
      expect(find.byKey(const ValueKey('pick-bg-01')), findsNothing);
    });

    testWidgets('con personaje sí se puede ir a cualquier paso', (
      tester,
    ) async {
      await pumpPicker(tester);
      await tapKey(tester, 'pick-char-01');

      await tapKey(tester, 'avatar-step-2');
      expect(find.byKey(const ValueKey('pick-bg-01')), findsOne);

      await tapKey(tester, 'avatar-step-1');
      expect(find.byKey(const ValueKey('pick-skin-1')), findsOne);
    });
  });

  group('al editar un cliente', () {
    const current = Avatar(
      characterId: 'char-01',
      skinId: 'skin-1',
      backgroundId: 'bg-01',
    );

    testWidgets('el avatar actual viene elegido y se puede continuar', (
      tester,
    ) async {
      await pumpPicker(tester, initial: current);

      expect(selected(tester, 'pick-char-01'), isTrue);
      expect(enabled(tester, 'avatar-next'), isTrue);
      expect(find.text(Strings.avatarChooseCharacterHint), findsNothing);
    });

    testWidgets('se puede retocar solo una parte', (tester) async {
      await pumpPicker(tester, initial: current);

      await tapKey(tester, 'avatar-next');
      await tapKey(tester, 'pick-skin-5');
      await tapKey(tester, 'avatar-next');
      await tapKey(tester, 'avatar-continue');

      expect(
        confirmed,
        const Avatar(
          characterId: 'char-01',
          skinId: 'skin-5',
          backgroundId: 'bg-01',
        ),
      );
    });
  });
}
