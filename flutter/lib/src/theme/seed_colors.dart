/// 16 套主题的 seed 定义——与 TUI 同源。
///
/// 唯一来源：`app/examples/theme_dump.rs`（从 ratatui-themes 导出）。
/// 重新生成：`cargo run --release -p voicefox-app --example theme_dump`，
/// 然后按输出更新本表。禁止在别处另写色值（迁移规划铁律：不分叉）。
library;

class SeedTheme {
  final String key;
  final String label;
  final String bg;
  final String accent;
  final bool dark;

  const SeedTheme(this.key, this.label, this.bg, this.accent, this.dark);
}

const List<SeedTheme> kSeedThemes = [
  SeedTheme('dracula', 'Dracula', '#282A36', '#BD93F9', true),
  SeedTheme('one-dark-pro', 'One Dark Pro', '#282C34', '#61AFEF', true),
  SeedTheme('nord', 'Nord', '#2E3440', '#88C0D0', true),
  SeedTheme('catppuccin-mocha', 'Catppuccin Mocha', '#1E1E2E', '#89B4FA', true),
  SeedTheme('catppuccin-latte', 'Catppuccin Latte', '#EFF1F5', '#1E66F5', false),
  SeedTheme('gruvbox-dark', 'Gruvbox Dark', '#282828', '#FABD2F', true),
  SeedTheme('gruvbox-light', 'Gruvbox Light', '#FBF1C7', '#B57614', false),
  SeedTheme('tokyo-night', 'Tokyo Night', '#1A1B26', '#7AA2F7', true),
  SeedTheme('solarized-dark', 'Solarized Dark', '#002B36', '#268BD2', true),
  SeedTheme('solarized-light', 'Solarized Light', '#FDF6E3', '#268BD2', false),
  SeedTheme('monokai-pro', 'Monokai Pro', '#2D2A2E', '#FFD866', true),
  SeedTheme('rose-pine', 'Rosé Pine', '#191724', '#EBBCBA', true),
  SeedTheme('kanagawa', 'Kanagawa', '#1F1F28', '#7FB4CA', true),
  SeedTheme('everforest', 'Everforest', '#2F3537', '#83C178', true),
  SeedTheme('cyberpunk', 'Cyberpunk', '#0D0221', '#00FFFF', true),
  SeedTheme('midnight-commander', 'Midnight Commander', '#0000AA', '#00AAAA', true),
];

/// "#RRGGBB" → 不透明 ARGB。`Color(0x1E1E2E)` 的 alpha 是 0x00：
/// 直接传 24 位值会让页面底色完全透明（窗口透出纯黑），
/// 16 套 seed 主题与 FlClash 定制都受影响。
int hexOf(String value) =>
    0xFF000000 | int.parse(value.substring(1), radix: 16);
