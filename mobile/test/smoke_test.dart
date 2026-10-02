import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';

void main() {
  testWidgets('la app arranca dentro de un MaterialApp', (tester) async {
    await tester.pumpWidget(const PulperiaApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
