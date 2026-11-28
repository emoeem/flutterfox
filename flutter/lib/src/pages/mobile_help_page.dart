/// 帮助页手机形态（Batch C-C C-07 / R6，SR-03 手机 8 页复用桌面收敛）。
///
/// 内容按移动端能力过滤（spec §5 / handoff C-C：过滤桌面快捷键段，不展示
/// 不适用的桌面窗口快捷键或不可执行入口）：
/// - 保留：功能地图 / 自建歌单 / 关于（版本与平台能力来自真实配置，
///   `appVersion` 单源沿用桌面 help_page.dart 导出）；
/// - 移除：桌面「播放页快捷键」（纯键盘段，触屏无对应能力）；
/// - 交互说明改触控语义（长按/点按），无桌面专属窗口条目。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../design_system/design_tokens.dart';
import 'help_page.dart' show appVersion;

/// 帮助页（手机）。
class MobileHelpPage extends StatelessWidget {
  const MobileHelpPage({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帮助')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _section(
              context,
              icon: Icons.map_outlined,
              title: '功能地图',
              rows: [
                ('发现', '多音源歌单、排行榜与分类，按音源筛选'),
                ('搜索', '歌曲、专辑、歌手与歌单，结果按音源聚合'),
                ('曲库', '收藏、历史、自建歌单与本地音乐'),
                ('下载', '并发分块下载，写入标签与封面'),
                ('播放页', '点按封面下方控件走带；长按歌曲行打开更多操作'),
              ],
            ),
            _section(
              context,
              icon: Icons.playlist_add,
              title: '自建歌单',
              rows: [
                ('新建', '曲库页「新建歌单」；收藏的歌单会显示在曲库'),
                ('加歌', '歌曲行长按 → 加入歌单；搜索、歌单详情同样可用'),
                ('同步', '账号歌单镜像来自远端缓存，可在设置中同步'),
              ],
            ),
            _section(
              context,
              icon: Icons.info_outline,
              title: '关于',
              rows: [
                ('版本', appVersion),
                ('音源', '${model.state.sources.length} 个音源接入'),
                ('播放内核', '桌面 libmpv / 手机系统播放器'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<(String, String)> rows,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VxRadius.lg),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: VxTypography.sectionTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final (name, description) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        name,
                        style: VxTypography.titleSm.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        description,
                        style: VxTypography.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
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
