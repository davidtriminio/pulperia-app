namespace Pulperia.Domain.Avatars;

/// <summary>Color con identificador estable, para tonos de piel y fondos.</summary>
public sealed record AvatarColor(string Id, string Hex);

/// <summary>
/// Paleta de avatares: 24 personajes, 6 tonos de piel y 12 fondos (RF-72). Debe
/// coincidir con <c>shared/vectors/avatar-palette.json</c>; un test lo comprueba. Los
/// ids nunca se renombran ni se reutilizan, porque se guardan en cada cliente.
/// </summary>
public static class AvatarPalette
{
    public static readonly IReadOnlyList<string> CharacterIds =
        Enumerable.Range(1, 24).Select(n => $"char-{n:00}").ToList();

    /// <summary>De claro a oscuro.</summary>
    public static readonly IReadOnlyList<AvatarColor> SkinTones =
    [
        new("skin-1", "#F9DCC4"),
        new("skin-2", "#EDBA94"),
        new("skin-3", "#D9966B"),
        new("skin-4", "#B26F47"),
        new("skin-5", "#8A5230"),
        new("skin-6", "#5C3A21"),
    ];

    public static readonly IReadOnlyList<AvatarColor> Backgrounds =
    [
        new("bg-01", "#E57373"),
        new("bg-02", "#FFB74D"),
        new("bg-03", "#FFF176"),
        new("bg-04", "#AED581"),
        new("bg-05", "#66BB6A"),
        new("bg-06", "#4DB6AC"),
        new("bg-07", "#4DD0E1"),
        new("bg-08", "#64B5F6"),
        new("bg-09", "#7986CB"),
        new("bg-10", "#BA68C8"),
        new("bg-11", "#F06292"),
        new("bg-12", "#B0BEC5"),
    ];

    public static int CombinationCount => CharacterIds.Count * SkinTones.Count * Backgrounds.Count;

    public static bool HasCharacter(string id) => CharacterIds.Contains(id);

    public static bool HasSkin(string id) => SkinTones.Any(s => s.Id == id);

    public static bool HasBackground(string id) => Backgrounds.Any(b => b.Id == id);
}

public enum AvatarComponent
{
    Character,
    Skin,
    Background,
}

/// <param name="Code">Código estable: <c>avatar_{componente}_required</c> o <c>avatar_{componente}_unknown</c>.</param>
public sealed record AvatarIssue(AvatarComponent Component, string Code);

public static class AvatarValidator
{
    /// <summary>
    /// Valida que el avatar esté completo (RF-16) y que cada identificador exista en la
    /// paleta (RF-72). Reporta todos los problemas, en este orden: personaje, tono de piel
    /// y fondo. Una lista vacía significa que el avatar es válido.
    /// </summary>
    public static IReadOnlyList<AvatarIssue> Validate(string? characterId, string? skinId, string? backgroundId)
    {
        var issues = new[]
        {
            Check(AvatarComponent.Character, "character", characterId, AvatarPalette.HasCharacter),
            Check(AvatarComponent.Skin, "skin", skinId, AvatarPalette.HasSkin),
            Check(AvatarComponent.Background, "background", backgroundId, AvatarPalette.HasBackground),
        };
        return issues.Where(i => i is not null).Select(i => i!).ToList();
    }

    private static AvatarIssue? Check(
        AvatarComponent component, string name, string? id, Func<string, bool> isInPalette)
    {
        if (string.IsNullOrEmpty(id))
        {
            return new AvatarIssue(component, $"avatar_{name}_required");
        }
        return isInPalette(id) ? null : new AvatarIssue(component, $"avatar_{name}_unknown");
    }
}
