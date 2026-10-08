namespace Pulperia.Domain.Business;

/// <summary>Cómo maneja los montos un negocio: lempiras enteros o con 2 decimales.</summary>
public enum AmountMode
{
    Integer,
    TwoDecimals,
}

/// <summary>Cómo mide las cantidades un negocio: solo unidades enteras o con fracciones.</summary>
public enum QuantityMode
{
    Integer,
    Fractional,
}

public static class AmountModes
{
    /// <summary>Identificador estable, el mismo de los vectores compartidos y de la API.</summary>
    public static string Id(this AmountMode mode) => mode switch
    {
        AmountMode.Integer => "integer",
        AmountMode.TwoDecimals => "two_decimals",
        _ => throw new ArgumentOutOfRangeException(nameof(mode)),
    };

    public static AmountMode FromId(string id) => id switch
    {
        "integer" => AmountMode.Integer,
        "two_decimals" => AmountMode.TwoDecimals,
        _ => throw new ArgumentException($"Modo de monto desconocido: {id}", nameof(id)),
    };
}

public static class QuantityModes
{
    /// <summary>Identificador estable, el mismo de los vectores compartidos y de la API.</summary>
    public static string Id(this QuantityMode mode) => mode switch
    {
        QuantityMode.Integer => "integer",
        QuantityMode.Fractional => "fractional",
        _ => throw new ArgumentOutOfRangeException(nameof(mode)),
    };

    public static QuantityMode FromId(string id) => id switch
    {
        "integer" => QuantityMode.Integer,
        "fractional" => QuantityMode.Fractional,
        _ => throw new ArgumentException($"Modo de cantidad desconocido: {id}", nameof(id)),
    };
}
