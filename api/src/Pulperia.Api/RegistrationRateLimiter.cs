using System.Threading.RateLimiting;

namespace Pulperia.Api;

/// <summary>
/// Límite de intentos de registro con código de invitación: 10 por minuto por origen de la conexión
/// (D-32). Es el mismo ritmo que el canje de D-28, pero sin usuario al que contarlo todavía. Vive en
/// memoria, por proceso.
/// </summary>
internal sealed class RegistrationRateLimiter : IDisposable
{
    private readonly PartitionedRateLimiter<string> _limiter = PartitionedRateLimiter.Create<string, string>(
        origin => RateLimitPartition.GetFixedWindowLimiter(
            origin,
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true,
            }));

    public bool TryAcquire(string origin)
    {
        using var lease = _limiter.AttemptAcquire(origin);
        return lease.IsAcquired;
    }

    public void Dispose() => _limiter.Dispose();
}
