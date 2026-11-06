/// Voicefox 设计系统 Token（Phase 1，§6 Design System）。
///
/// 真源参照：
/// - 视觉：`flutterfox-desktop-ui-concept.html` 的 CSS 变量（唯一视觉目标参照）；
/// - 计划书：`flutterfox-ui-redesign-plan-v2.md` §6.2 色彩 / §6.3 字号 /
///   §6.4 间距圆角 / §6.5 动效。
///
/// 深色 Token 值与概念稿 CSS 变量逐项对应（见各类注释）；浅色为独立调校
/// 对比度的独立色板（计划书 §6.2：不允许只反转深色）。
library;

import 'package:flutter/material.dart';

/// 深色（默认）色彩 Token。注释标注对应的概念稿 CSS 变量。
abstract final class VxColors {
  /// 主窗口底色（--bg）。
  static const Color background = Color(0xFF15141A);

  /// 最深底色（概念稿 body 背景，用于最深容器 / scrim）。
  static const Color scrim = Color(0xFF0E0D12);

  /// 一级表面：Sidebar / PlayerBar / ContextPanel（--side）。
  static const Color surface1 = Color(0xFF191820);

  /// 二级表面：卡片、次级面板（--surface）。
  static const Color surface2 = Color(0xFF201F28);

  /// 三级表面：输入框、浮层（--surface2）。
  static const Color surface3 = Color(0xFF292733);

  /// Hover / Selected 容器（--surface3）。
  static const Color hover = Color(0xFF34313F);

  /// 分隔线（--line）。
  static const Color divider = Color(0xFF33303B);

  /// 主文本：标题、歌曲名（--text）。
  static const Color textPrimary = Color(0xFFF1EEF5);

  /// 次文本：歌手、说明（--muted）。
  static const Color textSecondary = Color(0xFFB5AFBF);

  /// 弱文本：辅助标签、禁用文字（--dim）。
  static const Color textMuted = Color(0xFF85808F);

  /// 主强调：播放按钮、进度、选中态（--accent）。
  static const Color accent = Color(0xFFCBA6F7);

  /// 次强调 / 渐变端点（--accent2）。
  static const Color accentDeep = Color(0xFFA98BDD);

  /// 强调色之上的文本（.pill / .logo 文字色）。
  static const Color onAccent = Color(0xFF21182D);

  /// 播放圆钮图标色（.play 的 color）。
  static const Color onPlayIcon = Color(0xFF221D2C);

  /// error 之上的文本（深色模式，error #E78284 偏亮需深色文字）。
  static const Color onError = Color(0xFF2C1114);

  /// 成功语义（--green）。
  static const Color success = Color(0xFFA6D189);

  /// 警告语义（计划书 §6.2；概念稿未定义该 CSS 变量）。
  static const Color warning = Color(0xFFE5C890);

  /// 错误语义（--red）。
  static const Color error = Color(0xFFE78284);
}

/// 浅色色彩 Token。独立调校对比度（正文色对底 ≥ 4.5:1），非深色反转。
abstract final class VxLightColors {
  /// 主窗口底色（暖白微紫，与深色同色相家族）。
  static const Color background = Color(0xFFFAF9FC);

  /// 最深容器 / scrim。
  static const Color scrim = Color(0xFF1A1622);

  /// 一级表面：Sidebar / PlayerBar。
  static const Color surface1 = Color(0xFFF1EEF7);

  /// 二级表面：卡片、次级面板。
  static const Color surface2 = Color(0xFFFFFFFF);

  /// 三级表面：输入框、浮层。
  static const Color surface3 = Color(0xFFECE8F4);

  /// Hover / Selected 容器。
  static const Color hover = Color(0xFFE4DFF0);

  /// 分隔线。
  static const Color divider = Color(0xFFE0DCE9);

  /// 主文本。对 background 对比约 14:1。
  static const Color textPrimary = Color(0xFF262032);

  /// 次文本。对 background 对比约 6.5:1。
  static const Color textSecondary = Color(0xFF5D5670);

  /// 弱文本。对 background 对比约 4.5:1。
  static const Color textMuted = Color(0xFF8B8499);

  /// 主强调：比深色版 #CBA6F7 明显加深，对 background 约 5.6:1。
  static const Color accent = Color(0xFF7C4DC0);

  /// 次强调 / 渐变端点。
  static const Color accentDeep = Color(0xFF6A3FAE);

  /// 强调色之上的文本。
  static const Color onAccent = Color(0xFFFFFFFF);

