namespace Pulperia.Domain.Accounts;

/// <summary>Motivo por el que se rechaza suspender o reactivar una cuenta (RF-99).</summary>
public enum AccountSuspensionError
{
    ReasonRequired,
    AlreadySuspended,
    NotSuspended,
}

public static class AccountSuspensionErrors
{
    /// <summary>Código estable para los clientes (RNF-5).</summary>
    public static string Code(this AccountSuspensionError error) => error switch
    {
        AccountSuspensionError.ReasonRequired => "reason_required",
        AccountSuspensionError.AlreadySuspended => "account_already_suspended",
        AccountSuspensionError.NotSuspended => "account_not_suspended",
        _ => throw new ArgumentOutOfRangeException(nameof(error)),
    };
}

public readonly record struct AccountSuspensionChange(bool IsValid, AccountSuspensionError? Error)
{
    public static AccountSuspensionChange Ok() => new(true, null);

    public static AccountSuspensionChange Deny(AccountSuspensionError error) => new(false, error);
}

/// <summary>
/// Suspender una cuenta exige un motivo y solo vale para una cuenta que no lo está; reactivar solo
/// vale para una suspendida (RF-99).
/// </summary>
public static class AccountSuspensionRules
{
    public static AccountSuspensionChange Suspend(bool isSuspended, string? reason)
    {
        if (isSuspended)
        {
            return AccountSuspensionChange.Deny(AccountSuspensionError.AlreadySuspended);
        }
        return string.IsNullOrWhiteSpace(reason)
            ? AccountSuspensionChange.Deny(AccountSuspensionError.ReasonRequired)
            : AccountSuspensionChange.Ok();
    }

    public static AccountSuspensionChange Reactivate(bool isSuspended) =>
        isSuspended
            ? AccountSuspensionChange.Ok()
            : AccountSuspensionChange.Deny(AccountSuspensionError.NotSuspended);
}
