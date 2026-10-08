using Pulperia.Domain.Amounts;
using Pulperia.Domain.Catalog;

namespace Pulperia.Application.Operations;

/// <summary>
/// Operaciones de producto: crear, editar (nombre, precio, unidad) y archivar (RF-24 a RF-27,
/// RF-86). No existe una operación para borrar un producto (RF-27). Cambiar el precio jamás
/// toca los ítems de fiado ya registrados (RF-25, principio 4): viven en otra tabla y la
/// operación no los consulta.
/// </summary>
internal static class ProductOperations
{
    public static async Task<OperationResult> CreateAsync(
        IOperationStore store, Operation operation, OperationActor actor, CancellationToken cancellationToken)
    {
        var draft = ReadDraft(operation);
        var valid = await ValidateAsync(store, draft, cancellationToken);
        if (valid.Rejection is not null)
        {
            return valid.Rejection;
        }
        if (await store.FindProductAsync(operation.EntityId, cancellationToken) is not null)
        {
            return OperationResult.Rejected(RejectionCodes.EntityAlreadyExists);
        }

        await store.AddProductAsync(
            new ProductRecord(
                operation.EntityId, valid.Product!.Name, valid.Product.Price, valid.Product.Unit,
                PreviousPrice: null, PriceChangedAt: null, Archived: false, Version: 1,
                actor.UserId, operation.CreatedAt.UtcDateTime),
            cancellationToken);
        return OperationResult.Applied;
    }

    /// <summary>Edita nombre, precio y unidad; solo si la versión base coincide con la del servidor (D-8).</summary>
    public static async Task<OperationResult> UpdateAsync(
        IOperationStore store, Operation operation, CancellationToken cancellationToken)
    {
        var draft = ReadDraft(operation);
        if (operation.BaseVersion is null)
        {
            return OperationResult.Rejected(RejectionCodes.BaseVersionRequired);
        }
        if (await store.FindProductAsync(operation.EntityId, cancellationToken) is not { } current)
        {
            return OperationResult.Rejected(RejectionCodes.ProductNotFound);
        }
        var valid = await ValidateAsync(store, draft, cancellationToken);
        if (valid.Rejection is not null)
        {
            return valid.Rejection;
        }
        if (operation.BaseVersion != current.Version)
        {
            return OperationResult.Rejected(RejectionCodes.VersionConflict);
        }

        await store.UpdateProductAsync(
            current with
            {
                Name = valid.Product!.Name,
                Price = valid.Product.Price,
                Unit = valid.Product.Unit,
                Version = current.Version + 1,
            },
            cancellationToken);
        return OperationResult.Applied;
    }

    /// <summary>
    /// Archiva un producto (RF-26): deja de ofrecerse, pero conserva nombre y precio. Archivar
    /// uno ya archivado se acepta sin cambiar nada; la versión base no se exige, igual que en
    /// los clientes.
    /// </summary>
    public static async Task<OperationResult> ArchiveAsync(
        IOperationStore store, Operation operation, CancellationToken cancellationToken)
    {
        if (await store.FindProductAsync(operation.EntityId, cancellationToken) is not { } current)
        {
            return OperationResult.Rejected(RejectionCodes.ProductNotFound);
        }
        if (current.Archived)
        {
            return OperationResult.Applied;
        }

        await store.UpdateProductAsync(current with { Archived = true, Version = current.Version + 1 }, cancellationToken);
        return OperationResult.Applied;
    }

    private sealed record Draft(string Name, long Price, string? Unit);

    private static Draft ReadDraft(Operation operation)
    {
        var payload = Payload.Of(operation.Payload) ?? throw new InvalidPayloadException();
        var name = payload.String("name") ?? "";
        var price = payload.Long("price") ?? throw new InvalidPayloadException();
        return new Draft(name, price, payload.String("unit"));
    }

    private static async Task<(ValidProduct? Product, OperationResult? Rejection)> ValidateAsync(
        IOperationStore store, Draft draft, CancellationToken cancellationToken)
    {
        var modes = await store.GetModesAsync(cancellationToken);
        var result = ProductValidator.Validate(draft.Name, new Money(draft.Price), modes.Amount, draft.Unit);
        return result switch
        {
            ValidProduct valid => (valid, null),
            InvalidProduct invalid => (null, OperationResult.Rejected(invalid.Issues.Select(i => i.Code).Distinct().ToList())),
            _ => throw new InvalidOperationException(),
        };
    }
}
