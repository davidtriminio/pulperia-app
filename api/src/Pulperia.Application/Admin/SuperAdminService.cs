using Pulperia.Application.Accounts;
using Pulperia.Domain.Accounts;

namespace Pulperia.Application.Admin;

/// <summary>
/// Marcar y retirar la marca de super administrador (RF-95, D-29). Es una operación del
/// administrador del servidor: no hay endpoint ni pantalla que la haga.
/// </summary>
public sealed class SuperAdminService(IAdminStore store, TimeProvider clock)
{
    /// <summary>Marca a la cuenta; el rechazo trae el código estable (por ejemplo <c>already_super_admin</c>).</summary>
    public Task<AccountResult<Guid>> GrantAsync(
        string email, string performedBy, CancellationToken cancellationToken = default) =>
        SetAsync(email, grant: true, performedBy, cancellationToken);

    /// <summary>Le retira la marca; nunca al último super administrador (<c>last_super_admin</c>).</summary>
    public Task<AccountResult<Guid>> RevokeAsync(
        string email, string performedBy, CancellationToken cancellationToken = default) =>
        SetAsync(email, grant: false, performedBy, cancellationToken);

    private async Task<AccountResult<Guid>> SetAsync(
        string email, bool grant, string performedBy, CancellationToken cancellationToken)
    {
        var outcome = await store.SetSuperAdminAsync(
            AccountRules.NormalizeEmail(email), grant, performedBy, clock.GetUtcNow().UtcDateTime, cancellationToken);
        return outcome.UserId is { } userId
            ? AccountResult<Guid>.Ok(userId)
            : AccountResult<Guid>.Fail(outcome.Code!);
    }
}
