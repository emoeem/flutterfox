// Voicefox playbar（旧入口）。
//
// RETIRED (Phase 2)：全局播放栏的唯一实现已迁移到 `src/player/player_bar.dart`
// （92px、顶部 2px 进度线、左/中/右三区、时长未知显示 --:--）。
// 本文件降级为薄适配：保留旧类名与构造签名，内部直接委托新 PlayerBar，
// 供尚存的旧引用（如旧壳）不破坏编译；请勿在此继续添加功能。
import 'package:flutter/material.dart';

import '../app_model.dart';
import '../player/player_bar.dart';

/// 旧播放栏入口：委托给 `player/player_bar.dart` 的全局实现。
@Deprecated('Phase 2 起请直接使用 player/player_bar.dart 的 PlayerBar')
class VoicefoxPlaybar extends StatelessWidget {
  const VoicefoxPlaybar({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return PlayerBar(model: model);
  }
}
