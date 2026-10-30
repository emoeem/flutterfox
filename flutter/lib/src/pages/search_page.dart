/// 搜索页：搜索框 + 音源筛选 + 结果列表（触底加载更多）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
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
      widget.model
          .dispatch(bridge.FfiCommand.search(keyword: keyword.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.model.state.search;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200 &&
            state.hasMore &&
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SearchBar(
              controller: _controller,
              hintText: '搜索歌曲 / 歌手',
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: state.items.isEmpty
                ? Center(
                    child: Text(
                      state.keyword.isEmpty ? '输入关键词开始搜索' : '没有结果',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: state.items.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return SongTile(widget.model, state.items[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
