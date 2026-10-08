using Pulperia.Api;

namespace Pulperia.Tests.Management;

/// <summary>Sin cadena de conexión la API y el comando avisan claro, en vez de fallar en la primera petición.</summary>
public class ConnectionStringTests
{
    [Fact]
    public void La_API_no_arranca_sin_cadena_de_conexion_y_dice_como_ponerla()
    {
        var ex = Assert.Throws<InvalidOperationException>(
            () => ApiHost.Build([], builder => builder.Configuration["ConnectionStrings:Pulperia"] = ""));

        Assert.Contains("ConnectionStrings__Pulperia", ex.Message);
    }

    [Fact]
    public async Task El_comando_de_administrador_sin_cadena_de_conexion_sale_con_error_y_el_mismo_aviso()
    {
        var stdout = new StringWriter();
        var stderr = new StringWriter();

        var exitCode = await AdminCommands.RunAsync(
            ["reset-password", "ana@correo.com"], stdout, stderr, "admin@servidor",
            builder => builder.Configuration["ConnectionStrings:Pulperia"] = "");

        Assert.Equal(1, exitCode);
        Assert.Contains("ConnectionStrings__Pulperia", stderr.ToString());
        Assert.Equal("", stdout.ToString());
    }
}
