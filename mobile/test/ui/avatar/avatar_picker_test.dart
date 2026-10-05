import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/avatar/avatar.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/avatar/avatar_characters.dart';
import 'package:pulperia_mobile/ui/avatar/avatar_picker.dart';
import 'package:pulperia_mobile/ui/avatar/hex_color.dart';

void main() {
  Avatar? confirmed;

  Future<void> pumpPicker(WidgetTester tester, {Avatar? initial}) async {
    confirmed = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarPicker(
            initial: initial,
            onContinue: (avatar) => confirmed = avatar,
          ),
        ),
      ),
    );
  }

  Future<void> choose(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Finder continueButton() => find.byKey(const ValueKey('avatar-continue'));

  bool enabled(WidgetTester tester) =>
      tester.widget<FilledButton>(continueButton()).onPressed != null;

  testWidgets('ofrece 24 personajes, 6 tonos y 12 fondos', (tester) async {
    await pumpPicker(tester);

    for (final id in AvatarPalette.characterIds) {
      expect(find.byKey(ValueKey('pick-$id')), findsOne);
    }
    for (final s in AvatarPalette.skinTones) {
      expect(find.byKey(ValueKey('pick-${s.id}')), findsOne);
    }
    for (final b in AvatarPalette.backgrounds) {
      expect(find.byKey(ValueKey('pick-${b.id}')), findsOne);
    }
  });

  testWidgets('sin tono elegido las miniaturas usan uno por defecto, no gris', (
    tester,
  ) async {
    await pumpPicker(tester);

    AvatarCharacterPainter painterOf(String key) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as AvatarCharacterPainter;

    final fallbackSkin = hexColor(AvatarPalette.skinTones[1].hex);
    expect(painterOf('pick-char-05').skin, fallbackSkin);
    expect(painterOf('pick-char-24').skin, fallbackSkin);

    await choose(tester, 'pick-skin-5');
    final chosen = hexColor(AvatarPalette.skinTones[4].hex);
    expect(painterOf('pick-char-05').skin, chosen);
    expect(painterOf('pick-char-24').skin, chosen);
  });

  testWidgets('sin elegir nada no se puede continuar y indica qué falta', (
    tester,
  ) async {
    await pumpPicker(tester);

    expect(enabled(tester), isFalse);
    expect(find.text(Strings.avatarMissingCharacter), findsOne);
    expect(find.text(Strings.avatarMissingSkin), findsOne);
    expect(find.text(Strings.avatarMissingBackground), findsOne);
  });

  testWidgets('con solo dos de las tres cosas elegidas sigue bloqueado', (
    tester,
  ) async {
    await pumpPicker(tester);

    await choose(tester, 'pick-char-02');
    await choose(tester, 'pick-skin-3');

    expect(enabled(tester), isFalse);
    expect(find.text(Strings.avatarMissingCharacter), findsNothing);
    expect(find.text(Strings.avatarMissingSkin), findsNothing);
    expect(find.text(Strings.avatarMissingBackground), findsOne);
  });

  testWidgets('cada una de las tres elecciones es obligatoria', (tester) async {
    final all = ['pick-char-05', 'pick-skin-2', 'pick-bg-07'];
    for (var skip = 0; skip < all.length; skip++) {
      await tester.pumpWidget(const SizedBox()); // descarta el estado previo
      await pumpPicker(tester);
      for (var i = 0; i < all.length; i++) {
        if (i != skip) {
          await choose(tester, all[i]);
        }
      }
      expect(enabled(tester), isFalse, reason: 'sin ${all[skip]}');
    }
  });

  testWidgets('con las tres elegidas continúa con ese avatar', (tester) async {
    await pumpPicker(tester);

    await choose(tester, 'pick-char-02');
    await choose(tester, 'pick-skin-3');
    await choose(tester, 'pick-bg-11');

    expect(enabled(tester), isTrue);
    await tester.tap(continueButton());
    expect(
      confirmed,
      const Avatar(
        characterId: 'char-02',
        skinId: 'skin-3',
        backgroundId: 'bg-11',
      ),
    );
  });

  testWidgets('se puede cambiar de elección antes de continuar', (
    tester,
  ) async {
    await pumpPicker(tester);
    await choose(tester, 'pick-char-02');
    await choose(tester, 'pick-skin-3');
    await choose(tester, 'pick-bg-11');

    await choose(tester, 'pick-char-03');
    await choose(tester, 'pick-bg-01');
    await tester.tap(continueButton());

    expect(
      confirmed,
      const Avatar(
        characterId: 'char-03',
        skinId: 'skin-3',
        backgroundId: 'bg-01',
      ),
    );
  });

  testWidgets(
    'al editar, el avatar actual ya permite continuar y se puede retocar',
    (tester) async {
      const current = Avatar(
        characterId: 'char-01',
        skinId: 'skin-1',
        backgroundId: 'bg-01',
      );
      await pumpPicker(tester, initial: current);

      expect(enabled(tester), isTrue);
      await choose(tester, 'pick-skin-5');
      await tester.tap(continueButton());

      expect(
        confirmed,
        const Avatar(
          characterId: 'char-01',
          skinId: 'skin-5',
          backgroundId: 'bg-01',
        ),
      );
    },
  );
}