  /// 播放圆钮图标色（浅色下圆钮底为主文本深色，图标用底色）。
  static const Color onPlayIcon = Color(0xFFFAF9FC);

  /// error 之上的文本。
  static const Color onError = Color(0xFFFFFFFF);

  /// 成功语义（相对深色 #A6D189 加深到可读对比）。
  static const Color success = Color(0xFF2F7D24);

  /// 警告语义（相对深色 #E5C890 加深到可读对比）。
  static const Color warning = Color(0xFFB25E09);

  /// 错误语义（相对深色 #E78284 加深到可读对比）。
  static const Color error = Color(0xFFD20F39);

  /// 进度条轨道（浅色版 #45404E）。
  static const Color seekTrack = Color(0xFFDAD3E6);
}

/// 深色模式下的少量组件字面值（概念稿中非 CSS 变量的字面色）。
abstract final class VxDarkSurface {
  /// .hero 的 1px 边线。
  static const Color heroBorder = Color(0xFF393342);

  /// .seekbar 的轨道底色。
  static const Color seekTrack = Color(0xFF45404E);
}

/// Hero 渐变（深色）。值取自概念稿 `.hero` 的字面 CSS 值。
abstract final class VxDarkHero {
  /// .hero 的 1px 边线。
  static const Color border = VxDarkSurface.heroBorder;

  /// 线性渐变 112deg 起点。
  static const Color gradientStart = Color(0xFF373042);

  /// 线性渐变 55% 处。
  static const Color gradientMid = Color(0xFF272532);

  /// 线性渐变终点。
  static const Color gradientEnd = Color(0xFF1E1D26);

  /// 左上径向高光（#71609b88）。
  static const Color glow = Color(0x8871609B);

  /// 右上模糊光斑（#cba6f71c）。
  static const Color accentGlow = Color(0x1CCBA6F7);
}

/// Hero 渐变（浅色）。按浅色表面重排的等价层次，非反转。
abstract final class VxLightHero {
  /// .hero 边线的浅色对应。
  static const Color border = Color(0xFFDCD5EA);

  /// 线性渐变起点。
  static const Color gradientStart = Color(0xFFE7E0F2);

  /// 线性渐变 55% 处。
  static const Color gradientMid = Color(0xFFF2EFF8);

  /// 线性渐变终点。
  static const Color gradientEnd = Color(0xFFFAF9FC);

  /// 左上径向高光。
  static const Color glow = Color(0x55B79BE0);

  /// 右上模糊光斑。
  static const Color accentGlow = Color(0x24CBA6F7);
}

/// 缺封面占位渐变。值取自概念稿 `.art1`-`.art6`、`.hero-art`、`.context-art`。
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

  /// 按种子字符串（标题/歌手名）稳定选择一条渐变；同样的种子总是同一条。
  static LinearGradient forSeed(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    final colors = palette[hash % palette.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
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

  /// 页面内容内边距（§3.1：28，窄窗 20，超宽 32）。
  static const double pagePadding = 28;

  /// 区块间距（§4.1：30-36）。
  static const double sectionGap = 32;
}

/// 圆角 Token（§6.4：小按钮 8 / 输入框 10 / 封面卡 12 / Hero 18）。
abstract final class VxRadius {
  /// 小按钮、列表行内小元素。
  static const double sm = 8;

  /// 输入框、次级面板。
  static const double md = 10;

  /// 封面卡、卡片。
  static const double lg = 12;

  /// Hero / 大面板 / 对话框。
  static const double xl = 18;
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

/// 字号 Token（§6.3 + 概念稿补充层级）。
///
/// 标题层级 w600-w700，正文 w400；禁止把整个 TextTheme 压成 w400。
abstract final class VxTypography {
  /// Display 36/700：全屏播放页歌曲名、重要封面标题。
  static const TextStyle display = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.5,
  );

  /// H1 28/700：页面标题、专辑名、Hero 主标题。
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
  );

  /// H2 22/600（§6.3 写 650，落到 600 档）：区块大标题。
  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// 区块标题 18/700（概念稿 .section-head h3）。
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Title 16/600：歌曲名、卡片标题、主操作。
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// 小标题 13/600（概念稿 .track-name 13px）。
  static const TextStyle titleSm = TextStyle(
    fontSize: 13,
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

  /// 歌词当前行过渡。
  static const Duration lyricLine = Duration(milliseconds: 220);

  /// 列表 hover 背景淡入。
  static const Duration hoverFade = Duration(milliseconds: 120);

  /// 标准缓动。
  static const Curve standard = Curves.easeOutCubic;

  /// 强调缓动（大面板 / 全屏）。
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}
