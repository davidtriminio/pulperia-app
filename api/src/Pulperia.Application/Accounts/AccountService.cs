using Pulperia.Domain.Accounts;

namespace Pulperia.Application.Accounts;

/// <summary>Cuentas, negocios y sesiones. Cada rechazo lleva un código estable (RNF-5).</summary>
public sealed class AccountService(IAccountStore store, PasswordHasher hasher, TimeProvider clock)
{
    /// <summary>Crea la cuenta con su primer negocio y la asigna a él como dueño (RF-1, RF-2, RF-7, RF-78).</summary>
    public async Task<AccountResult<RegisteredAccount>> RegisterAsync(
        RegisterRequest request, CancellationToken cancellationToken = default)
    {
        var problems = AccountRules.ValidateRegistration(request.Email, request.Password, request.BusinessName);
        if (problems.Count > 0)
        {
            return AccountResult<RegisteredAccount>.Fail(problems);
        }

        var account = new NewAccount(
            Guid.CreateVersion7(),
            AccountRules.NormalizeEmail(request.Email),
            hasher.Hash(request.Password),
            Guid.CreateVersion7(),
            request.BusinessName.Trim(),
            request.AmountMode,
            request.QuantityMode,
            clock.GetUtcNow().UtcDateTime);

        return await store.TryCreateAccountAsync(account, cancellationToken)
            ? AccountResult<RegisteredAccount>.Ok(new RegisteredAccount(account.UserId, account.BusinessId))
            : AccountResult<RegisteredAccount>.Fail("email_taken");
    }
}
