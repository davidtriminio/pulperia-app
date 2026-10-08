using Microsoft.EntityFrameworkCore;

namespace Pulperia.Infrastructure.Persistence;

/// <summary>
/// El contador de cambios por negocio (<c>businesses.last_seq</c>). Se incrementa con una sola
/// sentencia atómica: dos operaciones del mismo negocio se esperan entre sí y nunca obtienen el
/// mismo número. Como el contador vive en una fila y no en una secuencia de PostgreSQL, si la
/// transacción se revierte el número se devuelve y no queda ningún hueco (T062).
/// </summary>
public static class ChangeSequence
{
    /// <summary>
    /// Reserva y devuelve el siguiente <c>seq</c> del negocio. Debe llamarse dentro de la misma
    /// transacción que escribe el cambio y su fila de <c>change_log</c>.
    /// </summary>
    /// <exception cref="InvalidOperationException">El negocio no existe.</exception>
    public static async Task<long> NextAsync(
        PulperiaDbContext db, Guid businessId, CancellationToken cancellationToken = default)
    {
        var next = await db.Database
            .SqlQuery<long>($"UPDATE businesses SET last_seq = last_seq + 1 WHERE id = {businessId} RETURNING last_seq AS \"Value\"")
            .ToListAsync(cancellationToken);

        return next.Count == 1
            ? next[0]
            : throw new InvalidOperationException($"El negocio {businessId} no existe.");
    }
}
