using System.Text.Json;
using Pulperia.Domain.Access;

namespace Pulperia.Application.Operations;

/// <summary>
/// Una operación tal como la envía un dispositivo (plan 4.1): qué hacer, sobre qué entidad, con
/// qué datos y, si edita, sobre qué versión. Es la única vía de escritura del servidor (D-4).
/// </summary>
/// <param name="OpId">Identificador de la operación; la idempotencia por <c>op_id</c> es de la sincronización (T075).</param>
/// <param name="Type">Por ejemplo <c>client.create</c> o <c>fiado.annul</c>.</param>
/// <param name="EntityId">Id del cliente, producto, fiado o abono sobre el que actúa.</param>
/// <param name="Payload">Los datos de la operación, en JSON (camelCase, como los encola el móvil).</param>
/// <param name="BaseVersion">Versión de la entidad sobre la que se hizo una edición (D-8).</param>
/// <param name="CreatedAt">Cuándo se creó la operación en el dispositivo (D-18); es la fecha de lo que registra.</param>
public sealed record Operation(
    Guid OpId,
    string Type,
    Guid EntityId,
    JsonElement Payload,
    int? BaseVersion,
    DateTimeOffset CreatedAt);

/// <summary>Quién envía la operación: el usuario autenticado y su rol en el negocio (RF-49).</summary>
public sealed record OperationActor(Guid UserId, Role Role);

/// <summary>
/// Lo que pasó con una operación: se aplicó o se rechazó con un código estable que los clientes
/// traducen a español (RNF-5).
/// </summary>
public sealed record OperationResult
{
    private static readonly IReadOnlyList<string> NoDetails = [];

    private OperationResult(string? code, IReadOnlyList<string> details)
    {
        Code = code;
        Details = details;
    }

    public static OperationResult Applied { get; } = new(null, NoDetails);

    public bool IsApplied => Code is null;

    /// <summary>Código del rechazo; null si se aplicó.</summary>
    public string? Code { get; }

    /// <summary>Todos los problemas encontrados, cuando son varios (el primero es <see cref="Code"/>).</summary>
    public IReadOnlyList<string> Details { get; }

    public static OperationResult Rejected(string code) => new(code, [code]);

    public static OperationResult Rejected(IReadOnlyList<string> codes) =>
        codes.Count == 0 ? throw new ArgumentException("Falta el código.", nameof(codes)) : new(codes[0], codes);
}
