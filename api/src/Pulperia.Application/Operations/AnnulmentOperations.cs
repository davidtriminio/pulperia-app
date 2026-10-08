namespace Pulperia.Application.Operations;

/// <summary>
/// Anulación de fiados y abonos (RF-43, RF-44, RF-46, RF-47, RF-49). El registro se conserva,
/// marcado con quién y cuándo lo anuló; no existe ninguna operación para editarlo ni borrarlo.
/// Anular algo ya anulado se acepta sin cambiar nada: el primer usuario y la primera fecha son
/// los que valen (idempotente, RF-53).
/// </summary>
internal static class AnnulmentOperations
{
    public static async Task<OperationResult> AnnulFiadoAsync(
        IOperationStore store, Operation operation, OperationActor actor, CancellationToken cancellationToken)
    {
        if (await store.FindFiadoAsync(operation.EntityId, cancellationToken) is not { } fiado)
        {
            return OperationResult.Rejected(RejectionCodes.FiadoNotFound);
        }
        if (fiado.AnnulledAt is not null)
        {
            return OperationResult.AppliedWithoutChange;
        }
        await store.AnnulFiadoAsync(fiado.Id, operation.CreatedAt.UtcDateTime, actor.UserId, cancellationToken);
        return OperationResult.Applied;
    }

    public static async Task<OperationResult> AnnulPaymentAsync(
        IOperationStore store, Operation operation, OperationActor actor, CancellationToken cancellationToken)
    {
        if (await store.FindPaymentAsync(operation.EntityId, cancellationToken) is not { } payment)
        {
            return OperationResult.Rejected(RejectionCodes.PaymentNotFound);
        }
        if (payment.AnnulledAt is not null)
        {
            return OperationResult.AppliedWithoutChange;
        }
        await store.AnnulPaymentAsync(payment.Id, operation.CreatedAt.UtcDateTime, actor.UserId, cancellationToken);
        return OperationResult.Applied;
    }
}
