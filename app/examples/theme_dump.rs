//! 导出 ratatui-themes 16 套主题的 seed 数据，供 Flutter 侧生成同源 ColorScheme。
//! 运行：cargo run --release -p voicefox-app --example theme_dump
//! 输出格式：name|bg_hex|fg_hex|accent_hex|is_dark

fn main() {
    for name in ratatui_themes::ThemeName::all() {
        let p = name.palette();
        println!(
            "{:?}|{}|{}|{}|{}",
            name,
            hex(&p.bg),
            hex(&p.fg),
            hex(&p.accent),
            p.is_dark()
        );
    }
}

fn hex(color: &ratatui::style::Color) -> String {
    match color {
        ratatui::style::Color::Rgb(r, g, b) => format!("#{r:02X}{g:02X}{b:02X}"),
        _ => "#000000".to_string(),
    }
}
