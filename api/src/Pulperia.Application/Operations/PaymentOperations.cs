using Pulperia.Domain.Amounts;
using Pulperia.Domain.Ledger;

namespace Pulperia.Application.Operations;

/// <summary>
/// Creación de abonos (RF-37 a RF-39, RF-49, RF-75). Un abono mayor que la deuda se acepta y
/// deja saldo a favor; un cliente archivado admite abonos.
/// </summary>
internal static class PaymentOperations
{
    public static async Task<OperationResult> CreateAsync(
        IOperationStore store, Operation operation, OperationActor actor, CancellationToken cancellationToken)
    {
        var payload = Payload.Of(operation.Payload) ?? throw new InvalidPayloadException();
        var clientId = payload.Guid("clientId") ?? throw new InvalidPayloadException();
        var amount = payload.Long("amount") ?? throw new InvalidPayloadException();
        var occurredAt = payload.Date("occurredAt") ?? operation.CreatedAt;

        // El tope va antes de cualquier cálculo (D-26).
        if (amount > LedgerLimits.MaxAmountMinorUnits)
        {
            return OperationResult.Rejected(LedgerLimits.AmountTooLarge);
        }
        var modes = await store.GetModesAsync(cancellationToken);
        if (PaymentValidator.Validate(new Money(amount), modes.Amount) is InvalidPayment invalid)
        {
            return OperationResult.Rejected(invalid.Error.Code());
        }
        if (await store.FindPaymentAsync(operation.EntityId, cancellationToken) is not null)
        {
            return OperationResult.Rejected(RejectionCodes.EntityAlreadyExists);
        }
        if (await store.FindClientAsync(clientId, cancellationToken) is null)
        {
            return OperationResult.Rejected(RejectionCodes.ClientNotFound);
        }

        await store.AddPaymentAsync(
            new PaymentRecord(
                operation.EntityId, clientId, new Money(amount), occurredAt.UtcDateTime, actor.UserId,
                AnnulledAt: null, AnnulledBy: null),
            cancellationToken);
        return OperationResult.Applied;
    }
}
