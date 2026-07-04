import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/quick_add/quick_add_sheet.dart';
import 'features/shell/home_shell.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  await NotificationService.instance.init();
  runApp(const MunshiApp());
}

class MunshiApp extends StatefulWidget {
  const MunshiApp({super.key});

  @override
  State<MunshiApp> createState() => _MunshiAppState();
}

class _MunshiAppState extends State<MunshiApp> {
  @override
  void initState() {
    super.initState();
    // Deep-link: a reminder tap opens the quick-add sheet.
    NotificationService.instance.onQuickAddRequested = _openQuickAdd;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final payload = await NotificationService.instance.launchPayload();
      if (payload == kQuickAddPayload) _openQuickAdd();
    });
  }

  void _openQuickAdd() {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) QuickAddSheet.show(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Munshi',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: MunshiTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}
