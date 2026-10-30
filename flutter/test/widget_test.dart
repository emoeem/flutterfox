import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/theme/seed_colors.dart';
import 'package:voicefox_flutter/src/theme/voicefox_theme.dart';

void main() {
  testWidgets('主题 seed 表完整且构建 ThemeData 不抛异常', (tester) async {
    expect(kSeedThemes.length, 16);
    for (final seed in kSeedThemes) {
      expect(seed.key, isNot(contains(' ')));
      final theme = buildVoicefoxTheme(seed.key, Brightness.dark);
      expect(theme.colorScheme.primary, isNot(0));
    }
  });

  test('AppModel 初始状态为空快照', () {
    final model = AppModel();
    expect(model.ready, isFalse);
    expect(model.state.queue, isEmpty);
  });
}
