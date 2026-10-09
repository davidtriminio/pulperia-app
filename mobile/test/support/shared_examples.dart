import 'dart:convert';
import 'dart:io';

/// Un caso de `shared/examples/`: un JSON de ejemplo que cumple un esquema del
/// contrato (la API lo comprueba en sus tests).
class ExampleCase {
  const ExampleCase(this.name, this.schema, this.example);

  final String name;
  final String schema;
  final Map<String, dynamic> example;
}

/// Lee los casos de `shared/examples/<file>`. `flutter test` se ejecuta en
/// `mobile/`, así que la carpeta compartida está en `../shared`.
List<ExampleCase> loadExamples(String file) {
  final json = jsonDecode(
    File('../shared/examples/$file').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final c in json['cases'] as List<dynamic>)
      ExampleCase(
        (c as Map<String, dynamic>)['name'] as String,
        c['schema'] as String,
        c['example'] as Map<String, dynamic>,
      ),
  ];
}

/// El ejemplo de ese archivo cuyo nombre empieza por [prefix].
Map<String, dynamic> exampleNamed(String file, String prefix) =>
    loadExamples(file).firstWhere((c) => c.name.startsWith(prefix)).example;
