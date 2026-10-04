import '../avatar/avatar.dart';

/// Lo que el usuario ingresa al crear o editar un cliente.
final class ClientDraft {
  const ClientDraft({
    required this.name,
    this.note,
    this.phone,
    this.address,
    this.characterId,
    this.skinId,
    this.backgroundId,
  });

  final String name;
  final String? note;
  final String? phone;
  final String? address;

  /// Los tres componentes del avatar (RF-14); null o vacío significa que
  /// todavía no se eligió.
  final String? characterId;
  final String? skinId;
  final String? backgroundId;
}

/// Campo de un cliente al que se refiere un problema de validación.
enum ClientField {
  name,
  note,
  phone,
  avatarCharacter,
  avatarSkin,
  avatarBackground,
}

final class ClientIssue {
  const ClientIssue(this.field, this.code);

  final ClientField field;

  /// Código estable, el mismo de los vectores compartidos y de la API.
  final String code;
}

sealed class ClientValidationResult {
  const ClientValidationResult();
}

final class ValidClient extends ClientValidationResult {
  const ValidClient(this.draft);

  final ClientDraft draft;
}

final class InvalidClient extends ClientValidationResult {
  const InvalidClient(this.issues);

  final List<ClientIssue> issues;
}

const int maxNoteLength = 300;

final RegExp _phoneFormat = RegExp(r'^[2389][0-9]{7}$');

bool _isMissing(String? value) => value == null || value.isEmpty;

const Map<AvatarComponent, ClientField> _avatarFields = {
  AvatarComponent.character: ClientField.avatarCharacter,
  AvatarComponent.skin: ClientField.avatarSkin,
  AvatarComponent.background: ClientField.avatarBackground,
};

/// Valida un cliente según RF-15, RF-16, RF-72, RF-74 y RF-77. Reporta todos los
/// problemas, en este orden: nombre, nota, teléfono, personaje, tono de piel
/// y fondo. El aviso de nombre repetido (RF-17) es aparte, no es un error.
ClientValidationResult validateClient(ClientDraft draft) {
  final issues = <ClientIssue>[];

  if (draft.name.trim().isEmpty) {
    issues.add(const ClientIssue(ClientField.name, 'name_required'));
  }

  final note = draft.note;
  if (note != null && note.length > maxNoteLength) {
    issues.add(const ClientIssue(ClientField.note, 'note_too_long'));
  }

  // El teléfono es opcional: vacío cuenta como ausente. Cuando hay valor se
  // evalúa tal cual, sin recortar espacios.
  final phone = draft.phone;
  if (!_isMissing(phone) && !_phoneFormat.hasMatch(phone!)) {
    issues.add(const ClientIssue(ClientField.phone, 'phone_invalid_format'));
  }

  final avatar = validateAvatar(
    characterId: draft.characterId,
    skinId: draft.skinId,
    backgroundId: draft.backgroundId,
  );
  if (avatar is InvalidAvatar) {
    for (final issue in avatar.issues) {
      issues.add(ClientIssue(_avatarFields[issue.component]!, issue.code));
    }
  }

  return issues.isEmpty ? ValidClient(draft) : InvalidClient(issues);
}
