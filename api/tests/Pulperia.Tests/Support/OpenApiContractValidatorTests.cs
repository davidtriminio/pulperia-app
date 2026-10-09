using System.Text.Json;

namespace Pulperia.Tests.Support;

/// <summary>El validador del contrato debe detectar las desviaciones; si no, la prueba del contrato no vale nada (T086).</summary>
public class OpenApiContractValidatorTests
{
    private static readonly OpenApiContract Contract = OpenApiContract.Load();

    private static JsonElement Json(string text) => JsonDocument.Parse(text).RootElement.Clone();

    private static JsonElement Schema(string name) => Json($$"""{ "$ref": "#/components/schemas/{{name}}" }""");

    private const string ValidSummary = """{ "debtTotal": 10, "creditTotal": 0, "debtors": [ { "clientId": "0197a000-0000-7000-8000-000000000001", "name": "Ana", "debt": 10 } ] }""";

    [Fact]
    public void Una_respuesta_correcta_no_tiene_problemas() =>
        Assert.Empty(Contract.Validate(Json(ValidSummary), Schema("SummaryResponse")));

    [Fact]
    public void Una_propiedad_que_el_contrato_no_declara_es_un_problema() =>
        Assert.Contains("'extra'", Assert.Single(Contract.Validate(
            Json(ValidSummary.Replace("\"debtTotal\": 10,", "\"debtTotal\": 10, \"extra\": 1,")), Schema("SummaryResponse"))));

    [Fact]
    public void Falta_una_propiedad_requerida() =>
        Assert.Contains("'creditTotal'", Assert.Single(Contract.Validate(
            Json(ValidSummary.Replace("\"creditTotal\": 0,", "")), Schema("SummaryResponse"))));

    [Theory]
    [InlineData("\"debtTotal\": 10", "\"debtTotal\": 10.5")]
    [InlineData("\"debtTotal\": 10", "\"debtTotal\": \"10\"")]
    [InlineData("\"debtTotal\": 10", "\"debtTotal\": null")]
    [InlineData("0197a000-0000-7000-8000-000000000001", "no-es-uuid")]
    public void Un_tipo_o_formato_equivocado_es_un_problema(string from, string to) =>
        Assert.NotEmpty(Contract.Validate(Json(ValidSummary.Replace(from, to)), Schema("SummaryResponse")));

    [Fact]
    public void Un_valor_fuera_del_enum_es_un_problema() =>
        Assert.NotEmpty(Contract.Validate(
            Json("""{ "id": "0197a000-0000-7000-8000-000000000001", "name": "N", "role": "jefe", "amountMode": "integer", "quantityMode": "integer" }"""),
            Schema("BusinessSummary")));

    [Fact]
    public void Una_fecha_sin_zona_es_un_problema()
    {
        const string tokens = """{ "userId": "0197a000-0000-7000-8000-000000000001", "accessToken": "a", "accessExpiresAt": "2026-10-08T12:00:00", "refreshToken": "r", "refreshExpiresAt": "2026-10-08T12:00:00Z" }""";

        Assert.Contains("accessExpiresAt", Assert.Single(Contract.Validate(Json(tokens), Schema("Tokens"))));
    }

    [Fact]
    public void Un_registro_que_no_encaja_con_ninguna_opcion_de_oneOf_es_un_problema() =>
        Assert.NotEmpty(Contract.Validate(Json("""{ "seq": 1, "type": "client", "entity": { "id": "0197a000-0000-7000-8000-000000000001" } }"""), Schema("ChangeEntry")));
}
