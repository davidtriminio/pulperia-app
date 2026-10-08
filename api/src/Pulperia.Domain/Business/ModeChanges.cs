namespace Pulperia.Domain.Business;

/// <summary>Motivo por el que se rechaza un cambio de modo del negocio.</summary>
public enum ModeChangeError
{
    DowngradeNotAllowed,
}

public static class ModeChangeErrors
{
    /// <summary>Código estable, el mismo de los vectores compartidos.</summary>
    public static string Code(this ModeChangeError error) => error switch
    {
        ModeChangeError.DowngradeNotAllowed => "mode_downgrade_not_allowed",
        _ => throw new ArgumentOutOfRangeException(nameof(error)),
    };
}

public readonly record struct ModeChangeResult(bool Allowed, ModeChangeError? Error)
{
    public static ModeChangeResult Allow() => new(true, null);

    public static ModeChangeResult Deny(ModeChangeError error) => new(false, error);
}

public static class ModeChanges
{
    /// <summary>
    /// Cambiar el modo de montos: solo se puede pasar de enteros a 2 decimales (RF-8), nunca al
    /// revés (RF-9). Pedir el mismo modo no cambia nada y se permite. El servidor es la única
    /// autoridad (D-3): ni el móvil ni la web pueden saltarse esta regla.
    /// </summary>
    public static ModeChangeResult ChangeAmountMode(AmountMode current, AmountMode requested) =>
        current == AmountMode.TwoDecimals && requested == AmountMode.Integer
            ? ModeChangeResult.Deny(ModeChangeError.DowngradeNotAllowed)
            : ModeChangeResult.Allow();

    /// <summary>
    /// Cambiar el modo de cantidades: solo se puede pasar de enteras a fraccionarias (RF-8),
    /// nunca al revés (RF-9). Pedir el mismo modo no cambia nada y se permite.
    /// </summary>
    public static ModeChangeResult ChangeQuantityMode(QuantityMode current, QuantityMode requested) =>
        current == QuantityMode.Fractional && requested == QuantityMode.Integer
            ? ModeChangeResult.Deny(ModeChangeError.DowngradeNotAllowed)
            : ModeChangeResult.Allow();
}
