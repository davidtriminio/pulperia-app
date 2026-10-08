using Pulperia.Domain.Amounts;
using Pulperia.Domain.Ledger;

namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>
/// Tabla <c>payments</c>: un abono general al saldo de un cliente, sin asociarse a ningún
/// fiado (RF-37). Nunca se edita ni se elimina: solo se anula (RF-43, RF-46).
/// </summary>
public sealed class PaymentEntity
{
    public Guid Id { get; set; }

    public Guid BusinessId { get; set; }

    public Guid ClientId { get; set; }

    /// <summary>Monto en la unidad menor; puede superar la deuda y dejar saldo a favor (RF-39).</summary>
    public long Amount { get; set; }

    public DateTime OccurredAt { get; set; }

    /// <summary>El usuario que lo registró (RF-49).</summary>
    public Guid CreatedBy { get; set; }

    public DateTime? AnnulledAt { get; set; }

    public Guid? AnnulledBy { get; set; }

    /// <summary>Como movimiento del dominio, para calcular el saldo (RF-40, RF-44).</summary>
    public LedgerMovement ToMovement() => new(MovementKind.Payment, new Money(Amount), AnnulledAt is not null);
}
