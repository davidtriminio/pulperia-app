using Pulperia.Application.Queries;
using Pulperia.Domain.Access;
using Pulperia.Domain.Ledger;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Queries;

namespace Pulperia.Api.Endpoints;

/// <summary>
/// Consultas de lectura de la web (plan 5), siempre sobre el negocio de <c>X-Business-Id</c>. Las
/// ve cualquier miembro activo con el permiso de lectura del rol (RF-48).
/// </summary>
internal static class QueryEndpoints
{
    public static void MapQueryEndpoints(this WebApplication app)
    {
        var clients = app.MapGroup("/api/clients").RequireBusiness().RequirePermission(Permission.ViewClients);
        clients.MapGet("", ListClientsAsync);
        clients.MapGet("/{id:guid}", GetClientAsync);

        app.MapGet("/api/summary", SummaryAsync).RequireBusiness().RequirePermission(Permission.ViewSummary);

        // Ver el catálogo no tiene permiso propio: todo miembro lo necesita para fiar (RF-48).
        app.MapGet("/api/products", ListProductsAsync).RequireBusiness();
    }

    private static QueryService CreateService(PulperiaDbContext db, Guid businessId) =>
        new(new EfQueryStore(db.WithBusiness(businessId)));

    /// <summary>El filtro <c>?archived=</c>: ausente es falso; solo <c>true</c> y <c>false</c> son válidos.</summary>
    private static bool TryReadArchived(HttpContext context, out bool archived)
    {
        archived = false;
        var text = context.Request.Query["archived"].ToString();
        if (text.Length == 0)
        {
            return true;
        }
        return bool.TryParse(text, out archived);
    }

    private static string Label(Balance balance) => balance.Label.Id();

    private static Dictionary<string, object?> WithBalance(Dictionary<string, object?> client, Balance balance)
    {
        client["balance"] = balance.Amount.MinorUnits;
        client["balanceLabel"] = Label(balance);
        return client;
    }

    private static async Task<IResult> ListClientsAsync(HttpContext context, PulperiaDbContext db)
    {
        if (!TryReadArchived(context, out var archived))
        {
            return Http.InvalidRequest();
        }
        var list = await CreateService(db, context.GetActiveBusiness().BusinessId).ListClientsAsync(archived, context.RequestAborted);
        return Results.Json(list.Select(c => WithBalance(EntityJson.Client(c.Client), c.Balance)).ToList(), Http.Json);
    }

    private static async Task<IResult> GetClientAsync(HttpContext context, PulperiaDbContext db, Guid id)
    {
        var history = await CreateService(db, context.GetActiveBusiness().BusinessId).GetClientAsync(id, context.RequestAborted);
        if (history is null)
        {
            return Http.Error(StatusCodes.Status404NotFound, "client_not_found");
        }
        var detail = WithBalance(EntityJson.Client(history.Client), history.Balance);
        detail["movements"] = history.Entries.Select(Movement).ToList();
        return Results.Json(detail, Http.Json);
    }

    private static Dictionary<string, object?> Movement(HistoryEntry e)
    {
        var movement = new Dictionary<string, object?>
        {
            ["kind"] = e.Kind == MovementKind.Fiado ? "fiado" : "payment",
            ["id"] = e.Id, ["amount"] = e.Amount.MinorUnits, ["occurredAt"] = e.OccurredAt, ["serverSeq"] = e.ServerSeq,
            ["createdBy"] = e.CreatedBy, ["annulledAt"] = e.AnnulledAt, ["annulledBy"] = e.AnnulledBy,
        };
        if (e.Kind == MovementKind.Fiado)
        {
            movement["items"] = e.Items.Select(EntityJson.Item).ToList();
        }
        return movement;
    }

    /// <summary>
    /// <c>GET /api/summary?limit=N</c>: deuda total, saldo a favor total y los clientes que más deben
    /// (RF-63 a RF-65). Sin <c>limit</c> trae a todos; con él, solo los N mayores.
    /// </summary>
    private static async Task<IResult> SummaryAsync(HttpContext context, PulperiaDbContext db)
    {
        int? limit = null;
        var text = context.Request.Query["limit"].ToString();
        if (text.Length > 0)
        {
            if (!int.TryParse(text, System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out var parsed) || parsed <= 0)
            {
                return Http.InvalidRequest();
            }
            limit = parsed;
        }

        var summary = await CreateService(db, context.GetActiveBusiness().BusinessId).SummaryAsync(limit, context.RequestAborted);
        return Results.Json(
            new
            {
                debtTotal = summary.DebtTotal.MinorUnits,
                creditTotal = summary.CreditTotal.MinorUnits,
                debtors = summary.Debtors.Select(d => new { clientId = d.ClientId, name = d.Name, debt = d.Debt.MinorUnits }).ToList(),
            },
            Http.Json);
    }

    private static async Task<IResult> ListProductsAsync(HttpContext context, PulperiaDbContext db)
    {
        if (!TryReadArchived(context, out var archived))
        {
            return Http.InvalidRequest();
        }
        var list = await CreateService(db, context.GetActiveBusiness().BusinessId).ListProductsAsync(archived, context.RequestAborted);
        return Results.Json(list.Select(EntityJson.Product).ToList(), Http.Json);
    }
}
