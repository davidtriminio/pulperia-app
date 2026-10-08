using System.Text.RegularExpressions;
using Pulperia.Domain.Avatars;

namespace Pulperia.Domain.Clients;

/// <summary>Lo que el usuario ingresa al crear o editar un cliente.</summary>
/// <param name="CharacterId">Los tres componentes del avatar (RF-14); null o vacío significa que no se eligió.</param>
public sealed record ClientDraft(
    string Name,
    string? Note,
    string? Phone,
    string? Address,
    string? CharacterId,
    string? SkinId,
    string? BackgroundId);

/// <summary>Campo de un cliente al que se refiere un problema de validación.</summary>
public enum ClientField
{
    Name,
    Note,
    Phone,
    AvatarCharacter,
    AvatarSkin,
    AvatarBackground,
}

/// <param name="Code">Código estable, el mismo de los vectores compartidos y del móvil.</param>
public sealed record ClientIssue(ClientField Field, string Code);

public abstract record ClientValidationResult;

public sealed record ValidClient(ClientDraft Draft) : ClientValidationResult;

public sealed record InvalidClient(IReadOnlyList<ClientIssue> Issues) : ClientValidationResult;

public static class ClientValidator
{
    public const int MaxNoteLength = 300;

    // \z y no $ (en .NET $ acepta un salto de línea final); [0-9] y no \d.
    private static readonly Regex PhoneFormat = new(@"^[2389][0-9]{7}\z", RegexOptions.CultureInvariant);

    /// <summary>
    /// Valida un cliente según RF-15, RF-16, RF-72, RF-74 y RF-77. Reporta todos los
    /// problemas, en este orden: nombre, nota, teléfono, personaje, tono de piel y fondo.
    /// El aviso de nombre repetido (RF-17) es aparte, no es un error.
    /// </summary>
    public static ClientValidationResult Validate(ClientDraft draft)
    {
        var issues = new List<ClientIssue>();

        if (string.IsNullOrWhiteSpace(draft.Name))
        {
            issues.Add(new ClientIssue(ClientField.Name, "name_required"));
        }

        if (draft.Note is { Length: > MaxNoteLength })
        {
            issues.Add(new ClientIssue(ClientField.Note, "note_too_long"));
        }

        // El teléfono es opcional: vacío cuenta como ausente. Cuando hay valor se
        // evalúa tal cual, sin recortar espacios.
        if (!string.IsNullOrEmpty(draft.Phone) && !PhoneFormat.IsMatch(draft.Phone))
        {
            issues.Add(new ClientIssue(ClientField.Phone, "phone_invalid_format"));
        }

        foreach (var issue in AvatarValidator.Validate(draft.CharacterId, draft.SkinId, draft.BackgroundId))
        {
            var field = issue.Component switch
            {
                AvatarComponent.Character => ClientField.AvatarCharacter,
                AvatarComponent.Skin => ClientField.AvatarSkin,
                _ => ClientField.AvatarBackground,
            };
            issues.Add(new ClientIssue(field, issue.Code));
        }

        return issues.Count == 0 ? new ValidClient(draft) : new InvalidClient(issues);
    }
}
