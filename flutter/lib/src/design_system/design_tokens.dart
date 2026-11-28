/// Voicefox 设计系统 Token（V2 重设计，design-spec v1.0 冻结版）。
///
/// 真源参照：
/// - 视觉：`docs/redesign/ui-redesign-v2/design-spec.md`（v1.0 已冻结，
///   2026-11-28 用户确认）+ `mockups/index.html` 六屏原型；
/// - 色板体系：Catppuccin Mocha（深色）/ Latte（浅色）+ Mauve 强调；
///   表面层为深蓝灰分层（禁止大面积纯黑，spec §2）。
///
/// 深色 Token 值与 spec §2 色板表逐项对应（见各类注释）；浅色为 Latte
/// 同构镜像 + 独立调校对比度（不允许只反转深色）。
library;

import 'package:flutter/material.dart';

/// 深色（默认）色彩 Token。注释标注对应的 spec §2 token 名。
abstract final class VxColors {
  /// 主窗口底色（spec `base`，Mocha base 深蓝灰）。
  static const Color background = Color(0xFF1E1E2E);

  /// 最深底色（Mocha crust，用于最深容器 / scrim）。
  static const Color scrim = Color(0xFF11111B);

  /// 一级表面：Sidebar / PlayerBar / 抽屉（spec `elevated`，Mocha mantle）。
  static const Color surface1 = Color(0xFF181825);

  /// 二级表面：卡片、次级面板（spec `card`）。
  static const Color surface2 = Color(0xFF262638);

  /// 三级表面：输入框、浮层（spec `high`，Mocha surface0）。
  static const Color surface3 = Color(0xFF313244);

  /// Hover / Selected 容器（Mocha surface1）。
  static const Color hover = Color(0xFF45475A);

  /// 分隔线 / 边框（spec `line` 的不透明落点：低对比度灰紫）。
  static const Color divider = Color(0xFF3A3D54);

  /// 主文本：标题、歌曲名（spec `text-1`，Mocha text）。
  static const Color textPrimary = Color(0xFFCDD6F4);

  /// 次文本：歌手、说明（spec `text-2`，Mocha subtext0）。
  static const Color textSecondary = Color(0xFFA6ADC8);

  /// 弱文本：辅助标签、禁用文字（spec `text-3`，Mocha overlay1）。
  static const Color textMuted = Color(0xFF7F849C);

  /// 主强调：播放按钮、进度、选中态（spec `accent`，Mocha Mauve）。
  static const Color accent = Color(0xFFCBA6F7);

  /// 次强调 / 渐变端点。
  static const Color accentDeep = Color(0xFFA98BDD);

  /// 强调色之上的文本（按钮/徽标，spec：accent 底 + 深色图标）。
  static const Color onAccent = Color(0xFF191927);

  /// 播放圆钮图标色（accent 底之上）。
  static const Color onPlayIcon = Color(0xFF191927);

  /// error 之上的文本（error #F38BA8 偏亮需深色文字）。
  static const Color onError = Color(0xFF2C1114);

  /// 成功语义（Mocha green）。
  static const Color success = Color(0xFFA6D189);

  /// 警告语义（Mocha yellow）。
  static const Color warning = Color(0xFFE5C890);

  /// 错误语义（Mocha red，spec `danger`）。
  static const Color error = Color(0xFFE78284);
}

/// 浅色色彩 Token。Latte 同构镜像 + 独立调校对比度（正文色对底 >= 4.5:1），
/// 非深色反转。
abstract final class VxLightColors {
  /// 主窗口底色（Latte base）。
  static const Color background = Color(0xFFEFF1F5);

  /// 最深容器 / scrim（Mocha crust，图像 scrim 保持深色语义）。
  static const Color scrim = Color(0xFF11111B);

  /// 一级表面：Sidebar / PlayerBar（Latte mantle）。
  static const Color surface1 = Color(0xFFE6E9EF);

  /// 二级表面：卡片、次级面板。
  static const Color surface2 = Color(0xFFFFFFFF);

  /// 三级表面：输入框、浮层（Latte crust）。
  static const Color surface3 = Color(0xFFDCE0E8);

  /// Hover / Selected 容器（Latte surface0）。
  static const Color hover = Color(0xFFCCD0DA);

  /// 分隔线（低对比度灰紫）。
  static const Color divider = Color(0xFFD3D7E1);

  /// 主文本（Latte text）。对 background 对比约 9:1。
  static const Color textPrimary = Color(0xFF4C4F69);

