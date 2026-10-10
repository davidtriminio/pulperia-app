using System.Security.Cryptography;
using Pulperia.Application.Accounts;
using Pulperia.Domain.Accounts;

namespace Pulperia.Application.Admin;

/// <summary>
/// Lo que el comando de restablecimiento necesita de la base de datos. No toca nada de los
/// negocios (RF-82).
/// </summary>
public interface IAdminStore
{
    /// <summary>
    /// En una sola transacción: cambia el hash de la cuenta, cierra sus sesiones abiertas y
    /// escribe en <c>admin_audit</c> quién lo hizo y cuándo (RF-81). Devuelve el id de la cuenta,
    /// o null, sin cambiar nada, si no existe.
    /// </summary>
    Task<Guid?> ResetPasswordAsync(
        string normalizedEmail, string newPasswordHash, string performedBy, DateTime at,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// En una sola transacción y con las marcas serializadas: aplica las reglas de
    /// <c>SuperAdminRules</c>, cambia la marca de la cuenta y escribe en <c>admin_audit</c> (RF-95,
    /// RF-101). Si no se puede, no cambia ni audita nada y devuelve el código del rechazo
    /// (<c>account_not_found</c> o el de <c>SuperAdminError</c>).
    /// </summary>
    Task<SuperAdminOutcome> SetSuperAdminAsync(
        string normalizedEmail, bool grant, string performedBy, DateTime at,
        CancellationToken cancellationToken = default);
}

/// <summary>Cómo terminó marcar o retirar la marca: el id de la cuenta, o el código del rechazo.</summary>
public sealed record SuperAdminOutcome(Guid? UserId, string? Code)
{
    public static SuperAdminOutcome Done(Guid userId) => new(userId, null);

    public static SuperAdminOutcome Fail(string code) => new(null, code);
}

/// <summary>
/// Restablece la contraseña de una cuenta a una nueva generada al azar, que se entrega una sola
/// vez (D-19). Es una operación del administrador del servidor: no hay endpoint ni pantalla.
/// </summary>
public sealed class PasswordResetService(IAdminStore store, PasswordHasher hasher, TimeProvider clock)
{
    // Sin 0/O ni 1/l/I: la contraseña se la dicta el administrador al usuario.
    private const string Alphabet = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
    private const int Length = 16;

    /// <summary>La contraseña nueva, o <c>account_not_found</c> si no hay una cuenta con ese correo.</summary>
    public async Task<AccountResult<string>> ResetPasswordAsync(
        string email, string performedBy, CancellationToken cancellationToken = default)
    {
        var password = NewPassword();
        var userId = await store.ResetPasswordAsync(
            AccountRules.NormalizeEmail(email), hasher.Hash(password), performedBy,
            clock.GetUtcNow().UtcDateTime, cancellationToken);
        return userId is null
            ? AccountResult<string>.Fail("account_not_found")
            : AccountResult<string>.Ok(password);
    }

    private static string NewPassword() =>
        string.Create(Length, 0, static (span, _) =>
        {
            for (var i = 0; i < span.Length; i++)
            {
                span[i] = Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)];
            }
        });
}
