import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How unspent daily allowance is treated.
/// - [spread]: leftover rolls into the remaining days, raising future daily
///   allowance (budget − spent-before-today, divided by days left).
/// - [savings]: each day gets a fixed allowance (budget ÷ days in month);
///   whatever you don't spend accrues to a savings pot instead.
enum LeftoverMode { spread, savings }

/// Small key-value app settings (not financial data — that lives in drift).
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _kLeftoverMode = 'leftover_mode';
  static const _kPin = 'app_pin';

  final ValueNotifier<LeftoverMode> leftoverMode =
      ValueNotifier(LeftoverMode.spread);

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getString(_kLeftoverMode);
    leftoverMode.value = LeftoverMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => LeftoverMode.spread,
    );
  }

  Future<void> setLeftoverMode(LeftoverMode mode) async {
    leftoverMode.value = mode;
    await _prefs.setString(_kLeftoverMode, mode.name);
  }

  // ---- App lock (PIN) ---------------------------------------------------

  String? get pin => _prefs.getString(_kPin);
  bool get hasPin => (pin?.isNotEmpty ?? false);

  Future<void> setPin(String value) => _prefs.setString(_kPin, value);
  Future<void> clearPin() => _prefs.remove(_kPin);
}
