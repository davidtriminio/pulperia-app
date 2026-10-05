import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/avatar/avatar.dart';
import 'package:pulperia_mobile/ui/avatar/avatar_characters.dart';
import 'package:pulperia_mobile/ui/avatar/avatar_view.dart';
import 'package:pulperia_mobile/ui/avatar/hex_color.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

AvatarCharacterPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(AvatarView),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as AvatarCharacterPainter;

void main() {
  const combos = [
    Avatar(characterId: 'char-01', skinId: 'skin-1', backgroundId: 'bg-01'),
    Avatar(characterId: 'char-02', skinId: 'skin-3', backgroundId: 'bg-06'),
    Avatar(characterId: 'char-03', skinId: 'skin-6', backgroundId: 'bg-12'),
    // Sin ilustración todavía: usa el marcador.
    Avatar(characterId: 'char-24', skinId: 'skin-2', backgroundId: 'bg-09'),
  ];

  for (final avatar in combos) {
    testWidgets('muestra $avatar con su fondo, su tono y su personaje', (
      tester,
    ) async {
      await tester.pumpWidget(_host(AvatarView(avatar: avatar, size: 80)));

      expect(tester.takeException(), isNull);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(AvatarView),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      final background = AvatarPalette.backgrounds.firstWhere(
        (b) => b.id == avatar.backgroundId,
      );
      final skin = AvatarPalette.skinTones.firstWhere(
        (s) => s.id == avatar.skinId,
      );
      expect(decoration.color, hexColor(background.hex));
      expect(decoration.shape, BoxShape.circle);
      expect(_painter(tester).character.id, avatar.characterId);
      expect(_painter(tester).skin, hexColor(skin.hex));
    });
  }

  testWidgets('respeta el tamaño pedido', (tester) async {
    await tester.pumpWidget(_host(AvatarView(avatar: combos.first, size: 64)));

    expect(tester.getSize(find.byType(AvatarView)), const Size(64, 64));
  });

  testWidgets('cambiar el avatar repinta con el nuevo personaje', (
    tester,
  ) async {
    await tester.pumpWidget(_host(AvatarView(avatar: combos[0], size: 80)));
    expect(_painter(tester).character.id, 'char-01');

    await tester.pumpWidget(_host(AvatarView(avatar: combos[1], size: 80)));
    expect(_painter(tester).character.id, 'char-02');
  });

  testWidgets('un id fuera de la paleta no rompe: se ve el marcador', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AvatarView(
          avatar: Avatar(
            characterId: 'char-99',
            skinId: 'skin-1',
            backgroundId: 'bg-01',
          ),
          size: 80,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
