/// 主导航请求总线：让页面内部（如首页快捷入口）请求 shell 切换导航项，
/// 避免页面反向 import shell 造成循环依赖。
library;

import 'package:flutter/widgets.dart';

/// 请求切换到的导航索引；shell 消费后置回 null。
final ValueNotifier<int?> navRequest = ValueNotifier(null);

/// 请求打开全屏播放页（Phase 3 NowPlayingPage）；shell 消费后置回 false。
/// 页面（如首页「正在播放」Hero）经此请求，避免反向 import shell。
final ValueNotifier<bool> nowPlayingRequest = ValueNotifier(false);

/// 桌面壳层中央内容区内嵌 Navigator（§7.5「播放器在页面切换、搜索、歌单
/// 详情和设置中持续存在」+ Phase 6 退出条件「播放器跨页面保持」）。
///
/// VoicefoxShell 把推入式详情页收进内容区：内容区内的页面用
/// `Navigator.of(context)` 即自动落到本 Navigator（就近解析），推入页
/// 只占中央内容列，Header/侧栏/右栏/PlayerBar 不被覆盖。位于内容区
/// 子树之外的入口（侧栏歌单项等）经本 key 显式推入。
/// 移动/平板壳不使用本 Navigator（全屏推入是移动形态的既定设计）。
final GlobalKey<NavigatorState> contentNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'content-navigator',
);
