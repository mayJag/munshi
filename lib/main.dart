import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'app/theme.dart';
import 'features/lock/lock_screen.dart';
import 'features/quick_add/quick_add_sheet.dart';
import 'features/shell/home_shell.dart';
import 'data/db.dart';
import 'services/backup_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/widget_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Settings must load before we read PIN state; guard so a prefs hiccup can't
  // block the whole app.
  try {
    await SettingsService.instance.init();
  } catch (_) {/* fall back to defaults */}

  // Notifications are best-effort; never let their init stop the app opening.
  try {
    await NotificationService.instance.init();
    final reminders = await db.activeReminders();
    await NotificationService.instance.rescheduleAll(reminders);
  } catch (_) {/* notifications unavailable */}

  runApp(const MunshiApp());

  // Non-essential background work runs AFTER the first frame so nothing here
  // can ever crash the launch. Each is independently guarded.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await BackupService.instance.maybeAutoBackup();
    } catch (_) {/* backup is optional */}
    try {
      await WidgetService.instance.refresh();
    } catch (_) {/* widget is optional */}
  });
}

class MunshiApp extends StatefulWidget {
  const MunshiApp({super.key});

  @override
  State<MunshiApp> createState() => _MunshiAppState();
}

class _MunshiAppState extends State<MunshiApp> {
  late bool _locked;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    _locked = SettingsService.instance.hasPin;
    // Deep-link: a reminder tap opens the quick-add sheet.
    NotificationService.instance.onQuickAddRequested = _openQuickAdd;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final payload = await NotificationService.instance.launchPayload();
      if (payload == kQuickAddPayload && !_locked) _openQuickAdd();
      await _initWidgetLaunch();
    });
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    super.dispose();
  }

  /// Handle taps on the "+ Add expense" home-screen widget — both the cold
  /// launch and taps while the app is already running.
  Future<void> _initWidgetLaunch() async {
    if (!Platform.isAndroid) return;
    try {
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _handleWidgetUri(launchUri);
      _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    } catch (_) {/* plugin unavailable — ignore */}
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri?.host == 'quickadd' && !_locked) _openQuickAdd();
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
