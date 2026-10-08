using System.Security.Cryptography;

namespace Pulperia.Domain.Invitations;

/// <summary>
/// Códigos de invitación de un solo uso (RF-92, RF-93, D-28): 8 caracteres de un alfabeto sin
/// símbolos ambiguos (sin 0, O, 1, I ni L), pensados para dictarse o escribirse a mano. Se
/// muestran como <c>XXXX-XXXX</c>.
/// </summary>
public static class InvitationCodes
{
    public const string Alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    public const int Length = 8;

    /// <summary>Un código nuevo, al azar criptográfico y sin sesgo.</summary>
    public static string Generate() =>
        string.Create(Length, 0, static (span, _) =>
        {
            for (var i = 0; i < span.Length; i++)
            {
                span[i] = Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)];
            }
        });

    /// <summary>La forma para mostrar: <c>ABCD-EFGH</c>.</summary>
    public static string Format(string code) => $"{code[..4]}-{code[4..]}";

    /// <summary>
    /// El código tal como se guarda, a partir de lo que escribió la persona: sin mayúsculas, espacios
    /// ni guiones. Devuelve null si no tiene la forma de un código (largo o caracteres fuera del alfabeto).
    /// </summary>
    public static string? Normalize(string? typed)
    {
        if (string.IsNullOrWhiteSpace(typed))
        {
            return null;
        }
        var code = new string(typed.Where(c => !char.IsWhiteSpace(c) && c != '-').ToArray()).ToUpperInvariant();
        return code.Length == Length && code.All(c => Alphabet.Contains(c)) ? code : null;
    }
}
