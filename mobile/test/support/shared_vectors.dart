import 'dart:convert';
import 'dart:io';

/// Un caso de los vectores compartidos de `shared/vectors/`.
class VectorCase {
  const VectorCase(this.name, this.input, this.expected);

  final String name;
  final Map<String, dynamic> input;
  final Map<String, dynamic> expected;
}

/// Lee los casos de `shared/vectors/<file>`. `flutter test` se ejecuta en
/// `mobile/`, así que la carpeta compartida está en `../shared`.
List<VectorCase> loadVectorCases(String file) {
  final json = jsonDecode(
    File('../shared/vectors/$file').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final c in json['cases'] as List<dynamic>)
      VectorCase(
        (c as Map<String, dynamic>)['name'] as String,
        c['input'] as Map<String, dynamic>,
        c['expected'] as Map<String, dynamic>,
      ),
  ];
}
