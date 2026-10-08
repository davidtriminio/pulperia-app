using System.Threading.RateLimiting;

namespace Pulperia.Api;

/// <summary>
/// Límite de intentos de canje de códigos de invitación: 10 por minuto por usuario (D-28). Con
/// 31^8 códigos posibles, adivinar uno a ese ritmo es inviable. Vive en memoria, por proceso.
/// </summary>
internal sealed class RedeemRateLimiter : IDisposable
{
    private readonly PartitionedRateLimiter<Guid> _limiter = PartitionedRateLimiter.Create<Guid, Guid>(
        userId => RateLimitPartition.GetFixedWindowLimiter(
            userId,
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true,
            }));

    public bool TryAcquire(Guid userId)
    {
        using var lease = _limiter.AttemptAcquire(userId);
        return lease.IsAcquired;
    }

    public void Dispose() => _limiter.Dispose();
}
