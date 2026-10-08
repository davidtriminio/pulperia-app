using System.Text.Json;
using Pulperia.Application.Operations;
using Pulperia.Application.Sync;
using Pulperia.Infrastructure.Operations;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Sync;

namespace Pulperia.Api.Endpoints;

/// <summary>
/// Sincronización del móvil con el negocio de <c>X-Business-Id</c>: enviar un lote de operaciones
/// y pedir los cambios por cursor (RF-52). La pertenencia la decide el servicio, no el filtro.
/// </summary>
internal static class SyncEndpoints
{
    private sealed record PushBody(List<OperationBody?>? Operations);

    private sealed record OperationBody(
        Guid? OpId, string? Type, Guid? EntityId, JsonElement Payload, int? BaseVersion, DateTimeOffset? CreatedAt);

    public static void MapSyncEndpoints(this WebApplication app)
    {
        var sync = app.MapGroup("/api/sync").RequireBusinessCaller();
        sync.MapPost("/push", PushAsync);
    }

    /// <summary>Un servicio de sincronización limitado al negocio de la petición (RNF-6).</summary>
    private static SyncService CreateService(PulperiaDbContext db, Guid businessId)
    {
        db.WithBusiness(businessId);
        return new SyncService(new OperationApplier(new EfOperationStore(db)), new EfSyncStore(db));
    }

    private static IResult Failure(IReadOnlyList<string> codes) => Http.Error(
        codes[0] switch
        {
            SyncService.Forbidden => StatusCodes.Status403Forbidden,
            _ => StatusCodes.Status400BadRequest,
        },
        codes);

    private static async Task<IResult> PushAsync(HttpContext context, PulperiaDbContext db)
    {
        var caller = context.GetBusinessCaller();
        if (await Http.ReadBodyAsync<PushBody>(context) is not { Operations: { } items })
        {
            return Http.InvalidRequest();
        }

        var operations = new List<Operation>(items.Count);
        foreach (var item in items)
        {
            if (item is not { OpId: { } opId, EntityId: { } entityId, CreatedAt: { } createdAt }
                || opId == Guid.Empty || string.IsNullOrWhiteSpace(item.Type))
            {
                return Http.InvalidRequest();
            }
            operations.Add(new Operation(opId, item.Type, entityId, item.Payload, item.BaseVersion, createdAt));
        }

        var result = await CreateService(db, caller.BusinessId)
            .PushAsync(caller.UserId, operations, context.RequestAborted);
        return result.IsSuccess
            ? Results.Json(new { results = result.Value!.Select(Json) }, Http.Json)
            : Failure(result.Codes);
    }

    private static object Json(OperationOutcome outcome) => outcome.Status switch
    {
        OutcomeStatus.Applied => new { opId = outcome.OpId, status = "applied" },
        OutcomeStatus.Duplicate => new { opId = outcome.OpId, status = "duplicate" },
        _ => new { opId = outcome.OpId, status = "rejected", code = outcome.Code, codes = outcome.Codes },
    };
}
