import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../services/settings_service.dart';

/// PIN entry gate shown on cold start when an app-lock PIN is set.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entry = '';
  bool _error = false;

  void _tap(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      if (key == '<') {
        if (_entry.isNotEmpty) _entry = _entry.substring(0, _entry.length - 1);
      } else if (_entry.length < 4) {
        _entry += key;
      }
    });
    if (_entry.length == 4) _check();
  }

  void _check() {
    if (_entry == SettingsService.instance.pin) {
      widget.onUnlock();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _entry = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: MunshiTheme.accent),
            const SizedBox(height: 16),
            Text('Enter PIN',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error ? 'Wrong PIN, try again' : 'Munshi is locked',
                style: TextStyle(
                    color: _error ? MunshiTheme.negative : Colors.white54)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _entry.length
                          ? MunshiTheme.accent
                          : Colors.white24,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 260,
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 1.4,
                children: [
                  for (final k in [
                    '1','2','3','4','5','6','7','8','9','','0','<'
                  ])
                    k.isEmpty
                        ? const SizedBox.shrink()
                        : InkWell(
                            borderRadius: BorderRadius.circular(40),
                            onTap: () => _tap(k),
                            child: Center(
                              child: k == '<'
                                  ? const Icon(Icons.backspace_outlined)
                                  : Text(k,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                            ),
                          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
