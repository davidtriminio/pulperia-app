using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;

namespace Pulperia.Domain.Ledger;

public abstract record PaymentValidationResult;

public sealed record ValidPayment(Money Amount) : PaymentValidationResult;

public sealed record InvalidPayment(AmountError Error) : PaymentValidationResult;

public static class PaymentValidator
{
    /// <summary>
    /// Valida un abono (RF-37, RF-38): el monto debe ser positivo y, con montos enteros,
    /// sin centavos (RF-36). No recibe el saldo del cliente: un abono mayor que la deuda
    /// es válido y deja saldo a favor (RF-39).
    /// </summary>
    public static PaymentValidationResult Validate(Money amount, AmountMode amountMode)
    {
        var error = AmountRules.Error(amount, amountMode);
        return error is null ? new ValidPayment(amount) : new InvalidPayment(error.Value);
    }
}
