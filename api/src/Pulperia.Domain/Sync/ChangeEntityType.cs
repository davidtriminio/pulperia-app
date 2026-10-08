namespace Pulperia.Domain.Sync;

/// <summary>
/// Tipo de registro de negocio que aparece en el registro de cambios (<c>change_log</c>) y que
/// los dispositivos reciben al sincronizar (RF-52).
/// </summary>
public enum ChangeEntityType
{
    Client,
    Product,
    Fiado,
    Payment,
}

public static class ChangeEntityTypes
{
    /// <summary>Identificador estable, el mismo de la base de datos y de la API.</summary>
    public static string Id(this ChangeEntityType type) => type switch
    {
        ChangeEntityType.Client => "client",
        ChangeEntityType.Product => "product",
        ChangeEntityType.Fiado => "fiado",
        ChangeEntityType.Payment => "payment",
        _ => throw new ArgumentOutOfRangeException(nameof(type)),
    };

    public static ChangeEntityType FromId(string id) => id switch
    {
        "client" => ChangeEntityType.Client,
        "product" => ChangeEntityType.Product,
        "fiado" => ChangeEntityType.Fiado,
        "payment" => ChangeEntityType.Payment,
        _ => throw new ArgumentException($"Tipo de entidad desconocido: {id}", nameof(id)),
    };
}
