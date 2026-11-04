// Voicefox local stub for package:system_fonts.
// The vendored myune font picker uses it to enumerate installed fonts; on
// voicefox we keep the built-in font list instead, so every call is a no-op.
class SystemFonts {
  SystemFonts();

  void rescan() {}

  /// Font file name → absolute path. Empty: callers fall back to their
  /// bundled/default font set.
  Map<String, String> getFontMap() => <String, String>{};

  Future<String?> loadFont(String fontName) async => null;
}
