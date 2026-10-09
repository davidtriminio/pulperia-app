using Pulperia.Application.Operations;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Ledger;

namespace Pulperia.Application.Queries;

/// <summary>Un cliente con lo que se le fio y lo que abonó, solo de movimientos vigentes (RF-40, RF-44).</summary>
public sealed record ClientTotals(ClientRecord Client, Money FiadoTotal, Money PaymentTotal);

/// <summary>Un cliente con su saldo: positivo es deuda, negativo es saldo a favor (RF-42).</summary>
public sealed record ClientWithBalance(ClientRecord Client, Balance Balance);

/// <summary>Un fiado y el orden en que llegó al servidor (el <c>seq</c> de su creación).</summary>
public sealed record FiadoArrival(FiadoRecord Fiado, long ServerSeq);

/// <summary>Un abono y el orden en que llegó al servidor (el <c>seq</c> de su creación).</summary>
public sealed record PaymentArrival(PaymentRecord Payment, long ServerSeq);

/// <summary>Todo lo guardado de un cliente: él mismo y sus movimientos.</summary>
public sealed record ClientMovements(
    ClientRecord Client, IReadOnlyList<FiadoArrival> Fiados, IReadOnlyList<PaymentArrival> Payments);

/// <summary>Un movimiento del historial de un cliente (RF-41); los anulados se conservan y se marcan.</summary>
public sealed record HistoryEntry(
    MovementKind Kind,
    Guid Id,
    Money Amount,
    DateTime OccurredAt,
    long ServerSeq,
    Guid CreatedBy,
    DateTime? AnnulledAt,
    Guid? AnnulledBy,
    IReadOnlyList<FiadoItemRecord> Items);

/// <summary>El cliente con su saldo y su historial cronológico (RF-41, RF-42, D-18).</summary>
public sealed record ClientHistory(ClientRecord Client, Balance Balance, IReadOnlyList<HistoryEntry> Entries);

/// <summary>Un cliente con deuda en el resumen del negocio.</summary>
public sealed record DebtorLine(Guid ClientId, string Name, Money Debt);

/// <summary>El resumen del negocio (RF-63, RF-64, RF-65).</summary>
public sealed record SummaryResult(Money DebtTotal, Money CreditTotal, IReadOnlyList<DebtorLine> Debtors);
