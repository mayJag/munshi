import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/lock/lock_screen.dart';
import 'features/quick_add/quick_add_sheet.dart';
import 'features/shell/home_shell.dart';
import 'data/db.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  await NotificationService.instance.init();
  // Restore scheduled reminders (survives app updates / fresh launches).
  final reminders = await db.activeReminders();
  await NotificationService.instance.rescheduleAll(reminders);
  runApp(const MunshiApp());
}

class MunshiApp extends StatefulWidget {
  const MunshiApp({super.key});

  @override
  State<MunshiApp> createState() => _MunshiAppState();
}

class _MunshiAppState extends State<MunshiApp> {
  late bool _locked;

  @override
  void initState() {
    super.initState();
    _locked = SettingsService.instance.hasPin;
    // Deep-link: a reminder tap opens the quick-add sheet.
    NotificationService.instance.onQuickAddRequested = _openQuickAdd;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final payload = await NotificationService.instance.launchPayload();
      if (payload == kQuickAddPayload && !_locked) _openQuickAdd();
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
      home: _locked
          ? LockScreen(onUnlock: () => setState(() => _locked = false))
          : const HomeShell(),
    );
  }
}
