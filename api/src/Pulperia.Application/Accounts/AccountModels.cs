using Pulperia.Domain.Access;
using Pulperia.Domain.Business;

namespace Pulperia.Application.Accounts;

/// <summary>Lo que se pide para crear una cuenta con su primer negocio (RF-1, RF-7).</summary>
public sealed record RegisterRequest(
    string Email,
    string Password,
    string BusinessName,
    AmountMode AmountMode,
    QuantityMode QuantityMode);

public sealed record RegisteredAccount(Guid UserId, Guid BusinessId);

/// <summary>Resultado de una operación de cuentas: el valor, o los códigos estables del rechazo (RNF-5).</summary>
public sealed record AccountResult<T>
{
    private AccountResult(T? value, IReadOnlyList<string> codes)
    {
        Value = value;
        Codes = codes;
    }

    public T? Value { get; }

    public IReadOnlyList<string> Codes { get; }

    public bool IsSuccess => Codes.Count == 0;

    public static AccountResult<T> Ok(T value) => new(value, []);

    public static AccountResult<T> Fail(params string[] codes) => new(default, codes);

    public static AccountResult<T> Fail(IReadOnlyList<string> codes) => new(default, codes);
}

/// <summary>Un negocio del usuario con el rol que tiene en él (RF-5, RF-6).</summary>
public sealed record BusinessSummary(
    Guid Id,
    string Name,
    Role Role,
    AmountMode AmountMode,
    QuantityMode QuantityMode,
    BusinessStatus Status = BusinessStatus.Active);
