using Pulperia.Domain.Access;

namespace Pulperia.Application.Operations;

/// <summary>
/// Las operaciones que el servidor sabe aplicar y el permiso que exige cada una (RF-13, RF-21,
/// RF-45, RF-48). Es la única tabla: una operación que no está aquí no existe, y por eso no hay
/// forma de borrar un producto, un fiado ni un abono (RF-27, RF-46).
/// </summary>
public static class OperationCatalog
{
    private static readonly Dictionary<string, Permission> Required = new()
    {
        ["client.create"] = Permission.CreateClient,
        ["client.update"] = Permission.EditClient,
        ["client.archive"] = Permission.ArchiveClient,
        ["client.restore"] = Permission.RestoreClient,
        ["product.create"] = Permission.ManageCatalog,
        ["product.update"] = Permission.ManageCatalog,
        ["product.archive"] = Permission.ManageCatalog,
        ["fiado.create"] = Permission.RegisterFiado,
        ["fiado.annul"] = Permission.AnnulMovement,
        ["payment.create"] = Permission.RegisterPayment,
        ["payment.annul"] = Permission.AnnulMovement,
    };

    public static IReadOnlyCollection<string> Types => Required.Keys;

    /// <summary>El permiso que exige el tipo de operación, o null si no existe tal operación.</summary>
    public static Permission? RequiredPermission(string type) =>
        Required.TryGetValue(type, out var permission) ? permission : null;
}
