/// 库页：收藏歌曲 / 历史 两个 tab。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import 'song_tile.dart';

class LibraryPage extends StatelessWidget {
  final AppModel model;

  const LibraryPage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: '收藏 ${model.state.favorites.length}'),
              Tab(text: '历史 ${model.state.history.length}'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Favorites(model),
                _History(model),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Favorites extends StatelessWidget {
  final AppModel model;

  const _Favorites(this.model);

  @override
  Widget build(BuildContext context) {
    final favorites = model.state.favorites;
    if (favorites.isEmpty) {
      return const Center(child: Text('还没有收藏，搜索页点击心形添加'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: favorites.length,
      itemBuilder: (context, index) =>
          SongTile(model, favorites[index], index: index),
    );
  }
}

class _History extends StatelessWidget {
  final AppModel model;

  const _History(this.model);

  @override
  Widget build(BuildContext context) {
    final history = model.state.history;
    if (history.isEmpty) {
      return const Center(child: Text('播放记录为空'));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton(
              onPressed: () => model
                  .dispatch(const bridge.FfiCommand.historyClear()),
              child: const Text('清空历史'),
            ),
          ),
        ),
        for (var i = 0; i < history.length; i++)
          SongTile(model, history[i], index: i),
      ],
    );
  }
}
