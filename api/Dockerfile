# Imagen de la API (D-33). Se construye con el contexto en api/ (ver deploy/docker-compose.yml).
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Primero los .csproj: el restore de paquetes se cachea mientras no cambien.
COPY src/Pulperia.Domain/Pulperia.Domain.csproj src/Pulperia.Domain/
COPY src/Pulperia.Application/Pulperia.Application.csproj src/Pulperia.Application/
COPY src/Pulperia.Infrastructure/Pulperia.Infrastructure.csproj src/Pulperia.Infrastructure/
COPY src/Pulperia.Api/Pulperia.Api.csproj src/Pulperia.Api/
RUN dotnet restore src/Pulperia.Api/Pulperia.Api.csproj

COPY src/ src/
RUN dotnet publish src/Pulperia.Api/Pulperia.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app .

# Sin privilegios: la imagen de ASP.NET trae el usuario "app".
USER app
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
ENTRYPOINT ["dotnet", "Pulperia.Api.dll"]
