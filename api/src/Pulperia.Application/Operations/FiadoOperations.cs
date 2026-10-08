using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Ledger;
using Pulperia.Domain.Quantities;

namespace Pulperia.Application.Operations;

/// <summary>
/// Creación de fiados, con ítems o solo con monto (RF-28 a RF-36, RF-49, RF-83 a RF-85, RF-87,
/// RF-88). Un fiado a un cliente archivado se acepta siempre: el servidor no puede saber si el
/// dispositivo conocía el archivado, y el cliente sigue archivado con el saldo actualizado (RF-85).
/// </summary>
internal static class FiadoOperations
{
    public static async Task<OperationResult> CreateAsync(
        IOperationStore store, Operation operation, OperationActor actor, CancellationToken cancellationToken)
    {
        var draft = ReadDraft(operation);

        if (CheckLimits(draft) is { } overLimit)
        {
            return overLimit;
        }
        if (draft.Items.Select(i => i.Id).Distinct().Count() != draft.Items.Count)
        {
            return OperationResult.Rejected(RejectionCodes.DuplicateItemId);
        }
        if (draft.Items.Any(i => i.Unit is null))
        {
            return OperationResult.Rejected(RejectionCodes.ItemUnitUnknown);
        }

        var modes = await store.GetModesAsync(cancellationToken);
        var validated = FiadoValidator.Validate(ToDomain(draft), modes.Amount, modes.Quantity);
        if (validated is InvalidFiado invalid)
        {
            return OperationResult.Rejected(invalid.Issues.Select(i => i.Code).Distinct().ToList());
        }
        if (CheckConsistency(draft, modes) is { } inconsistent)
        {
            return inconsistent;
        }

        if (await store.FindFiadoAsync(operation.EntityId, cancellationToken) is not null)
        {
            return OperationResult.Rejected(RejectionCodes.EntityAlreadyExists);
        }
        if (await store.FindClientAsync(draft.ClientId, cancellationToken) is null)
        {
            return OperationResult.Rejected(RejectionCodes.ClientNotFound);
        }
        foreach (var productId in draft.Items.Where(i => i.ProductId is not null).Select(i => i.ProductId!.Value).Distinct())
        {
            if (await store.FindProductAsync(productId, cancellationToken) is null)
            {
                return OperationResult.Rejected(RejectionCodes.ProductNotFound);
            }
        }
        if ((await store.FindExistingItemIdsAsync(draft.Items.Select(i => i.Id).ToList(), cancellationToken)).Count > 0)
        {
            return OperationResult.Rejected(RejectionCodes.EntityAlreadyExists);
        }

        var total = draft.Items.Count == 0
            ? new Money(draft.Total!.Value)
            : new Money(draft.Items.Sum(i => i.Subtotal));
        await store.AddFiadoAsync(
            new FiadoRecord(
                operation.EntityId, draft.ClientId, total, (draft.OccurredAt ?? operation.CreatedAt).UtcDateTime,
                actor.UserId, AnnulledAt: null, AnnulledBy: null,
                draft.Items.Select(i => new FiadoItemRecord(
                    i.Id, i.ProductId, i.Description, new Quantity(i.Quantity), i.Unit!.Value,
                    new Money(i.UnitPrice), new Money(i.Subtotal))).ToList()),
            cancellationToken);
        return OperationResult.Applied;
    }

    private sealed record ItemDraft(
        Guid Id, Guid? ProductId, string Description, long Quantity, SaleUnit? Unit, long UnitPrice, long Subtotal);

    private sealed record Draft(
        Guid ClientId, long? Total, DateTimeOffset? OccurredAt, IReadOnlyList<ItemDraft> Items);

    private static Draft ReadDraft(Operation operation)
    {
        var payload = Payload.Of(operation.Payload) ?? throw new InvalidPayloadException();
        var clientId = payload.Guid("clientId") ?? throw new InvalidPayloadException();
        var total = payload.Long("total");
        var items = (payload.Objects("items") ?? []).Select(ReadItem).ToList();
        // Con ítems el total viaja siempre; sin ítems ni total, el fiado está vacío (RF-33).
        if (items.Count > 0 && total is null)
        {
            throw new InvalidPayloadException();
        }
        return new Draft(clientId, total, payload.Date("occurredAt"), items);
    }

    private static ItemDraft ReadItem(Payload item) => new(
        item.Guid("id") ?? throw new InvalidPayloadException(),
        item.Guid("productId"),
        item.String("description") ?? "",
        item.Long("quantity") ?? throw new InvalidPayloadException(),
        item.String("unit") is { } unit ? SaleUnits.TryFromId(unit) : SaleUnit.Unit,
        item.Long("unitPrice") ?? throw new InvalidPayloadException(),
        item.Long("subtotal") ?? throw new InvalidPayloadException());

    /// <summary>Topes de D-26, antes de calcular nada para que ningún producto pueda desbordar.</summary>
    private static OperationResult? CheckLimits(Draft draft)
    {
        var codes = new List<string>();
        if (draft.Items.Count > LedgerLimits.MaxItemsPerFiado)
        {
            codes.Add(LedgerLimits.TooManyItems);
        }
        if (draft.Total > LedgerLimits.MaxAmountMinorUnits
            || draft.Items.Any(i => i.UnitPrice > LedgerLimits.MaxAmountMinorUnits
                                    || i.Subtotal > LedgerLimits.MaxAmountMinorUnits))
        {
            codes.Add(LedgerLimits.AmountTooLarge);
        }
        if (draft.Items.Any(i => i.Quantity > LedgerLimits.MaxQuantityMilli))
        {
            codes.Add(LedgerLimits.QuantityTooLarge);
        }
        if (draft.Items.Any(i => i.Description.Length > LedgerLimits.MaxDescriptionLength))
        {
            codes.Add(LedgerLimits.DescriptionTooLong);
        }
        return codes.Count == 0 ? null : OperationResult.Rejected(codes);
    }

    private static FiadoDraft ToDomain(Draft draft) => draft.Items.Count == 0
        ? new FiadoTotalOnly(draft.Total is { } total ? new Money(total) : null)
        : new FiadoWithItems(draft.Items.Select(i => new FiadoItemDraft(
            i.Description, i.ProductId?.ToString(), new Quantity(i.Quantity), new Money(i.UnitPrice), i.Unit!.Value)).ToList());

    /// <summary>
    /// El subtotal y el total que manda el dispositivo son el registro histórico (principio 4),
    /// pero deben ser coherentes: cada subtotal es cantidad por precio redondeado como lo hace el
    /// negocio. Si un dueño pasó de enteros a decimales mientras el dispositivo trabajaba sin
    /// conexión, el subtotal con el redondeo anterior también es válido.
    /// </summary>
    private static OperationResult? CheckConsistency(Draft draft, BusinessModes modes)
    {
        foreach (var item in draft.Items)
        {
            var quantity = new Quantity(item.Quantity);
            var price = new Money(item.UnitPrice);
            var accepted = new HashSet<long> { Subtotals.Of(modes.Amount, quantity, price).MinorUnits };
            if (modes.Amount == AmountMode.TwoDecimals)
            {
                accepted.Add(Subtotals.Of(AmountMode.Integer, quantity, price).MinorUnits);
            }
            if (!accepted.Contains(item.Subtotal))
            {
                return OperationResult.Rejected(RejectionCodes.SubtotalMismatch);
            }
        }

        return draft.Items.Count > 0 && draft.Total != draft.Items.Sum(i => i.Subtotal)
            ? OperationResult.Rejected(RejectionCodes.TotalMismatch)
            : null;
    }
}
