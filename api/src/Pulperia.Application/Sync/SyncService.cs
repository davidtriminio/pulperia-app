using Pulperia.Application.Accounts;
using Pulperia.Application.Operations;
using Pulperia.Domain.Team;

namespace Pulperia.Application.Sync;

/// <summary>
/// La sincronización de un dispositivo con un negocio: recibe lotes de operaciones y devuelve el
/// resultado de cada una (RF-52). Es la única vía de escritura del móvil (D-4).
/// </summary>
public sealed class SyncService(OperationApplier applier, ISyncStore store)
{
    /// <summary>Operaciones por lote, para que un envío no sea ilimitado (el móvil envía por tandas).</summary>
    public const int MaxBatchSize = 500;

    public const string Forbidden = "forbidden";
    public const string BatchTooLarge = "batch_too_large";

    /// <summary>
    /// Aplica el lote en orden y en una sola transacción con el negocio bloqueado (plan 4.2): o se
    /// guarda todo el lote con sus resultados, o nada y el dispositivo reenvía el mismo lote. Una
    /// operación mala se rechaza sin impedir las demás.
    /// </summary>
    public async Task<AccountResult<IReadOnlyList<OperationOutcome>>> PushAsync(
        Guid userId, IReadOnlyList<Operation> operations, CancellationToken cancellationToken = default)
    {
        if (operations.Count > MaxBatchSize)
        {
            return AccountResult<IReadOnlyList<OperationOutcome>>.Fail(BatchTooLarge);
        }
        if (await store.FindMembershipAsync(userId, cancellationToken) is not { Status: MembershipStatus.Active } membership)
        {
            return AccountResult<IReadOnlyList<OperationOutcome>>.Fail(Forbidden);
        }

        var actor = new OperationActor(userId, membership.Role);
        var outcomes = await store.InTransactionAsync(
            async () =>
            {
                await store.LockBusinessAsync(cancellationToken);
                var results = new List<OperationOutcome>(operations.Count);
                foreach (var operation in operations)
                {
                    results.Add(await ApplyAsync(operation, actor, cancellationToken));
                }
                return (IReadOnlyList<OperationOutcome>)results;
            },
            cancellationToken);
        return AccountResult<IReadOnlyList<OperationOutcome>>.Ok(outcomes);
    }

    private async Task<OperationOutcome> ApplyAsync(
        Operation operation, OperationActor actor, CancellationToken cancellationToken)
    {
        var result = await applier.ApplyAsync(operation, actor, cancellationToken);
        return result.IsApplied
            ? OperationOutcome.Applied(operation.OpId)
            : OperationOutcome.Rejected(operation.OpId, result.Details);
    }
}
