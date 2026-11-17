// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad
// License: Apache-2.0 (see /home/emo/code/myune_music-reference/LICENSE)
// Upstream logic kept as-is unless the seam (AudioService/adapters) requires it.
//
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_fonts/system_fonts.dart';
import 'package:flutter/foundation.dart';

import '../../theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  static final int _defaultSeedColorValue = Colors.blue.toARGB32(); // 默认蓝色
  Color _currentSeedColor = Color(
    _defaultSeedColorValue,
  ); // 当前正在使用的主题种子色（可能是动态色或手动色）
  Color _lastManualSeedColor = Color(
    _defaultSeedColorValue,
  ); // 用户最后一次手动选择的种子色，用于在关闭动态配色时恢复

  /// 动态种子（B1）：由 setSeedColor 注入（main.dart DynamicColorBuilder
  /// 的系统调色板 / 封面取色 / vendored 手动选色都走该入口），非 null 时
  /// getters 以它为 buildAppTheme 的 dynamicSeed。冷启动只恢复
  /// _currentSeedColor 不恢复本字段——命名主题默认不受历史种子污染。
  Color? _dynamicSeed;
  Color? get dynamicSeed => _dynamicSeed;

  /// 当前命名主题 key（B1）：AppModel.themeKey 经 MyuneProjection 推入。
  String? _themeKey;
  String get currentThemeKey => _themeKey ?? 'catppuccin-mocha';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  static const String _seedColorKey = 'user_seed_color';
  static const String _lastManualSeedColorKey =
      'user_last_manual_seed_color'; // 用户手动选择的种子色，用于在关闭动态配色时恢复
  static const String _themeKeyKey = 'user_theme_key';

  static const String _fontFamilyKey = 'user_font_family';
  String _currentFontFamily = 'Misans'; // 默认字体

  ThemeProvider() {
    initialize();
  }

  Color get currentSeedColor => _currentSeedColor;

  Color get lastManualSeedColor => _lastManualSeedColor;

  String get currentFontFamily => _currentFontFamily;

  ColorScheme get currentColorScheme {
    return ColorScheme.fromSeed(seedColor: _currentSeedColor);
  }

  /// B1：委托统一构建器 buildAppTheme（命名主题显式色板 + VxTypography
  /// 层级 + VxPalette 扩展），不再 fromSeed/misansTextTheme。
  ThemeData get lightThemeData => buildAppTheme(
    currentThemeKey,
    Brightness.light,
    dynamicSeed: dynamicSeed,
    fontFamily: _currentFontFamily,
    platform: defaultTargetPlatform,
  ).makeMouseClickable();

  ThemeData get darkThemeData => buildAppTheme(
    currentThemeKey,
    Brightness.dark,
    dynamicSeed: dynamicSeed,
    fontFamily: _currentFontFamily,
    platform: defaultTargetPlatform,
  ).makeMouseClickable();

  /// 命名主题切换（B1）：乐观更新 + 持久化 + notifyListeners。
  /// 推 key 即回到命名主题模式，清除动态种子覆盖（动态色路径由 main.dart
  /// 的 DynamicColorBuilder 持续经 setSeedColor 重新注入，不受影响）。
  Future<void> setThemeKey(String key) async {
    final keyChanged = _themeKey != key;
    final seedCleared = _dynamicSeed != null;
    if (!keyChanged && !seedCleared) return;
    _themeKey = key;
    _dynamicSeed = null;
    notifyListeners();
    if (keyChanged) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKeyKey, key);
    }
  }

  Future<void> setSeedColor(Color newColor, {bool isManual = false}) async {
    if (_currentSeedColor != newColor || _dynamicSeed != newColor) {
      _currentSeedColor = newColor;
      _dynamicSeed = newColor;
      notifyListeners();
      await _saveSeedColor(newColor);
    }
    if (isManual) {
      _lastManualSeedColor = newColor;
      await _saveLastManualSeedColor(newColor);
    }
  }

  Future<void> _loadSeedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final int? savedColorValue = prefs.getInt(_seedColorKey);
    if (savedColorValue != null) {
      _currentSeedColor = Color(savedColorValue);
    }
  }

  Future<void> _saveSeedColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color.toARGB32());
  }

  Future<void> _saveLastManualSeedColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastManualSeedColorKey, color.toARGB32());
  }

  Future<void> _loadLastManualSeedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final int? savedColorValue = prefs.getInt(_lastManualSeedColorKey);
    if (savedColorValue != null) {
      _lastManualSeedColor = Color(savedColorValue);
    }
  }

  Future<void> restoreLastManualColor() async {
    final color = _lastManualSeedColor;
    if (_currentSeedColor != color) {
      _currentSeedColor = color;
      notifyListeners();
      await _saveSeedColor(color);
    }
  }

  // 迁移手动选择的种子色键名
  // 如果用户手动选择的种子色键名不存在，从种子色键中获取颜色值并迁移到用户手动选择的种子色键名
  // 这是为了在应用升级时，用户手动选择的种子色能够被恢复
  Future<void> _migrateManualColorKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_lastManualSeedColorKey)) {
      final existingSeed = prefs.getInt(_seedColorKey);
      if (existingSeed != null) {
        await prefs.setInt(_lastManualSeedColorKey, existingSeed);
      }
    }
  }

  void toggleDarkMode() async {
    switch (_themeMode) {
      case ThemeMode.light:
        _themeMode = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        _themeMode = ThemeMode.system;
        break;
      case ThemeMode.system:
        _themeMode = ThemeMode.light;
        break;
    }
    notifyListeners();

    setThemeMode(_themeMode);
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_theme_mode', _themeModeToString(_themeMode));
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _stringToThemeMode(String? modeString) {
    switch (modeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? modeString = prefs.getString('user_theme_mode');
    _themeMode = _stringToThemeMode(modeString);
  }

  Future<void> _loadFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFont = prefs.getString(_fontFamilyKey);
    if (savedFont != null && savedFont.isNotEmpty) {
      _currentFontFamily = savedFont;
    }
  }

  Future<void> _loadThemeKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_themeKeyKey);
    if (savedKey != null && savedKey.isNotEmpty) {
      _themeKey = savedKey;
    }
  }

  void setFontFamily(String fontFamily) async {
    if (_currentFontFamily == fontFamily) return; // 没变就直接退出
    _currentFontFamily = fontFamily;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, fontFamily);
  }

  void resetFontFamily() async {
    _currentFontFamily = 'Misans'; // 默认字体
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fontFamilyKey);
  }

  Future<void> initialize() async {
    await Future.wait([
      _loadSeedColor(),
      _loadDarkMode(),
      _loadFontFamily(),
      _loadThemeKey(),
    ]);
    await _migrateManualColorKey();
    await _loadLastManualSeedColor();
    notifyListeners();
  }

  Future<void> loadCurrentFont(SystemFonts systemFonts) async {
    if (_currentFontFamily != 'Misans') {
      await systemFonts.loadFont(_currentFontFamily);
      notifyListeners();
    }
  }
}

class DesktopButtonTheme {
  const DesktopButtonTheme._(); // 防止实例化

  static const WidgetStateProperty<MouseCursor> clickableCursor =
      WidgetStatePropertyAll(SystemMouseCursors.click);

  static const TextButtonThemeData textButtonTheme = TextButtonThemeData(
    style: ButtonStyle(mouseCursor: clickableCursor),
  );

  static const ElevatedButtonThemeData elevatedButtonTheme =
      ElevatedButtonThemeData(style: ButtonStyle(mouseCursor: clickableCursor));

  static const OutlinedButtonThemeData outlinedButtonTheme =
      OutlinedButtonThemeData(style: ButtonStyle(mouseCursor: clickableCursor));
}

// makeMouseClickable 已上移至 theme/app_theme.dart 的公有扩展
// MouseClickableTheme（B1）：统一构建器与 vendored ThemeProvider 共用。
