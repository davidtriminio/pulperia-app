using Pulperia.Application.Accounts;
using Pulperia.Application.Operations;
using Pulperia.Domain.Team;

namespace Pulperia.Application.Sync;

/// <summary>
/// La sincronización de un dispositivo con un negocio: recibe lotes de operaciones y devuelve el
/// resultado de cada una (RF-52). Es la única vía de escritura del móvil (D-4).
/// </summary>
public sealed class SyncService(OperationApplier applier, ISyncStore store, TimeProvider clock)
{
    private const string AppliedResult = "applied";
    private const char CodeSeparator = ',';

    /// <summary>Operaciones por lote, para que un envío no sea ilimitado (el móvil envía por tandas).</summary>
    public const int MaxBatchSize = 500;

    /// <summary>Registros por página de cambios si el dispositivo no pide un tamaño, y el máximo que se le da.</summary>
    public const int DefaultPageSize = 200;

    public const int MaxPageSize = 500;

    public const string Forbidden = "forbidden";
    public const string BatchTooLarge = "batch_too_large";
    public const string OpIdInUse = "op_id_in_use";

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
        // Quien fue quitado conserva su rol para este último lote: sus operaciones se juzgan igual.
        if (await store.FindMembershipAsync(userId, cancellationToken) is not { } membership)
        {
            return AccountResult<IReadOnlyList<OperationOutcome>>.Fail(Forbidden);
        }

        var actor = new OperationActor(userId, membership.Role);
        var outcomes = await store.InTransactionAsync(
            async () =>
            {
                // Un removido tiene un único lote (RF-12), sin límite de tiempo. Se reclama dentro de la
                // transacción del lote: si el lote falla, también se deshace y puede reintentar.
                if (membership.Status == MembershipStatus.Removed
                    && !await store.TryClaimFinalSyncAsync(userId, cancellationToken))
                {
                    return null;
                }
                await store.LockBusinessAsync(cancellationToken);
                var results = new List<OperationOutcome>(operations.Count);
                foreach (var operation in operations)
                {
                    results.Add(await ApplyAsync(operation, actor, cancellationToken));
                }
                return (IReadOnlyList<OperationOutcome>?)results;
            },
            cancellationToken);
        return outcomes is null
            ? AccountResult<IReadOnlyList<OperationOutcome>>.Fail(Forbidden)
            : AccountResult<IReadOnlyList<OperationOutcome>>.Ok(outcomes);
    }

    /// <summary>
    /// Los cambios del negocio posteriores al cursor, paginados (plan 4.3). Con cursor cero es la
    /// descarga inicial (RF-58). Solo para quien pertenece al negocio: un removido ya no lee sus
    /// datos (RF-11); su único acceso es el último lote de envío (RF-12).
    /// </summary>
    public async Task<AccountResult<ChangePage>> PullAsync(
        Guid userId, long cursor, int? limit, CancellationToken cancellationToken = default)
    {
        if (await store.FindMembershipAsync(userId, cancellationToken) is not { Status: MembershipStatus.Active })
        {
            return AccountResult<ChangePage>.Fail(Forbidden);
        }
        var size = Math.Clamp(limit ?? DefaultPageSize, 1, MaxPageSize);
        return AccountResult<ChangePage>.Ok(await store.ReadChangesAsync(cursor, size, cancellationToken));
    }

    /// <summary>
    /// Una operación ya procesada devuelve su resultado original sin tocar nada (RF-53); una nueva
    /// se aplica y se anota, con su resultado, en la misma transacción.
    /// </summary>
    private async Task<OperationOutcome> ApplyAsync(
        Operation operation, OperationActor actor, CancellationToken cancellationToken)
    {
        if (await store.FindProcessedOpAsync(operation.OpId, cancellationToken) is { } known)
        {
            // El mismo id en otro negocio no es un reenvío: no se aplica ni se cuenta nada de él.
            if (!known.InThisBusiness)
            {
                return OperationOutcome.Rejected(operation.OpId, [OpIdInUse]);
            }
            return known.Result == AppliedResult
                ? OperationOutcome.Duplicate(operation.OpId)
                : OperationOutcome.Rejected(operation.OpId, known.Result.Split(CodeSeparator));
        }

        var result = await applier.ApplyAsync(operation, actor, cancellationToken);
        await store.AddProcessedOpAsync(
            operation.OpId,
            result.IsApplied ? AppliedResult : string.Join(CodeSeparator, result.Details),
            clock.GetUtcNow().UtcDateTime,
            cancellationToken);
        return result.IsApplied
            ? OperationOutcome.Applied(operation.OpId)
            : OperationOutcome.Rejected(operation.OpId, result.Details);
    }
}
