import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/shell/home_shell.dart';

void main() {
  runApp(const MunshiApp());
}

class MunshiApp extends StatelessWidget {
  const MunshiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Munshi',
      debugShowCheckedModeBanner: false,
      theme: MunshiTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}
