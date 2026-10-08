using Pulperia.Domain.Business;

namespace Pulperia.Domain.Amounts;

public static class AmountRules
{
    /// <summary>
    /// Regla común a todo monto ingresado (un total, un precio, un abono): debe ser
    /// positivo (RF-32, RF-38) y, con montos enteros, no tener centavos (RF-36).
    /// Devuelve null si el monto es válido.
    /// </summary>
    public static AmountError? Error(Money money, AmountMode mode)
    {
        if (!money.IsPositive)
        {
            return AmountError.NotPositive;
        }
        if (mode == AmountMode.Integer && money.MinorUnits % 100 != 0)
        {
            return AmountError.NotWhole;
        }
        return null;
    }
}
