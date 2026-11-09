import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/library_page.dart';
import 'package:voicefox_flutter/src/widgets/push_dialog.dart';

bridge.SongDto _song(String name) => bridge.SongDto(
  id: name,
  source: 'local',
  name: name,
  singer: '歌手',
  albumName: '专辑',
  durationMs: BigInt.from(180000),
);

void main() {
  testWidgets('推送预览展示追加差异并要求确认', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPushDialog(
                context,
                model,
                localName: '本地歌单',
                songs: [_song('本地曲目')],
                isFavorites: false,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    model.debugSetPush(
      phase: 'preview',
      preview: const bridge.PushPreviewDto(
        targetName: '远端歌单',
        targetKind: '歌单',
        localSongs: 3,
        remoteSongs: 8,
        additions: 1,
        matched: 2,
        unmatched: 0,
        samples: ['新增曲目 - 歌手'],
      ),
    );
    await tester.pump();

    expect(find.text('远端歌单 · 歌单'), findsOneWidget);
    expect(find.text('将追加 1 首 · 已匹配 2 首'), findsOneWidget);
    expect(find.text('确认推送'), findsOneWidget);
  });

  testWidgets('收藏页可显示账号红心镜像曲目', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LibraryPage(model))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('网易云'));
    await tester.pump();
    model.debugBrowseLoaded(
      kind: AppModel.accountFavoritesKind,
      source: 'wy',
      id: 'favorites',
      songs: [_song('镜像红心曲目')],
    );
    await tester.pumpAndSettle();

    expect(find.text('镜像红心曲目'), findsOneWidget);
  });
}
