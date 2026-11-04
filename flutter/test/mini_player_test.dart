import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/main.dart';
import 'package:voicefox_flutter/src/app_model.dart';

void main() {
  testWidgets('引导完成前显示骨架屏；mini player 在无歌时不可见', (tester) async {
    final model = AppModel();
    // 不调用 bootstrapDesktop：Rust 侧未就绪，走 _BootstrapScreen 分支
    await tester.pumpWidget(VoicefoxApp(model: model));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });
}
