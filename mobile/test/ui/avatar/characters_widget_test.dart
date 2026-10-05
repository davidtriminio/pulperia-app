import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/avatar/avatar.dart';
import 'package:pulperia_mobile/ui/avatar/avatar_characters.dart';
import 'package:pulperia_mobile/ui/avatar/hex_color.dart';

void main() {
  testWidgets('los 24 personajes se ven con los 6 tonos y los 12 fondos', (
    tester,
  ) async {
    final prototypes = AvatarPalette.characterIds;
    final tiles = <Widget>[
      for (final id in prototypes)
        for (final skin in AvatarPalette.skinTones)
          for (final bg in AvatarPalette.backgrounds)
            Container(
              key: ValueKey('$id/${skin.id}/${bg.id}'),
              width: 24,
              height: 24,
              color: hexColor(bg.hex),
              child: CustomPaint(
                painter: AvatarCharacterPainter(
                  AvatarCharacters.of(id),
                  hexColor(skin.hex),
                ),
              ),
            ),
    ];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(child: Wrap(children: tiles)),
      ),
    );

    expect(tiles, hasLength(24 * 6 * 12));
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(24 * 6 * 12));
  });
}
