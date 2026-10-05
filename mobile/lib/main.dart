import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/local/app_database.dart';
import 'dev/dev_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase(driftDatabase(name: 'pulperia'));
  // Solo en depuración: negocio y usuario de prueba hasta la sesión real (T088).
  await seedDevSession(db, devSessionFor());
  runApp(const PulperiaApp());
}
