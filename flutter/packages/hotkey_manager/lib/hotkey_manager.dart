// Voicefox local stub for package:hotkey_manager.
// Global hotkeys are a P1 feature; this stub keeps the vendored myune settings
// UI compiling without pulling a native keyboard hook (keybinder-3.0).
import 'package:flutter/services.dart';

enum HotKeyModifier { control, alt, shift, meta }

enum HotKeyScope { system, inapp }

class HotKey {
  const HotKey({
    this.identifier,
    required this.key,
    this.modifiers = const [],
    this.scope = HotKeyScope.system,
  });

  factory HotKey.fromJson(Map<String, dynamic> json) => HotKey(
        identifier: json['identifier'] as String?,
        key: PhysicalKeyboardKey(json['key'] as int? ?? 32),
        modifiers: const [],
      );

  final String? identifier;
  final PhysicalKeyboardKey key;
  final List<HotKeyModifier> modifiers;
  final HotKeyScope scope;

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'key': key.usbHidUsage,
      };
}

class HotKeyManager {
  HotKeyManager._();

  static final HotKeyManager instance = HotKeyManager._();

  Future<void> register(
    HotKey hotKey, {
    Function(HotKey)? keyDownHandler,
    Function(HotKey)? keyUpHandler,
  }) async {}

  Future<void> unregister(HotKey hotKey) async {}

  Future<void> unregisterAll() async {}
}

/// Top-level instance, matching hotkey_manager 0.2.x.
final HotKeyManager hotKeyManager = HotKeyManager.instance;
