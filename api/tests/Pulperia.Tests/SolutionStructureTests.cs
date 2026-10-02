using System.Reflection;

namespace Pulperia.Tests;

public class SolutionStructureTests
{
    [Theory]
    [InlineData("Pulperia.Domain")]
    [InlineData("Pulperia.Application")]
    [InlineData("Pulperia.Infrastructure")]
    [InlineData("Pulperia.Api")]
    public void Layer_assembly_is_loadable(string name)
    {
        var assembly = Assembly.Load(name);

        Assert.Equal(name, assembly.GetName().Name);
    }

    [Fact]
    public void Domain_references_no_other_project_or_framework_library()
    {
        var references = Assembly.Load("Pulperia.Domain")
            .GetReferencedAssemblies()
            .Select(a => a.Name!)
            .Where(n => n.StartsWith("Pulperia.") || n.StartsWith("Microsoft.EntityFrameworkCore") || n.StartsWith("Microsoft.AspNetCore"));

        Assert.Empty(references);
    }
}
