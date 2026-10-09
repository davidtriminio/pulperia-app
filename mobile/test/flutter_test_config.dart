import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configuración común de todos los tests. Sin teléfono no hay plugin de
/// conectividad: se simula un canal que nunca emite cambios (los tests que
/// necesitan cambios sobrescriben `onlineProvider`).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const events = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    ..setMockMethodCallHandler(methods, (call) async => <String>['wifi'])
    ..setMockMethodCallHandler(events, (call) async => null);
  await testMain();
}
