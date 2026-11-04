/// 帮助与关于：功能地图、播放页快捷键、版本信息。
///
/// TUI 的 help.rs 是键位说明页；GUI 侧键位少，这里改为
/// 「能做什么 + 怎么操作」的入口页，并作为设置页的收尾分区。
library;

import 'package:flutter/material.dart';

/// 与 Cargo workspace `version` 保持同步（发版时一并改）。
const appVersion = '0.8.1';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: const [
        _Section(
          icon: Icons.keyboard_outlined,
          title: '播放页快捷键',
          rows: [('空格', '播放 / 暂停'), ('← / →', '快退 / 快进 5 秒'), ('Esc', '收起播放页')],
        ),
        _Section(
          icon: Icons.map_outlined,
          title: '功能地图',
          rows: [
            ('首页', '正在播放、曲库统计、快捷开关、最近在听'),
            ('队列', '当前播放队列，支持单曲移除、清空与当前曲高亮'),
            ('搜索', '多音源搜索；歌曲行的「更多」可下钻歌手 / 专辑'),
            ('曲库', '收藏、历史、自建歌单、本地音乐'),
            ('下载', '下载任务进度、取消与清理'),
            ('设置', '主题、动态取色、歌词、音量、播放模式、扫码登录'),
          ],
        ),
        _Section(
          icon: Icons.playlist_add_outlined,
          title: '自建歌单',
          rows: [
            ('新建', '曲库 → 自建歌单 → 新建歌单'),
            ('加歌', '任意歌曲行的「更多」菜单 → 加入歌单'),
            ('管理', '歌单行的菜单支持重命名、删除；详情页可移除单曲'),
          ],
        ),
        _Section(
          icon: Icons.info_outline,
          title: '关于',
          rows: [
            ('版本', 'voicefox $appVersion'),
            ('前端', 'Flutter + flutter_rust_bridge'),
            ('核心', '与 TUI 版共用同一套 Rust 播放 / 音源 / 存储实现'),
            ('数据', '配置与曲库由 Rust 端统一管理，升级前建议备份配置目录'),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;

  /// (名称, 说明) 行；名称用等宽字体，查看时更像一张速查表。
  final List<(String, String)> rows;

  const _Section({required this.icon, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 88,
                      child: Text(
                        row.$1,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: scheme.primary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: Theme.of(context).textTheme.bodyMedium,
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