  /// 次文本（Latte subtext1）。对 background 对比约 5.5:1。
  static const Color textSecondary = Color(0xFF5C5F77);

  /// 弱文本（Latte subtext0）。对 background 对比约 4.7:1。
  static const Color textMuted = Color(0xFF6C6F85);

  /// 主强调（Latte Mauve），对 background 约 5.4:1。
  static const Color accent = Color(0xFF8839EF);

  /// 次强调 / 渐变端点。
  static const Color accentDeep = Color(0xFF6A3FAE);

  /// 强调色之上的文本。
  static const Color onAccent = Color(0xFFFFFFFF);

  /// 播放圆钮图标色（浅色下圆钮底为主文本深色，图标用底色）。
  static const Color onPlayIcon = Color(0xFFEFF1F5);

  /// error 之上的文本。
  static const Color onError = Color(0xFFFFFFFF);

  /// 成功语义（相对深色 #A6D189 加深到可读对比）。
  static const Color success = Color(0xFF2F7D24);

  /// 警告语义（相对深色 #E5C890 加深到可读对比）。
  static const Color warning = Color(0xFFB25E09);

  /// 错误语义（相对深色 #E78284 加深到可读对比）。
  static const Color error = Color(0xFFD20F39);

  /// 进度条轨道（浅色版 #45404E）。
  /// 进度条轨道（Latte surface0 系）。
  static const Color seekTrack = Color(0xFFC9CDD9);
}

/// 深色模式下的少量组件字面值（spec §2/§4 的字面落点）。
abstract final class VxDarkSurface {
  /// Hero 的 1px 边线（低对比度灰紫，同 divider）。
  static const Color heroBorder = Color(0xFF3A3D54);

  /// 进度条轨道底色（spec `high`，Mocha surface0）。
  static const Color seekTrack = Color(0xFF313244);
}

/// Hero 渐变（深色）。蓝灰分层 + accent 低透明 wash（spec §4 Hero）。
abstract final class VxDarkHero {
  /// Hero 的 1px 边线。
  static const Color border = VxDarkSurface.heroBorder;

  /// 线性渐变起点（surface 系深端）。
  static const Color gradientStart = Color(0xFF2B2C40);

  /// 线性渐变 55% 处（spec `card`）。
  static const Color gradientMid = Color(0xFF262638);

  /// 线性渐变终点（spec `base`）。
  static const Color gradientEnd = Color(0xFF1E1E2E);

  /// 左上径向高光（accent 低透明，克制不炫技）。
  static const Color glow = Color(0x3ACBA6F7);

  /// 右上模糊光斑。
  static const Color accentGlow = Color(0x1CCBA6F7);
}

/// Hero 渐变（浅色）。按 Latte 表面重排的等价层次，非反转。
abstract final class VxLightHero {
  /// Hero 边线的浅色对应。
  static const Color border = Color(0xFFD3D7E1);

  /// 线性渐变起点。
  static const Color gradientStart = Color(0xFFE2E5EE);

  /// 线性渐变 55% 处。
  static const Color gradientMid = Color(0xFFEAEDF3);

  /// 线性渐变终点。
  static const Color gradientEnd = Color(0xFFEFF1F5);

  /// 左上径向高光。
  static const Color glow = Color(0x55B79BE0);

  /// 右上模糊光斑。
  static const Color accentGlow = Color(0x24CBA6F7);
}

/// 缺封面占位渐变（spec §5 封面系统：差异化自动艺术封面）。
///
/// 规则：真实封面永远优先（VxArtwork 链路）；本类只服务无封面回退。
/// 稳定 hash 同时决定 **配色** 与 **渐变方向槽位**，同实体永远同组合。
abstract final class VxCoverGradients {
  /// 渐变三色组（起点、中点、终点）。
  static const List<List<Color>> palette = [
    [Color(0xFFB77B72), Color(0xFF443850), Color(0xFF1B2437)], // .art1
    [Color(0xFFC8B08C), Color(0xFF66516F), Color(0xFF252B42)], // .art2
    [Color(0xFF87A4A0), Color(0xFF3D5267), Color(0xFF29243F)], // .art3
    [Color(0xFFE2A58B), Color(0xFF96577C), Color(0xFF29243F)], // .art4
    [Color(0xFF8BA4CE), Color(0xFF51517D), Color(0xFF202538)], // .art5
    [Color(0xFFB2A2CC), Color(0xFF735F91), Color(0xFF252638)], // .art6
    [Color(0xFFE7AE9B), Color(0xFF715A8D), Color(0xFF292638)], // .hero-art
    [Color(0xFFD4A28E), Color(0xFF735B8D), Color(0xFF24253C)], // .context-art
  ];

