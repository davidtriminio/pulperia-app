using Pulperia.Application.Accounts;

namespace Pulperia.Tests.Accounts;

/// <summary>T063: hash de contraseñas con PBKDF2-HMAC-SHA256 (D-27).</summary>
public class PasswordHasherTests
{
    private static readonly PasswordHasher Fast = new(iterations: 1_000);

    [Fact]
    public void Por_omision_usa_600000_iteraciones_y_el_formato_del_plan()
    {
        var hash = new PasswordHasher().Hash("contrasena1");

        var parts = hash.Split('$');
        Assert.Equal(4, parts.Length);
        Assert.Equal(("pbkdf2-sha256", "600000"), (parts[0], parts[1]));
        Assert.Equal(16, Convert.FromBase64String(parts[2]).Length);
        Assert.Equal(32, Convert.FromBase64String(parts[3]).Length);
        Assert.DoesNotContain("contrasena1", hash);
    }

    [Fact]
    public void La_contrasena_correcta_verifica_y_la_incorrecta_no()
    {
        var hash = Fast.Hash("contrasena1");

        Assert.True(Fast.Verify(hash, "contrasena1").IsValid);
        Assert.False(Fast.Verify(hash, "contrasena2").IsValid);
        Assert.False(Fast.Verify(hash, "").IsValid);
    }

    [Fact]
    public void La_misma_contrasena_da_hashes_distintos_por_la_sal() =>
        Assert.NotEqual(Fast.Hash("contrasena1"), Fast.Hash("contrasena1"));

    [Fact]
    public void Un_hash_con_menos_iteraciones_que_las_vigentes_pide_renovarse()
    {
        var old = new PasswordHasher(iterations: 1_000).Hash("contrasena1");

        var current = new PasswordHasher(iterations: 2_000).Verify(old, "contrasena1");
        var same = Fast.Verify(old, "contrasena1");

        Assert.True(current.IsValid);
        Assert.True(current.NeedsRehash);
        Assert.False(same.NeedsRehash);
    }

    [Theory]
    [InlineData("")]
    [InlineData("texto")]
    [InlineData("pbkdf2-sha256$x$y$z")]
    [InlineData("md5$1000$AAAA$AAAA")]
    [InlineData("pbkdf2-sha256$1000$no-es-base64$AAAA")]
    public void Un_hash_mal_formado_no_verifica_y_no_lanza(string malformed) =>
        Assert.False(Fast.Verify(malformed, "contrasena1").IsValid);
}
