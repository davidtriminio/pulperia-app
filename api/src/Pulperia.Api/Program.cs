using Pulperia.Api;

// "admin ..." son comandos del administrador del servidor (D-19): se ejecutan y terminan,
// sin levantar la API.
if (args is ["admin", .. var adminArgs])
{
    return await AdminCommands.RunAsync(adminArgs, Console.Out, Console.Error, $"{Environment.UserName}@{Environment.MachineName}");
}

ApiHost.Build(args).Run();
return 0;
