using System.Text.RegularExpressions;

namespace Pulperia.Domain.Accounts;

/// <summary>Reglas de una cuenta nueva: correo, contraseña y nombre del negocio (RF-1, RF-2, RF-78, D-27).</summary>
public static class AccountRules
{
    public const int MinPasswordLength = 8;
    public const int MaxPasswordLength = 128;

    // Forma básica: algo@algo, sin espacios ni un segundo @. \z y no $ (en .NET $ acepta un salto final).
    private static readonly Regex EmailShape = new(@"^[^@\s]+@[^@\s]+\z", RegexOptions.CultureInvariant);

    /// <summary>El usuario se identifica por su correo (RF-2): recortado y en minúsculas.</summary>
    public static string NormalizeEmail(string? email) => (email ?? "").Trim().ToLowerInvariant();

    /// <summary>Recibe un correo ya normalizado.</summary>
    public static bool IsValidEmail(string normalizedEmail) => EmailShape.IsMatch(normalizedEmail);

    public static string? PasswordError(string? password) => (password?.Length ?? 0) switch
    {
        < MinPasswordLength => "password_too_short",
        > MaxPasswordLength => "password_too_long",
        _ => null,
    };

    /// <summary>El nombre es obligatorio (RF-78).</summary>
    public static string? BusinessNameError(string? name) =>
        string.IsNullOrWhiteSpace(name) ? "business_name_required" : null;

    /// <summary>Todos los problemas de un registro, en el orden correo, contraseña y negocio.</summary>
    public static IReadOnlyList<string> ValidateRegistration(string? email, string? password, string? businessName)
    {
        var codes = new List<string>();
        if (!IsValidEmail(NormalizeEmail(email)))
        {
            codes.Add("email_invalid");
        }
        if (PasswordError(password) is { } passwordError)
        {
            codes.Add(passwordError);
        }
        if (BusinessNameError(businessName) is { } nameError)
        {
            codes.Add(nameError);
        }
        return codes;
    }
}
