using System.Text.Json;

namespace Pulperia.Tests.Support;

/// <summary>
/// Los ejemplos de <c>shared/examples/</c> cumplen el contrato. Los clientes (móvil y web) los usan
/// en sus tests, así que si un ejemplo se desviara del contrato, sus tests probarían otra API.
/// </summary>
public class SharedExamplesTests
{
    private static readonly OpenApiContract Contract = OpenApiContract.Load();

    public static TheoryData<string> Names
    {
        get
        {
            var data = new TheoryData<string>();
            foreach (var c in SharedExamples.LoadAll())
            {
                data.Add($"{c.File}: {c.Name}");
            }
            return data;
        }
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Cada_ejemplo_cumple_el_esquema_que_nombra(string name)
    {
        var example = SharedExamples.LoadAll().Single(c => $"{c.File}: {c.Name}" == name);
        var schema = JsonDocument.Parse($$"""{ "$ref": "#/components/schemas/{{example.Schema}}" }""").RootElement;

        var problems = Contract.Validate(example.Example, schema);

        Assert.True(problems.Count == 0, string.Join("\n", problems));
    }

    [Fact]
    public void Los_ejemplos_cubren_lo_que_el_movil_recibe_en_la_fase_8()
    {
        var schemas = SharedExamples.LoadAll().Select(c => c.Schema).ToHashSet();

        Assert.Superset(
            new HashSet<string> { "Registered", "Tokens", "BusinessSummary", "OperationResult", "PushResponse", "PullResponse", "Error" },
            schemas);
    }

    [Fact]
    public void Un_ejemplo_de_pull_trae_los_cuatro_tipos_de_registro_y_los_tres_resultados_de_una_operacion()
    {
        var cases = SharedExamples.LoadAll();

        var types = cases.Where(c => c.Schema == "PullResponse")
            .SelectMany(c => c.Example.GetProperty("changes").EnumerateArray()).Select(e => e.GetProperty("type").GetString()).ToHashSet();
        var statuses = cases.Where(c => c.Schema == "OperationResult").Select(c => c.Example.GetProperty("status").GetString()).ToHashSet();

        Assert.Superset(new HashSet<string?> { "client", "product", "fiado", "payment" }, types);
        Assert.Superset(new HashSet<string?> { "applied", "duplicate", "rejected" }, statuses);
    }
}
