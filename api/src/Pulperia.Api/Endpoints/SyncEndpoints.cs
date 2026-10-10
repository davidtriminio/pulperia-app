using System.Text.Json;
using Pulperia.Application.Operations;
using Pulperia.Application.Sync;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Sync;
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
        sync.MapGet("/pull", PullAsync);

        // La web envía de una en una (D-4); solo quien es miembro activo: su último lote es cosa del móvil.
        app.MapPost("/api/operations", OperationAsync).RequireBusiness();
    }

    /// <summary>Un servicio de sincronización limitado al negocio de la petición (RNF-6).</summary>
    private static SyncService CreateService(PulperiaDbContext db, TimeProvider clock, Guid businessId)
    {
        db.WithBusiness(businessId);
        return new SyncService(new OperationApplier(new EfOperationStore(db)), new EfSyncStore(db), clock);
    }

    private static IResult Failure(IReadOnlyList<string> codes) => Http.Error(
        codes[0] switch
        {
            SyncService.Forbidden or "business_pending" or "business_suspended" => StatusCodes.Status403Forbidden,
            _ => StatusCodes.Status400BadRequest,
        },
        codes);

    private static async Task<IResult> PushAsync(HttpContext context, PulperiaDbContext db, TimeProvider clock)
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

        var result = await CreateService(db, clock, caller.BusinessId)
            .PushAsync(caller.UserId, operations, context.RequestAborted);
        return result.IsSuccess
            ? Results.Json(new { results = result.Value!.Select(Json) }, Http.Json)
            : Failure(result.Codes);
    }

    /// <summary>
    /// <c>POST /api/operations</c>: una operación de la web, aplicada con las mismas reglas y la misma
    /// idempotencia que las del móvil (RF-59, RF-60). Responde con su resultado, igual que cada
    /// elemento de <c>results</c> del lote. Sin <c>createdAt</c> toma la hora del servidor.
    /// </summary>
    private static async Task<IResult> OperationAsync(HttpContext context, PulperiaDbContext db, TimeProvider clock)
    {
        var active = context.GetActiveBusiness();
        if (await Http.ReadBodyAsync<OperationBody>(context) is not { OpId: { } opId, EntityId: { } entityId } body
            || opId == Guid.Empty || string.IsNullOrWhiteSpace(body.Type))
        {
            return Http.InvalidRequest();
        }

        var operation = new Operation(opId, body.Type, entityId, body.Payload, body.BaseVersion, body.CreatedAt ?? clock.GetUtcNow());
        var result = await CreateService(db, clock, active.BusinessId).PushAsync(active.UserId, [operation], context.RequestAborted);
        return result.IsSuccess ? Results.Json(Json(result.Value![0]), Http.Json) : Failure(result.Codes);
    }

    /// <summary>
    /// <c>GET /api/sync/pull?cursor=N&amp;limit=M</c>: lo que cambió después del <c>seq</c> N. Sin cursor es
    /// la descarga inicial (cursor cero). Responde <c>{ cursor, hasMore, changes: [{ seq, type, entity }] }</c>.
    /// </summary>
    private static async Task<IResult> PullAsync(HttpContext context, PulperiaDbContext db, TimeProvider clock)
    {
        var caller = context.GetBusinessCaller();
        var query = context.Request.Query;
        if (!TryReadNumber(query["cursor"], out var cursor) || cursor < 0
            || !TryReadNumber(query["limit"], out var limit) || limit <= 0)
        {
            return Http.InvalidRequest();
        }

        var result = await CreateService(db, clock, caller.BusinessId).PullAsync(
            caller.UserId, cursor ?? 0, limit is { } size ? (int)Math.Min(size, SyncService.MaxPageSize) : null,
            context.RequestAborted);
        return result.IsSuccess
            ? Results.Json(
                new
                {
                    cursor = result.Value!.Cursor,
                    hasMore = result.Value.HasMore,
                    changes = result.Value.Changes.Select(c => new { seq = c.Seq, type = c.Type.Id(), entity = EntityJson.Of(c) }),
                },
                Http.Json)
            : Failure(result.Codes);
    }

    /// <summary>Un parámetro numérico opcional: ausente es válido y queda en null; presente debe ser un entero.</summary>
    private static bool TryReadNumber(string? text, out long? value)
    {
        value = null;
        if (string.IsNullOrEmpty(text))
        {
            return true;
        }
        if (!long.TryParse(text, System.Globalization.NumberStyles.AllowLeadingSign, System.Globalization.CultureInfo.InvariantCulture, out var parsed))
        {
            return false;
        }
        value = parsed;
        return true;
    }

    private static object Json(OperationOutcome outcome) => outcome.Status switch
    {
        OutcomeStatus.Applied => new { opId = outcome.OpId, status = "applied" },
        OutcomeStatus.Duplicate => new { opId = outcome.OpId, status = "duplicate" },
        _ => new { opId = outcome.OpId, status = "rejected", code = outcome.Code, codes = outcome.Codes },
    };
}
