using System.Security.Cryptography;

namespace Pulperia.Application.Accounts;

public readonly record struct PasswordCheck(bool IsValid, bool NeedsRehash);

/// <summary>
/// Hash de contraseñas con PBKDF2-HMAC-SHA256 del BCL, sin paquetes (D-27). Formato guardado:
/// <c>pbkdf2-sha256$iteraciones$sal$hash</c>, con sal y hash en base64.
/// </summary>
public sealed class PasswordHasher(int iterations = PasswordHasher.DefaultIterations)
{
    public const int DefaultIterations = 600_000;

    private const string Algorithm = "pbkdf2-sha256";
    private const int SaltBytes = 16;
    private const int HashBytes = 32;

    public string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltBytes);
        var hash = Derive(password, salt, iterations);
        return $"{Algorithm}${iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }

    /// <summary>
    /// Comprueba la contraseña contra un hash guardado, en tiempo constante. Un hash mal formado
    /// no verifica (nunca lanza). <c>NeedsRehash</c> avisa de un hash con menos iteraciones que
    /// las vigentes, para renovarlo en el siguiente inicio de sesión.
    /// </summary>
    public PasswordCheck Verify(string storedHash, string password)
    {
        var parts = storedHash.Split('$');
        if (parts.Length != 4 || parts[0] != Algorithm
            || !int.TryParse(parts[1], out var storedIterations) || storedIterations < 1
            || !TryFromBase64(parts[2], out var salt) || !TryFromBase64(parts[3], out var expected)
            || expected.Length != HashBytes)
        {
            return new PasswordCheck(false, false);
        }

        var actual = Derive(password, salt, storedIterations);
        var valid = CryptographicOperations.FixedTimeEquals(actual, expected);
        return new PasswordCheck(valid, valid && storedIterations < iterations);
    }

    private static byte[] Derive(string password, byte[] salt, int iterations) =>
        Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, HashBytes);

    private static bool TryFromBase64(string text, out byte[] bytes)
    {
        try
        {
            bytes = Convert.FromBase64String(text);
            return bytes.Length > 0;
        }
        catch (FormatException)
        {
            bytes = [];
            return false;
        }
    }
}