  /// 渐变方向槽位（spec §5：至少 5 个方向，避免所有封面同向）。
  static const List<(Alignment, Alignment)> directions = [
    (Alignment.topLeft, Alignment.bottomRight), // 135deg
    (Alignment.topRight, Alignment.bottomLeft), // 225deg
    (Alignment.bottomLeft, Alignment.topRight), // 45deg
    (Alignment.bottomRight, Alignment.topLeft), // 315deg
    (Alignment.topCenter, Alignment.bottomCenter), // 纵向
    (Alignment.centerLeft, Alignment.centerRight), // 横向
  ];

  /// 按种子字符串（标题/歌手名）稳定选择配色 + 方向；同样的种子总是同一条。
  static LinearGradient forSeed(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    final colors = palette[hash % palette.length];
    final direction = directions[(hash ~/ palette.length) % directions.length];
    return LinearGradient(
      begin: direction.$1,
      end: direction.$2,
      stops: const [0.0, 0.55, 1.0],
      colors: colors,
    );
  }
}

/// 间距 Token（§6.4：4px 基数）。
abstract final class VxSpacing {
  /// 基础间距单位。
  static const double unit = 4;

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// 页面内容内边距（spec §3：桌面 30，窄窗 20，超宽 32；手机 18）。
  static const double pagePadding = 30;

  /// 区块间距（§4.1：30-36）。
  static const double sectionGap = 32;
}

/// 圆角 Token（spec §3：控件 8-9 / 封面卡 10 / 面板 14 / 大封面 16）。
abstract final class VxRadius {
  /// 小按钮、列表行内小元素。
  static const double sm = 8;

  /// 输入框、次级面板、封面卡。
  static const double md = 10;

  /// 面板、卡片容器。
  static const double lg = 14;

  /// Hero / 大封面。
  static const double xl = 16;
}

/// TrackRow 三种密度（Phase 1 任务 4：50 / 58 / 66）。
abstract final class VxDensities {
  /// 紧凑行高。
  static const double trackRowCompact = 50;

  /// 标准行高。
  static const double trackRowStandard = 58;

  /// 舒适行高。
  static const double trackRowComfortable = 66;
}

/// 字号 Token（spec §3 字阶：display 26-28 / 页题 22 / 区题 16 / 正文 13.5-14 /
/// 说明 12-12.5 / 徽标 10.5）。
///
/// 标题层级 w600-w700，正文 w400；禁止把整个 TextTheme 压成 w400。
abstract final class VxTypography {
  /// Display 28/700：全屏播放页歌曲名、重要封面标题。
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
  );

  /// H1 22/700：页面标题、专辑名、Hero 主标题。
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// H2 18/600：区块大标题。
  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
  );

  /// 区块标题 16/600（spec 区题）。
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// Title 16/600：歌曲名、卡片标题、主操作。
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// 小标题 13.5/600（卡片题，spec 卡片题 13.5 两行钳制）。
  static const TextStyle titleSm = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// Body 14/400：普通信息。
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Caption 12/400：音源、时长、格式。
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Mono 12/500：进度时间、采样率、音质数值；tabular figures。
  static const TextStyle mono = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Eyebrow 10/700 字距 1.5（概念稿 .eyebrow / .group-label）。
  static const TextStyle eyebrow = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.5,
  );
}

/// 动效时长 Token（§6.5）。
abstract final class VxMotion {
  /// 主页面切换（160-200ms，取 180）。
  static const Duration pageTransition = Duration(milliseconds: 180);

  /// 右侧面板展开。
  static const Duration panelExpand = Duration(milliseconds: 240);

  /// 全屏播放页打开。
  static const Duration fullscreenOpen = Duration(milliseconds: 320);

  /// 歌曲封面切换 Crossfade。
  static const Duration coverCrossfade = Duration(milliseconds: 280);

  /// 播放/暂停图标。
  static const Duration iconToggle = Duration(milliseconds: 150);

  /// 歌词当前行过渡（spec §6：250ms 平滑过渡）。
  static const Duration lyricLine = Duration(milliseconds: 250);

  /// 列表 hover 背景淡入。
  static const Duration hoverFade = Duration(milliseconds: 120);

  /// 标准缓动。
  static const Curve standard = Curves.easeOutCubic;

  /// 强调缓动（大面板 / 全屏）。
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}
