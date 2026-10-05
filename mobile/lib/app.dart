import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

class PulperiaApp extends StatelessWidget {
  const PulperiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appTitle,
      locale: const Locale('es'),
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}
