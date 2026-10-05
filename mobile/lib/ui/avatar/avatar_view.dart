import 'package:flutter/material.dart';

import '../../domain/avatar/avatar.dart';
import '../../l10n/strings.dart';
import 'avatar_characters.dart';
import 'hex_color.dart';

/// Muestra un avatar: el personaje con su tono de piel sobre un fondo de
/// color, en un círculo del tamaño pedido (RF-14, RF-72).
///
/// Si un identificador no está en la paleta (no debería pasar: se valida al
/// guardar) usa un gris neutro en vez de fallar.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.avatar, this.size = 48});

  final Avatar avatar;
  final double size;

  static const _fallback = Color(0xFFB0BEC5);

  @override
  Widget build(BuildContext context) {
    final background = AvatarPalette.backgrounds
        .where((b) => b.id == avatar.backgroundId)
        .map((b) => hexColor(b.hex))
        .firstOrNull;
    final skin = AvatarPalette.skinTones
        .where((s) => s.id == avatar.skinId)
        .map((s) => hexColor(s.hex))
        .firstOrNull;

    return Semantics(
      label: Strings.avatar,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background ?? _fallback,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: CustomPaint(
              painter: AvatarCharacterPainter(
                AvatarCharacters.of(avatar.characterId),
                skin ?? _fallback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
