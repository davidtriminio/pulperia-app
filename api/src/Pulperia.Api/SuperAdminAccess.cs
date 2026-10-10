using Pulperia.Api.Endpoints;
using Pulperia.Application.Accounts;

namespace Pulperia.Api;

/// <summary>Marca las rutas que solo abre un super administrador; una prueba las busca por ella (D-29).</summary>
public sealed class SuperAdminOnlyMetadata
{
    public static readonly SuperAdminOnlyMetadata Instance = new();
}

/// <summary>
/// Filtro de las rutas de administración de la plataforma (RF-96, D-29): exige un token de acceso
/// vigente y comprueba en la base, en cada petición, que la cuenta siga marcada como super
/// administrador y sin suspender. No usa ni mira <c>X-Business-Id</c>: la administración no
/// trabaja dentro de un negocio.
/// </summary>
public static class SuperAdminAccess
{
    private const string AdminKey = "Pulperia.SuperAdmin";

    /// <summary>Protege la ruta o el grupo: 401 sin sesión, 403 si la cuenta no es super administrador vigente.</summary>
    public static TBuilder RequireSuperAdmin<TBuilder>(this TBuilder builder) where TBuilder : IEndpointConventionBuilder
    {
        builder.WithMetadata(SuperAdminOnlyMetadata.Instance);
        builder.AddEndpointFilter(async (invocation, next) =>
        {
            var context = invocation.HttpContext;
            var accounts = context.RequestServices.GetRequiredService<AccountService>();

            if (await Http.AuthenticateAsync(context, accounts) is not { } user)
            {
                return Http.Unauthorized();
            }
            if (!await accounts.IsActiveSuperAdminAsync(user.UserId, context.RequestAborted))
            {
                return Http.Error(StatusCodes.Status403Forbidden, "forbidden");
            }
            context.Items[AdminKey] = user;
            return await next(invocation);
        });
        return builder;
    }

    /// <summary>El super administrador de una ruta protegida con <see cref="RequireSuperAdmin"/>.</summary>
    public static AuthenticatedUser GetSuperAdmin(this HttpContext context) =>
        context.Items[AdminKey] as AuthenticatedUser
        ?? throw new InvalidOperationException("La ruta no está protegida con RequireSuperAdmin().");

    /// <summary>El grupo <c>/api/admin</c>, protegido: toda ruta de administración cuelga de él.</summary>
    public static RouteGroupBuilder MapAdminGroup(this WebApplication app) =>
        app.MapGroup("/api/admin").RequireSuperAdmin();
}
