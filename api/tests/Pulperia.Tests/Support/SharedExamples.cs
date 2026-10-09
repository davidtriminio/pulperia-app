using System.Text.Json;

namespace Pulperia.Tests.Support;

/// <summary>Un caso de <c>shared/examples/</c>: un JSON de ejemplo y el esquema del contrato que debe cumplir.</summary>
public sealed record ExampleCase(string File, string Name, string Schema, JsonElement Example);

/// <summary>Lee los ejemplos compartidos (<c>shared/examples/*.json</c>) que los clientes usan en sus tests.</summary>
public static class SharedExamples
{
    public static IReadOnlyList<ExampleCase> LoadAll()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "shared", "examples")))
        {
            dir = dir.Parent;
        }
        if (dir is null)
        {
            throw new DirectoryNotFoundException("No se encontró shared/examples desde " + AppContext.BaseDirectory);
        }

        return Directory.GetFiles(Path.Combine(dir.FullName, "shared", "examples"), "*.json").Order()
            .SelectMany(file => JsonDocument.Parse(File.ReadAllText(file)).RootElement.GetProperty("cases").EnumerateArray()
                .Select(c => new ExampleCase(
                    Path.GetFileName(file), c.GetProperty("name").GetString()!, c.GetProperty("schema").GetString()!,
                    c.GetProperty("example").Clone())))
            .ToList();
    }
}
