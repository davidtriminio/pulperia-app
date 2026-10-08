using System.Text.Json;

namespace Pulperia.Tests.Support;

/// <summary>Un caso de los vectores compartidos de <c>shared/vectors/</c>.</summary>
public sealed record VectorCase(string Name, JsonElement Input, JsonElement Expected);

/// <summary>
/// Lee los vectores compartidos entre plataformas (<c>shared/vectors/*.json</c>).
/// Ninguna plataforma redefine esos casos: la API los lee igual que el móvil.
/// </summary>
public static class SharedVectors
{
    private static readonly Dictionary<string, IReadOnlyList<VectorCase>> Cache = new();

    /// <summary>Carpeta <c>shared/vectors</c>, buscada hacia arriba desde el binario de pruebas.</summary>
    private static string VectorsDirectory()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "shared", "vectors");
            if (Directory.Exists(candidate))
            {
                return candidate;
            }
            dir = dir.Parent;
        }
        throw new DirectoryNotFoundException("No se encontró shared/vectors desde " + AppContext.BaseDirectory);
    }

    public static IReadOnlyList<VectorCase> Load(string file)
    {
        lock (Cache)
        {
            if (Cache.TryGetValue(file, out var cached))
            {
                return cached;
            }

            using var stream = File.OpenRead(Path.Combine(VectorsDirectory(), file));
            using var doc = JsonDocument.Parse(stream);
            var cases = doc.RootElement.GetProperty("cases")
                .EnumerateArray()
                .Select(c => new VectorCase(
                    c.GetProperty("name").GetString()!,
                    c.GetProperty("input").Clone(),
                    c.GetProperty("expected").Clone()))
                .ToList();
            Cache[file] = cases;
            return cases;
        }
    }

    /// <summary>Casos de un archivo, opcionalmente filtrados por <c>input.operation</c>.</summary>
    public static IReadOnlyList<VectorCase> Load(string file, string operation) =>
        Load(file)
            .Where(c => c.Input.TryGetProperty("operation", out var op) && op.GetString() == operation)
            .ToList();

    /// <summary>Nombres de los casos, para usar como datos de una <c>[Theory]</c>.</summary>
    public static TheoryData<string> Names(string file, string? operation = null)
    {
        var data = new TheoryData<string>();
        var cases = operation is null ? Load(file) : Load(file, operation);
        foreach (var c in cases)
        {
            data.Add(c.Name);
        }
        return data;
    }

    public static VectorCase Get(string file, string name) =>
        Load(file).First(c => c.Name == name);
}
