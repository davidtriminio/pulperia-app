using Pulperia.Domain.Business;

namespace Pulperia.Application.Accounts;

/// <summary>Una cuenta nueva con su primer negocio, que se guarda entera o no se guarda.</summary>
public sealed record NewAccount(
    Guid UserId,
    string Email,
    string PasswordHash,
    Guid BusinessId,
    string BusinessName,
    AmountMode AmountMode,
    QuantityMode QuantityMode,
    DateTime CreatedAt);

/// <summary>
/// Lo que el servicio de cuentas necesita de la base de datos. Las cuentas, los negocios y las
/// sesiones no están limitados a un negocio: son anteriores a elegir uno.
/// </summary>
public interface IAccountStore
{
    /// <summary>
    /// Crea el usuario, el negocio y la pertenencia de dueño en una sola transacción. Devuelve
    /// false, sin crear nada, si el correo ya está registrado.
    /// </summary>
    Task<bool> TryCreateAccountAsync(NewAccount account, CancellationToken cancellationToken = default);
}
