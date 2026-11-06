/// 主导航请求总线：让页面内部（如首页快捷入口）请求 shell 切换导航项，
/// 避免页面反向 import shell 造成循环依赖。
library;

import 'package:flutter/foundation.dart';

/// 请求切换到的导航索引；shell 消费后置回 null。
final ValueNotifier<int?> navRequest = ValueNotifier(null);

/// 请求打开全屏播放页（Phase 3 NowPlayingPage）；shell 消费后置回 false。
/// 页面（如首页「正在播放」Hero）经此请求，避免反向 import shell。
final ValueNotifier<bool> nowPlayingRequest = ValueNotifier(false);
