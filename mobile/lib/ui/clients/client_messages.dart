import '../../domain/client/client_validation.dart';
import '../../l10n/strings.dart';

/// Mensaje en español para un problema de validación de cliente. Los códigos
/// son los estables del dominio (RNF-5).
String clientIssueMessage(ClientIssue issue) => switch (issue.code) {
  'name_required' => Strings.nameRequired,
  'note_too_long' => Strings.noteTooLong,
  'phone_invalid_format' => Strings.phoneInvalid,
  'avatar_character_required' => Strings.avatarMissingCharacter,
  'avatar_skin_required' => Strings.avatarMissingSkin,
  'avatar_background_required' => Strings.avatarMissingBackground,
  // Un id fuera de la paleta no se puede elegir desde la interfaz.
  _ => Strings.saveError,
};
