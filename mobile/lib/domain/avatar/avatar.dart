/// Color con identificador estable, para tonos de piel y fondos.
final class AvatarColor {
  const AvatarColor(this.id, this.hex);

  final String id;

  /// Color en hexadecimal, por ejemplo `#F9DCC4`.
  final String hex;
}

/// Paleta de avatares: 24 personajes, 6 tonos de piel y 12 fondos (RF-72).
///
/// Debe coincidir con `shared/vectors/avatar-palette.json`; un test lo
/// comprueba. Los ids nunca se renombran ni se reutilizan, porque se guardan
/// en cada cliente.
abstract final class AvatarPalette {
  static const List<String> characterIds = [
    'char-01', 'char-02', 'char-03', 'char-04', 'char-05', 'char-06', //
    'char-07', 'char-08', 'char-09', 'char-10', 'char-11', 'char-12', //
    'char-13', 'char-14', 'char-15', 'char-16', 'char-17', 'char-18', //
    'char-19', 'char-20', 'char-21', 'char-22', 'char-23', 'char-24',
  ];

  /// De claro a oscuro.
  static const List<AvatarColor> skinTones = [
    AvatarColor('skin-1', '#F9DCC4'),
    AvatarColor('skin-2', '#EDBA94'),
    AvatarColor('skin-3', '#D9966B'),
    AvatarColor('skin-4', '#B26F47'),
    AvatarColor('skin-5', '#8A5230'),
    AvatarColor('skin-6', '#5C3A21'),
  ];

  static const List<AvatarColor> backgrounds = [
    AvatarColor('bg-01', '#E57373'),
    AvatarColor('bg-02', '#FFB74D'),
    AvatarColor('bg-03', '#FFF176'),
    AvatarColor('bg-04', '#AED581'),
    AvatarColor('bg-05', '#66BB6A'),
    AvatarColor('bg-06', '#4DB6AC'),
    AvatarColor('bg-07', '#4DD0E1'),
    AvatarColor('bg-08', '#64B5F6'),
    AvatarColor('bg-09', '#7986CB'),
    AvatarColor('bg-10', '#BA68C8'),
    AvatarColor('bg-11', '#F06292'),
    AvatarColor('bg-12', '#B0BEC5'),
  ];

  static int get combinationCount =>
      characterIds.length * skinTones.length * backgrounds.length;

  static bool hasCharacter(String id) => characterIds.contains(id);
  static bool hasSkin(String id) => skinTones.any((s) => s.id == id);
  static bool hasBackground(String id) => backgrounds.any((b) => b.id == id);
}

/// Un avatar: la combinación de un personaje, un tono de piel y un fondo.
final class Avatar {
  const Avatar({
    required this.characterId,
    required this.skinId,
    required this.backgroundId,
  });

  final String characterId;
  final String skinId;
  final String backgroundId;

  @override
  bool operator ==(Object other) =>
      other is Avatar &&
      other.characterId == characterId &&
      other.skinId == skinId &&
      other.backgroundId == backgroundId;

  @override
  int get hashCode => Object.hash(characterId, skinId, backgroundId);

  @override
  String toString() => 'Avatar($characterId, $skinId, $backgroundId)';
}

enum AvatarComponent { character, skin, background }

final class AvatarIssue {
  const AvatarIssue(this.component, this.code);

  final AvatarComponent component;

  /// Código estable, el mismo de la API.
  final String code;
}

sealed class AvatarValidationResult {
  const AvatarValidationResult();
}

final class ValidAvatar extends AvatarValidationResult {
  const ValidAvatar(this.avatar);

  final Avatar avatar;
}

final class InvalidAvatar extends AvatarValidationResult {
  const InvalidAvatar(this.issues);

  final List<AvatarIssue> issues;
}

AvatarIssue? _check(
  AvatarComponent component,
  String name,
  String? id,
  bool Function(String) isInPalette,
) {
  if (id == null || id.isEmpty) {
    return AvatarIssue(component, 'avatar_${name}_required');
  }
  if (!isInPalette(id)) {
    return AvatarIssue(component, 'avatar_${name}_unknown');
  }
  return null;
}

/// Valida que el avatar esté completo (RF-16) y que cada identificador exista
/// en la paleta (RF-72). Reporta todos los problemas, en este orden:
/// personaje, tono de piel y fondo.
AvatarValidationResult validateAvatar({
  required String? characterId,
  required String? skinId,
  required String? backgroundId,
}) {
  final issues = [
    _check(
      AvatarComponent.character,
      'character',
      characterId,
      AvatarPalette.hasCharacter,
    ),
    _check(AvatarComponent.skin, 'skin', skinId, AvatarPalette.hasSkin),
    _check(
      AvatarComponent.background,
      'background',
      backgroundId,
      AvatarPalette.hasBackground,
    ),
  ].nonNulls.toList();

  if (issues.isNotEmpty) {
    return InvalidAvatar(issues);
  }
  return ValidAvatar(
    Avatar(
      characterId: characterId!,
      skinId: skinId!,
      backgroundId: backgroundId!,
    ),
  );
}
