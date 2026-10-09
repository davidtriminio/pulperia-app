# shared/ — datos compartidos entre plataformas

Esta carpeta no contiene código ejecutable. Contiene **datos** que los tests de las tres plataformas (API en .NET, móvil en Flutter, web en Angular) leen para comprobar que calculan lo mismo.

## Por qué existe
El mismo cálculo (por ejemplo el redondeo de un subtotal o el saldo de un cliente) lo implementan tres plataformas. Si cada una definiera sus propios casos de prueba, podrían divergir sin que nadie lo note, y el saldo de un cliente sería distinto en el móvil y en el servidor. Aquí hay una sola fuente de verdad: cada plataforma tiene que pasar los mismos casos.

## Archivos previstos
Se crean en las tareas T006 a T013, T086 y T176 de `specs/001-mvp/tasks.md`.

| Archivo | Contenido | RF |
|---|---|---|
| `vectors/subtotal-integer.json` | Subtotal con montos enteros | 34 |
| `vectors/subtotal-two-decimals.json` | Subtotal con 2 decimales | 83 |
| `vectors/balance.json` | Saldo de un cliente | 39, 40, 42, 44, 47 |
| `vectors/phone.json` | Validación de teléfono | 77 |
| `vectors/summary.json` | Resumen del negocio | 63, 64, 65 |
| `vectors/avatar-palette.json` | Paleta de avatares (personajes, tonos, fondos) | 72 |
| `vectors/client-validation.json` | Validación de cliente | 15, 17, 74 |
| `vectors/business-modes.json` | Modos de montos y cantidades del negocio | 8, 9, 32, 35, 36, 84 |
| `vectors/units.json` | Unidades de venta (lista fija con ids estables) | 86, 87, 88, 89 |
| `vectors/price-change.json` | Precio anterior de un producto al cambiarle el precio | 90 |
| `openapi.json` | Contrato de la API | — |

## Formato de un archivo de vectores
Cada archivo de `vectors/` es un JSON con esta forma:

- `description`: qué comprueba el archivo.
- `rf`: lista de números de requisito funcional que cubre.
- `cases`: lista de casos. Cada caso tiene:
  - `name`: nombre legible que explica por qué existe el caso.
  - `input`: los datos de entrada.
  - `expected`: el resultado exacto que debe producir cualquier plataforma.

Excepción: `vectors/avatar-palette.json` y `vectors/units.json` no tienen `cases`. Son catálogos de datos (`characters`, `skinTones` y `backgrounds`, cada uno con `id` estable y, en tonos y fondos, el color `hex`) que las plataformas leen para dibujar y validar avatares. Los ids nunca se renombran ni se reutilizan.

`vectors/units.json` es la lista `units` (cada unidad con `id` estable, `singular`, `plural` y `abbreviation`, en español) más `default`, la unidad por omisión. Los ids tampoco se renombran ni se reutilizan.

Convenciones de los datos:
- **Dinero**: entero en la unidad menor (centavos de lempira). L 30 se escribe `3000`. Nunca decimales ni cadenas.
- **Cantidades**: entero en milésimas. 0.25 se escribe `250`.
- **Modo de montos**: `"integer"` o `"two_decimals"`.
- **Modo de cantidades**: `"integer"` o `"fractional"`.
- **Fechas y horas**: texto ISO 8601 en UTC, por ejemplo `"2026-10-02T15:30:00Z"`.
- **Identificadores**: textos GUID/UUID.
- **Errores esperados**: un código estable en texto dentro de `expected`, por ejemplo `{"error": "quantity_not_integer"}`, nunca el mensaje en español.

### Ejemplo
```json
{
  "description": "Subtotal de un ítem con montos enteros",
  "rf": [34],
  "cases": [
    {
      "name": "0.25 por L 30 son L 7.50 y el .5 sube a L 8",
      "input": { "amountMode": "integer", "quantityMilli": 250, "unitPrice": 3000 },
      "expected": { "subtotal": 800 }
    }
  ]
}
```

## Cómo los lee cada plataforma
Cada plataforma localiza esta carpeta con una ruta relativa a la raíz del repositorio y ejecuta todos los casos del archivo.

- **API (.NET)**: los tests de `api/tests` suben hasta la raíz del repositorio y leen `shared/vectors/<archivo>.json`.
- **Móvil (Flutter)**: `flutter test` se ejecuta en `mobile/`, así que los tests leen `../shared/vectors/<archivo>.json`.
- **Web (Angular)**: se define en T122, cuando se consume el primer archivo. El formato de los archivos no depende de ello.

Cada plataforma recorre `cases` y compara su resultado con `expected`; un caso que falle debe mostrar su `name`.

## Reglas
- Un vector es comportamiento acordado. **No se cambia un caso para que un test pase**: si un resultado esperado cambia, primero se actualiza la spec o el plan.
- Añadir casos nuevos es siempre válido; cambiar o borrar uno existente requiere el paso anterior.
- Los vectores son datos puros: sin lógica, sin referencias a código de ninguna plataforma.

## `openapi.json`: el contrato de la API
Descripción OpenAPI 3.0 escrita a mano (D-17). Los clientes HTTP del móvil y de la web se escriben contra ella; no se generan.

- Cada ruta de la API está descrita, con sus respuestas, y cada objeto declara **todas** sus propiedades: una que no esté en el contrato no existe.
- La prueba `ApiContractTests` (en `api/tests`) recorre la API real: comprueba que las rutas del servidor y las del contrato son las mismas, que cada petición y cada respuesta cumplen su esquema, y que no queda en el contrato ninguna respuesta que ninguna prueba haya visto. Cambiar la API sin cambiar el contrato (o al revés) la hace fallar.
- Al cambiar el contrato hay que actualizar antes el plan (sección 5), por la regla de no cambiar el contrato de la API sin spec.

## `examples/`: respuestas de ejemplo
Cada archivo de `examples/` tiene `description` y `cases`; cada caso tiene `name`, `schema` (el nombre de un esquema de `components/schemas` de `openapi.json`) y `example` (un JSON que lo cumple). Son el puente entre el contrato y los clientes (D-17):

- La API comprueba en `SharedExamplesTests` que cada ejemplo cumple el esquema que nombra, así que un ejemplo no puede desviarse del contrato.
- El móvil (y más adelante la web) lee los mismos ejemplos en sus tests de modelos y de cliente HTTP, y por tanto prueba contra lo que la API devuelve de verdad.

| Archivo | Contenido |
|---|---|
| `examples/auth.json` | Registro y tokens |
| `examples/businesses.json` | Negocios del usuario con su rol |
| `examples/sync.json` | Resultados de operaciones, resultado de un lote y páginas del pull |
| `examples/errors.json` | El cuerpo de error con su código estable |

Las reglas de los vectores se aplican igual: añadir ejemplos es siempre válido; cambiar o borrar uno exige actualizar antes el contrato.
