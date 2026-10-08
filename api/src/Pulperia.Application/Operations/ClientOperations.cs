using Pulperia.Domain.Clients;

namespace Pulperia.Application.Operations;

/// <summary>Operaciones de cliente: crear, editar con versión, archivar y restaurar (RF-14 a RF-23, RF-55, RF-73).</summary>
internal static class ClientOperations
{
    public static async Task<OperationResult> CreateAsync(
        IOperationStore store, Operation operation, OperationActor actor, CancellationToken cancellationToken)
    {
        var draft = ReadDraft(operation);
        if (Validate(draft) is { } rejection)
        {
            return rejection;
        }
        if (await store.FindClientAsync(operation.EntityId, cancellationToken) is not null)
        {
            return OperationResult.Rejected(RejectionCodes.EntityAlreadyExists);
        }

        var at = operation.CreatedAt.UtcDateTime;
        await store.AddClientAsync(
            new ClientRecord(
                operation.EntityId, draft.Name, draft.CharacterId!, draft.SkinId!, draft.BackgroundId!,
                draft.Phone, draft.Address, draft.Note, Archived: false, Version: 1, actor.UserId, at, at),
            cancellationToken);
        return OperationResult.Applied;
    }

    /// <summary>
    /// Edita nombre, avatar, teléfono, dirección y nota (RF-19). Solo si la versión base coincide
    /// con la del servidor: si no, gana el servidor (RF-55, D-8). No cambia si está archivado.
    /// </summary>
    public static async Task<OperationResult> UpdateAsync(
        IOperationStore store, Operation operation, CancellationToken cancellationToken)
    {
        var draft = ReadDraft(operation);
        if (operation.BaseVersion is null)
        {
            return OperationResult.Rejected(RejectionCodes.BaseVersionRequired);
        }
        if (await store.FindClientAsync(operation.EntityId, cancellationToken) is not { } current)
        {
            return OperationResult.Rejected(RejectionCodes.ClientNotFound);
        }
        if (Validate(draft) is { } rejection)
        {
            return rejection;
        }
        if (operation.BaseVersion != current.Version)
        {
            return OperationResult.Rejected(RejectionCodes.VersionConflict);
        }

        await store.UpdateClientAsync(
            current with
            {
                Name = draft.Name,
                CharacterId = draft.CharacterId!,
                SkinId = draft.SkinId!,
                BackgroundId = draft.BackgroundId!,
                Phone = draft.Phone,
                Address = draft.Address,
                Note = draft.Note,
                Version = current.Version + 1,
                UpdatedAt = operation.CreatedAt.UtcDateTime,
            },
            cancellationToken);
        return OperationResult.Applied;
    }

    /// <summary>
    /// Archiva o restaura (RF-20, RF-23). Es un estado al que se converge: archivar uno ya
    /// archivado, o restaurar uno activo, se acepta sin cambiar nada, y la versión base no se
    /// exige, porque el resultado es el mismo aunque otro dispositivo haya editado antes.
    /// </summary>
    public static async Task<OperationResult> SetArchivedAsync(
        IOperationStore store, Operation operation, bool archived, CancellationToken cancellationToken)
    {
        if (await store.FindClientAsync(operation.EntityId, cancellationToken) is not { } current)
        {
            return OperationResult.Rejected(RejectionCodes.ClientNotFound);
        }
        if (current.Archived == archived)
        {
            return OperationResult.Applied;
        }

        await store.UpdateClientAsync(
            current with { Archived = archived, Version = current.Version + 1, UpdatedAt = operation.CreatedAt.UtcDateTime },
            cancellationToken);
        return OperationResult.Applied;
    }

    private sealed record Draft(
        string Name, string? CharacterId, string? SkinId, string? BackgroundId,
        string? Phone, string? Address, string? Note);

    private static Draft ReadDraft(Operation operation)
    {
        var payload = Payload.Of(operation.Payload) ?? throw new InvalidPayloadException();
        return new Draft(
            payload.String("name")?.Trim() ?? "",
            payload.String("characterId"),
            payload.String("skinId"),
            payload.String("backgroundId"),
            BlankToNull(payload.String("phone")),
            BlankToNull(payload.String("address")),
            BlankToNull(payload.String("note")));
    }

    private static string? BlankToNull(string? value) => string.IsNullOrEmpty(value) ? null : value;

    private static OperationResult? Validate(Draft draft)
    {
        var result = ClientValidator.Validate(new ClientDraft(
            draft.Name, draft.Note, draft.Phone, draft.Address, draft.CharacterId, draft.SkinId, draft.BackgroundId));
        return result is InvalidClient invalid
            ? OperationResult.Rejected(invalid.Issues.Select(i => i.Code).Distinct().ToList())
            : null;
    }
}
