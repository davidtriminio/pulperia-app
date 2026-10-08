using Pulperia.Domain.Amounts;
using Pulperia.Domain.Ledger;

namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>
/// Tabla <c>fiados</c>: lo que un cliente se llevó fiado, con o sin detalle de ítems
/// (RF-28, RF-29). Nunca se edita ni se elimina: solo se anula, conservando quién y cuándo
/// (RF-43, RF-46); la base lo hace cumplir con disparadores.
/// </summary>
public sealed class FiadoEntity
{
    public Guid Id { get; set; }

    public Guid BusinessId { get; set; }

    public Guid ClientId { get; set; }

    /// <summary>Total en la unidad menor; con ítems es la suma de sus subtotales, calculada al crear.</summary>
    public long Total { get; set; }

    /// <summary>Cuándo ocurrió la venta, según el dispositivo que la registró (D-18).</summary>
    public DateTime OccurredAt { get; set; }

    /// <summary>El usuario que lo registró (RF-49).</summary>
    public Guid CreatedBy { get; set; }

    public DateTime? AnnulledAt { get; set; }

    public Guid? AnnulledBy { get; set; }

    /// <summary>Como movimiento del dominio, para calcular el saldo (RF-40, RF-44).</summary>
    public LedgerMovement ToMovement() => new(MovementKind.Fiado, new Money(Total), AnnulledAt is not null);
}
