namespace Pulperia.Domain.Clients;

public static class Homonyms
{
    private static string Comparable(string name) => name.Trim().ToLowerInvariant();

    /// <summary>
    /// Indica si <paramref name="name"/> coincide con alguno de <paramref name="existingNames"/>,
    /// ignorando mayúsculas y espacios exteriores (RF-17). Solo los espacios exteriores se
    /// ignoran: los interiores y las tildes cuentan.
    /// </summary>
    /// <remarks>
    /// Es un aviso, no un error: el usuario puede continuar si lo confirma. Un nombre vacío
    /// (o solo de espacios) nunca tiene homónimos, porque ya se rechaza aparte (RF-15). Al
    /// editar un cliente, <paramref name="existingNames"/> no debe incluir el nombre del propio
    /// cliente.
    /// </remarks>
    public static bool HasHomonym(string name, IEnumerable<string> existingNames)
    {
        var target = Comparable(name);
        return target.Length > 0 && existingNames.Any(existing => Comparable(existing) == target);
    }
}
