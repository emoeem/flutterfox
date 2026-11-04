/// 搜索页：搜索框 + 音源筛选 + 结果列表（触底加载更多）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/empty_state.dart';
import 'song_tile.dart';

class SearchPage extends StatefulWidget {
  final AppModel model;

  const SearchPage(this.model, {super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  /// 选中的音源过滤；null = 聚合全音源。
  String? _source;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String keyword) {
    _debounce?.cancel();
    if (keyword.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.model.dispatch(
        bridge.FfiCommand.search(keyword: keyword.trim(), source: _source),
      );
    });
  }

  void _selectSource(String? source) {
    if (_source == source) return;
    setState(() => _source = source);
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    widget.model.dispatch(
      bridge.FfiCommand.search(keyword: keyword, source: source),
    );
  }

  Widget _item(BuildContext context, int index) {
    if (index >= widget.model.state.search.items.length) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SongTile(widget.model, widget.model.state.search.items[index]);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.model.state.search;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200 &&
            state.hasMore &&
            !state.loading &&
            state.keyword.isNotEmpty) {
          widget.model.dispatch(bridge.FfiCommand.searchMore(
            keyword: state.keyword,
            page: state.page + 1,
          ));
        }
        return false;
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                pageTitle(context, '搜索'),
                SearchBar(
                  controller: _controller,
                  hintText: '搜索歌曲 / 歌手',
                  onChanged: _onChanged,
                ),
                const SizedBox(height: 8),
                // 音源筛选：聚合 + 已启用音源（能力位来自 Rust 快照）。
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('聚合'),
                          selected: _source == null,
                          onSelected: (_) => _selectSource(null),
                        ),
                      ),
                      for (final item in widget.model.state.sources)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(item.name),
                            selected: _source == item.id,
                            onSelected: (_) => _selectSource(item.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.items.isEmpty
                ? _emptyState(context, state)
                : LayoutBuilder(builder: (context, constraints) {
                    // 桌面双列网格，手机保持单列列表
                    final wide = constraints.maxWidth >= 840;
                    final itemCount = state.items.length +
                        (state.hasMore && state.loading ? 1 : 0);
                    if (!wide) {
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: itemCount,
                        itemBuilder: (context, index) =>
                            _item(context, index),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 480,
                        mainAxisExtent: 76,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) => _item(context, index),
                    );
                  }),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, bridge.SearchDto state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = state.error;
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: '搜索失败',
        subtitle: error,
        action: TextButton(
          onPressed: () => widget.model.dispatch(
            bridge.FfiCommand.search(keyword: state.keyword),
          ),
          child: const Text('重试'),
        ),
      );
    }
    return EmptyState(
      icon: Icons.search_off,
      title: state.keyword.isEmpty ? '输入关键词开始搜索' : '没有结果',
      subtitle: state.keyword.isEmpty ? '支持歌曲名与歌手名' : null,
    );
  }
}
