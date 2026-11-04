use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};

use lx_core::keybinding::migrate_legacy_settings_bindings;
use lx_core::model::config::{
    CURRENT_CONFIG_VERSION, Config, ThemeConfig, sanitize_status_bar_items,
};
use lx_core::model::source::SourceId;

const VERSION_1_DEFAULT_SOURCES: &[SourceId] = &[
    SourceId::Kw,
    SourceId::Kg,
    SourceId::Tx,
    SourceId::Wy,
    SourceId::Mg,
];

/// 接入 B 站之后的默认音源组合，供后续音源迁移判断。
const VERSION_10_DEFAULT_SOURCES: &[SourceId] = &[
    SourceId::Kw,
    SourceId::Kg,
    SourceId::Tx,
    SourceId::Wy,
    SourceId::Mg,
    SourceId::Bili,
];
const VERSION_11_DEFAULT_SOURCES: &[SourceId] = &[
    SourceId::Kw,
    SourceId::Kg,
    SourceId::Tx,
    SourceId::Wy,
    SourceId::Mg,
    SourceId::Bili,
    SourceId::Qianqian,
];
const VERSION_12_DEFAULT_SOURCES: &[SourceId] = &[
    SourceId::Kw,
    SourceId::Kg,
    SourceId::Tx,
    SourceId::Wy,
    SourceId::Mg,
    SourceId::Bili,
    SourceId::Qianqian,
    SourceId::Joox,
];
const VERSION_13_DEFAULT_SOURCES: &[SourceId] = &[
    SourceId::Kw,
    SourceId::Kg,
    SourceId::Tx,
    SourceId::Wy,
    SourceId::Mg,
    SourceId::Bili,
    SourceId::Qianqian,
    SourceId::Joox,
    SourceId::Fivesing,
];
const VERSION_15_DEFAULT_SOURCES: &[SourceId] = &[
    SourceId::Kw,
    SourceId::Kg,
    SourceId::Tx,
    SourceId::Wy,
    SourceId::Mg,
    SourceId::Bili,
    SourceId::Qianqian,
    SourceId::Joox,
    SourceId::Fivesing,
    SourceId::Jamendo,
];

/// 正常配置只会有几 KB。ConfigDto 往返 bug 曾把 `play_mode` 写成
/// 128MB 的转义引号串，超大文件直接按损坏处理，避免启动时白读白解析。
const MAX_CONFIG_BYTES: u64 = 4 * 1024 * 1024;

/// `play_mode` 的合法 token，与 `PlayerConfig::default` 保持一致。
const VALID_PLAY_MODES: &[&str] = &["none", "list-loop", "single-loop", "random"];

/// 加载配置：优先读用户配置文件，否则用默认值
pub fn load(custom_path: &str) -> anyhow::Result<(Config, PathBuf)> {
    let config_path = resolve_config_path(custom_path);

    if let Ok(metadata) = fs::metadata(&config_path)
        && metadata.len() > MAX_CONFIG_BYTES
    {
        quarantine_corrupted(&config_path, "文件超过 4MB")?;
        return default_config_at(&config_path);
    }

    match fs::read_to_string(&config_path) {
        Ok(content) => {
            let mut config: Config = match toml::from_str(&content) {
                Ok(config) => config,
                Err(error) => {
                    // 解析失败的存量损坏（如旧 bug 写出的大写 quality 枚举名）：
                    // 备份后回默认配置，不能让程序起不来。
                    quarantine_corrupted(&config_path, &format!("解析失败: {error}"))?;
                    return default_config_at(&config_path);
                }
            };
            let mut changed = sanitize_corrupted_fields(&mut config);
            changed |= migrate_legacy_config(&mut config);
            if changed {
                save(&config, &config_path)?;
            }
            Ok((config, config_path))
        }
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            default_config_at(&config_path)
        }
        Err(error) => Err(error.into()),
    }
}

/// 把默认配置写到 `path`（配置文件不存在时的原逻辑）。
fn default_config_at(config_path: &std::path::Path) -> anyhow::Result<(Config, PathBuf)> {
    let config = Config::default();
    save(&config, config_path)?;
    Ok((config, config_path.to_path_buf()))
}

/// 把损坏的配置文件改名留档（不删除，用户可手工找回），随后由调用方写默认配置。
fn quarantine_corrupted(config_path: &std::path::Path, reason: &str) -> anyhow::Result<()> {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|elapsed| elapsed.as_nanos())
        .unwrap_or(0);
    let backup = config_path.with_file_name(format!(
        "{}.corrupt-{unique}",
        config_path.file_name().unwrap_or_default().to_string_lossy(),
    ));
    tracing::warn!(
        "配置文件损坏（{reason}），已备份到 {} 并改用默认配置",
        backup.display()
    );
    match fs::rename(config_path, &backup) {
        Ok(()) => Ok(()),
        // 文件可能已被并发进程挪走；不存在视为已隔离。
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.into()),
    }
}

/// 与版本迁移无关的字段修复，每次加载都执行。
///
/// ConfigDto 往返 bug 曾用 `Debug` 格式化写回 `play_mode`，每次保存多一层
/// 引号转义，实测把配置膨胀到 134MB。非法 token 在这里重置回默认，
/// `load` 随后的 `save` 会把文件恢复到 KB 级。
fn sanitize_corrupted_fields(config: &mut Config) -> bool {
    if VALID_PLAY_MODES.contains(&config.player.play_mode.as_str()) {
        return false;
    }
    tracing::warn!(
        "检测到损坏的 play_mode（{} 字节），已重置为 list-loop",
        config.player.play_mode.len()
    );
    config.player.play_mode = "list-loop".to_string();
    true
}

fn migrate_legacy_config(config: &mut Config) -> bool {
    // 主题迁移只对未记录过版本的配置执行：用户若刻意把四色配成旧默认值，
    // 反复执行会把整个主题静默替换成 Mocha。
    let mut changed = if config.version < 1 {
        migrate_legacy_theme(config)
    } else {
        false
    };
    changed |= sanitize_status_bar_items(&mut config.ui.status_bar_items);
    if config.version < 1 {
        if config.source.enabled == [SourceId::Kw] {
            config.source.enabled = VERSION_1_DEFAULT_SOURCES.to_vec();
        }
        config.version = 1;
        changed = true;
    }
    if config.version < 2 {
        if same_sources(&config.source.enabled, VERSION_1_DEFAULT_SOURCES) {
            config.source.enabled.push(SourceId::Bili);
        }
        config.version = 2;
        changed = true;
    }
    if config.version < 3 {
        // 旧版本曾把 local_music.enabled 的默认值保存为 false，导致已经
        // 配置过目录的用户升级后不会自动扫描。只在版本迁移时恢复一次；
        // 版本 3 之后用户主动关闭仍会被保留。
        if !config.local_music.paths.is_empty() && !config.local_music.enabled {
            config.local_music.enabled = true;
        }
        config.version = 3;
        changed = true;
    }
    if config.version < 4 {
        // 通知原先位于 [ui]，迁移到独立的 [notification]，保留用户已有
        // 的开关和停留时间；缺失字段继续使用新的默认值。
        if let Some(enabled) = config.ui.show_notifications {
            config.notification.in_app = enabled;
        }
        if let Some(timeout) = config.ui.notification_timeout {
            config.notification.in_app_timeout = timeout;
        }
        config.ui.show_notifications = None;
        config.ui.notification_timeout = None;
        config.version = 4;
        changed = true;
    }
    if config.version < 5 {
        config.player.history_limit = config.player.history_limit.max(1);
        config.version = 5;
        changed = true;
    }
    if config.version < 6 {
        config.version = 6;
        changed = true;
    }
    if config.version < 7 {
        // 新增播放器控制项均带有 serde(default)，旧配置只需提升版本即可。
        config.version = 7;
        changed = true;
    }
    if config.version < 8 {
        // Fade/EQ/ReplayGain clip fields also have serde defaults; bump the
        // version after deserialization so the next save records the schema.
        config.version = 8;
        changed = true;
    }
    if config.version < 9 {
        migrate_legacy_settings_bindings(&mut config.keybindings);
        config.version = 9;
        changed = true;
    }
    if config.version < 10 {
        // 新增 [download] 下载配置，字段均有 serde 默认值，旧配置提升版本即可。
        config.version = 10;
        changed = true;
    }
    if config.version < 11 {
        if same_sources(&config.source.enabled, VERSION_10_DEFAULT_SOURCES) {
            config.source.enabled.push(SourceId::Qianqian);
        }
        config.version = 11;
        changed = true;
    }
    if config.version < 12 {
        if same_sources(&config.source.enabled, VERSION_11_DEFAULT_SOURCES) {
            config.source.enabled.push(SourceId::Joox);
        }
        config.version = 12;
        changed = true;
    }
    if config.version < 13 {
        if same_sources(&config.source.enabled, VERSION_12_DEFAULT_SOURCES) {
            config.source.enabled.push(SourceId::Fivesing);
        }
        config.version = 13;
        changed = true;
    }
    if config.version < 14 {
        if same_sources(&config.source.enabled, VERSION_13_DEFAULT_SOURCES) {
            config.source.enabled.push(SourceId::Jamendo);
        }
        config.version = 14;
        changed = true;
    }
    if config.version < 15 {
        // Apple Music 只有 30 秒试听，因此不自动加入默认音源。
        config.version = 15;
        changed = true;
    }
    if config.version < 16 {
        if same_sources(&config.source.enabled, VERSION_15_DEFAULT_SOURCES) {
            config.source.enabled.push(SourceId::Soda);
        }
        config.version = 16;
        changed = true;
    }
    if config.version < 17 {
        // 新增 source.js_first、integration.now_playing、
        // integration.listenbrainz_token，字段均有 serde 默认值，旧配置
        // 提升版本即可（js_first=false 保持内置音源先行的默认顺序）。
        config.version = 17;
        changed = true;
    }
    if config.version > CURRENT_CONFIG_VERSION {
        // 用户可能带着更高版本的配置降级运行：只警告不 panic（debug_assert
        // 会在开发构建直接崩溃），字段由 serde default 兜底。
        tracing::warn!(
            "配置文件版本 {} 高于当前支持的 {}，部分新字段将被忽略",
            config.version,
            CURRENT_CONFIG_VERSION
        );
    }
    changed
}

fn same_sources(left: &[SourceId], right: &[SourceId]) -> bool {
    left.len() == right.len() && right.iter().all(|source| left.contains(source))
}

fn migrate_legacy_theme(config: &mut Config) -> bool {
    let theme = &config.theme;
    let uses_original_defaults = theme.accent.eq_ignore_ascii_case("cyan")
        && theme.text.eq_ignore_ascii_case("white")
        && theme.muted.eq_ignore_ascii_case("dark_gray")
        && theme.border.eq_ignore_ascii_case("cyan");
    if uses_original_defaults {
        config.theme = ThemeConfig::default();
    }
    uses_original_defaults
}

/// 获取配置文件路径: ~/.config/voicefox/config.toml（复用 crate::default_config_path）
pub fn config_path() -> PathBuf {
    crate::default_config_path()
}

fn resolve_config_path(custom_path: &str) -> PathBuf {
    let custom_path = custom_path.trim();
    if custom_path.is_empty() {
        return config_path();
    }
    if let Some(relative) = custom_path.strip_prefix("~/")
        && let Some(home) = dirs::home_dir()
    {
        return home.join(relative);
    }
    PathBuf::from(custom_path)
}

/// 保存配置到文件
pub fn save(config: &Config, path: &std::path::Path) -> anyhow::Result<()> {
    let toml_str = toml::to_string_pretty(config)?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    save_atomic(path, toml_str.as_bytes())?;
    Ok(())
}

/// 原子写入配置文件：先写同目录临时文件再 rename。
///
/// 音量、播放模式等操作会高频触发配置保存，直接覆盖可能在进程崩溃或断电时
/// 留下半个配置文件；临时文件 + rename 保证目标文件要么完整要么保持旧内容。
fn save_atomic(path: &std::path::Path, content: &[u8]) -> std::io::Result<()> {
    let temp_path = path.with_file_name(format!(
        "{}.tmp-{}-{}",
        path.file_name().unwrap_or_default().to_string_lossy(),
        std::process::id(),
        CONFIG_TEMP_SEQ.fetch_add(1, Ordering::Relaxed)
    ));
    let result = (|| -> std::io::Result<()> {
        fs::write(&temp_path, content)?;
        #[cfg(windows)]
        {
            // Windows 不支持覆盖式 rename：先把旧文件挪走（而非删除），
            // 换名失败时挪回来，保证任何时刻配置文件都存在。
            let old_path = path.with_extension(format!(
                "{}.old-{}",
                path.extension().unwrap_or_default().to_string_lossy(),
                std::process::id()
            ));
            if path.exists() {
                fs::rename(path, &old_path)?;
            }
            match fs::rename(&temp_path, path) {
                Ok(()) => {
                    let _ = fs::remove_file(&old_path);
                    Ok(())
                }
                Err(error) => {
                    let _ = fs::rename(&old_path, path);
                    Err(error)
                }
            }
        }
        #[cfg(not(windows))]
        fs::rename(&temp_path, path)
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temp_path);
    }
    result
}

static CONFIG_TEMP_SEQ: AtomicU64 = AtomicU64::new(0);

#[cfg(test)]
mod tests {
    use super::{load, migrate_legacy_config};
    use lx_core::keybinding::Action;
    use lx_core::model::config::{CURRENT_CONFIG_VERSION, Config, StatusBarItem};
    use lx_core::model::source::SourceId;

    #[test]
    fn migrates_the_original_default_theme_to_mocha() {
        let mut config = Config {
            version: 0,
            ..Config::default()
        };
        config.theme.accent = "cyan".into();
        config.theme.text = "white".into();
        config.theme.muted = "dark_gray".into();
        config.theme.border = "cyan".into();

        migrate_legacy_config(&mut config);

        assert_eq!(config.theme.base, "#1e1e2e");
        assert_eq!(config.theme.accent, "#cba6f7");
    }

    #[test]
    fn expands_the_original_kw_only_source_default_once() {
        let mut config = Config {
            version: 0,
            ..Config::default()
        };
        config.source.enabled = vec![SourceId::Kw];

        assert!(migrate_legacy_config(&mut config));
        assert_eq!(config.version, CURRENT_CONFIG_VERSION);
        assert_eq!(config.source.enabled, SourceId::default_enabled());

        config.source.enabled = vec![SourceId::Kw];
        assert!(!migrate_legacy_config(&mut config));
        assert_eq!(config.source.enabled, vec![SourceId::Kw]);
    }

    #[test]
    fn preserves_a_custom_source_selection_during_version_two_migration() {
        let mut config = Config {
            version: 1,
            ..Config::default()
        };
        config.source.enabled = vec![SourceId::Kg, SourceId::Wy];

        assert!(migrate_legacy_config(&mut config));
        assert_eq!(config.version, CURRENT_CONFIG_VERSION);
        assert_eq!(config.source.enabled, vec![SourceId::Kg, SourceId::Wy]);
    }

    #[test]
    fn reenables_existing_local_music_paths_during_version_three_migration() {
        let mut config = Config {
            version: 2,
            ..Config::default()
        };
        config.local_music.paths = vec!["/music".to_string()];
        config.local_music.enabled = false;

        assert!(migrate_legacy_config(&mut config));
        assert_eq!(config.version, CURRENT_CONFIG_VERSION);
        assert!(config.local_music.enabled);
    }

    #[test]
    fn preserves_local_music_disable_after_version_three_migration() {
        let mut config = Config::default();
        config.local_music.paths = vec!["/music".to_string()];
        config.local_music.enabled = false;

        assert!(!migrate_legacy_config(&mut config));
        assert!(!config.local_music.enabled);
    }

    #[test]
    fn migrates_legacy_ui_notification_options() {
        let mut config = Config {
            version: 3,
            ..Config::default()
        };
        config.ui.show_notifications = Some(false);
        config.ui.notification_timeout = Some(9);

        assert!(migrate_legacy_config(&mut config));
        assert_eq!(config.version, CURRENT_CONFIG_VERSION);
        assert!(!config.notification.in_app);
        assert_eq!(config.notification.in_app_timeout, 9);
        assert_eq!(config.ui.show_notifications, None);
        assert_eq!(config.ui.notification_timeout, None);
    }

    #[test]
    fn migrates_history_limit_to_a_positive_value() {
        let mut config = Config {
            version: 4,
            ..Config::default()
        };
        config.player.history_limit = 0;

        assert!(migrate_legacy_config(&mut config));
        assert_eq!(config.version, CURRENT_CONFIG_VERSION);
        assert_eq!(config.player.history_limit, 1);
    }

    #[test]
    fn migrates_version_eight_settings_shortcuts_away_from_tab_numbers() {
        let mut config = Config {
            version: 8,
            ..Config::default()
        };
        let settings = config.keybindings.pages.get_mut("settings").unwrap();
        // 旧版逐行动作的裸数字绑定：动作本身已经删除，迁移只负责把它们清掉。
        settings.insert(Action::SettingsCyclePlaybackSpeed, "1".to_string());
        settings.insert(Action::SettingsCycleBalance, "6".to_string());
        // 仍然存在的导航键被裸数字占用：必须迁回默认（数字键留给侧边栏）。
        settings.insert(Action::ListSelectUp, "8".to_string());

        assert!(migrate_legacy_config(&mut config));
        assert_eq!(config.version, CURRENT_CONFIG_VERSION);
        let settings = config.keybindings.pages.get("settings").unwrap();
        for action in [
            Action::SettingsCyclePlaybackSpeed,
            Action::SettingsCycleBalance,
        ] {
            assert_eq!(
                settings.get(&action).map(String::as_str),
                None,
                "{action:?} 的行内快捷键已经删除，旧绑定必须被清理掉"
            );
        }
        assert_eq!(
            settings.get(&Action::ListSelectUp).map(String::as_str),
            Some("k"),
            "仍在使用的导航键要从裸数字迁回默认"
        );
    }

    #[test]
    fn migration_preserves_status_bar_order_and_removes_duplicates() {
        let mut config = Config::default();
        config.ui.status_bar_items = vec![
            StatusBarItem::Source,
            StatusBarItem::Song,
            StatusBarItem::Source,
        ];

        assert!(migrate_legacy_config(&mut config));
        assert_eq!(
            config.ui.status_bar_items,
            vec![StatusBarItem::Source, StatusBarItem::Song]
        );
    }

    #[test]
    fn loads_partial_config_with_defaults() {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "voicefox-partial-config-{}-{}.toml",
            std::process::id(),
            unique
        ));
        std::fs::write(&path, "[player]\nvolume = 42\n").unwrap();

        let (config, _) = load(path.to_str().unwrap()).unwrap();

        assert_eq!(config.player.volume, 42);
        assert_eq!(config.player.engine, "mpv");
        assert!(config.player.remember_playback_state);
        assert_eq!(config.player.history_limit, 100);
        assert_eq!(config.network.timeout, 15);
        assert_eq!(config.version, CURRENT_CONFIG_VERSION);
        assert_eq!(config.source.enabled, SourceId::default_enabled());
        let _ = std::fs::remove_file(path);
    }

    /// `ui.table_columns` 是用户可以手写的：只写半个列条目不能把整份配置
    /// 弄成解析失败，否则 `main` 里的 `?` 会让程序直接起不来。
    #[test]
    fn partial_table_column_entry_does_not_break_the_whole_config() {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "voicefox-partial-columns-{}-{}.toml",
            std::process::id(),
            unique
        ));
        std::fs::write(
            &path,
            "[ui.table_columns]\n[[ui.table_columns.queue]]\nkey = \"name\"\n",
        )
        .unwrap();

        let (config, _) = load(path.to_str().unwrap()).unwrap();

        let columns = config.ui.table_columns.get("queue").unwrap();
        assert_eq!(columns.len(), 1);
        assert_eq!(columns[0].key, "name");
        // 缺失字段走 TableColumnConfig::default()
        assert_eq!(columns[0].width, 8);
        assert!(columns[0].visible);
        let _ = std::fs::remove_file(path);
    }

    fn temp_config_path(tag: &str) -> std::path::PathBuf {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!(
            "voicefox-{tag}-{}-{unique}.toml",
            std::process::id()
        ))
    }

    /// 实测受害者：play_mode 是逐层转义的引号串，文件膨胀到 134MB。
    /// 加载必须把它重置回合法 token 并把文件恢复到 KB 级。
    #[test]
    fn corrupted_play_mode_is_reset_and_file_rewritten() {
        let path = temp_config_path("playmode-corrupt");
        // 两层转义模拟往返 bug 的存量形态。
        std::fs::write(
            &path,
            "[player]\nplay_mode = \"\\\"\\\\\\\"list-loop\\\\\\\"\\\"\"\nvolume = 7\n",
        )
        .unwrap();

        let (config, _) = load(path.to_str().unwrap()).unwrap();

        assert_eq!(config.player.play_mode, "list-loop");
        assert_eq!(config.player.volume, 7, "其余字段必须保留");
        let rewritten = std::fs::read_to_string(&path).unwrap();
        assert!(
            rewritten.len() < 64 * 1024,
            "重写后的配置应回到 KB 级（完整默认配置约 6KB），实际 {} 字节",
            rewritten.len()
        );
        let _ = std::fs::remove_file(path);
    }

    /// 解析失败（如旧 bug 写出的大写 quality 枚举名）不能让程序起不来：
    /// 损坏文件改名留档，回默认配置。
    #[test]
    fn unparsable_config_is_quarantined_and_replaced() {
        let path = temp_config_path("unparsable");
        std::fs::write(&path, "[download]\nquality = \"High320\"\n").unwrap();

        let (config, _) = load(path.to_str().unwrap()).unwrap();

        assert_eq!(config.version, CURRENT_CONFIG_VERSION);
        // 留档文件存在且内容原样。
        let dir = path.parent().unwrap();
        let backups: Vec<_> = std::fs::read_dir(dir)
            .unwrap()
            .filter_map(|entry| entry.ok())
            .filter(|entry| {
                entry
                    .file_name()
                    .to_string_lossy()
                    .starts_with(path.file_name().unwrap().to_string_lossy().as_ref())
                    && entry.file_name().to_string_lossy().contains(".corrupt-")
            })
            .collect();
        assert_eq!(backups.len(), 1, "损坏文件必须留档一份");
        let _ = std::fs::remove_file(path);
        let _ = std::fs::remove_file(backups[0].path());
    }

    /// 超过 4MB 的配置直接按损坏处理，不做无谓的读取与解析。
    #[test]
    fn oversized_config_is_quarantined_without_parsing() {
        let path = temp_config_path("oversized");
        // 注释填充：内容本身合法，仅体积超限。
        let filler = "#".repeat(5 * 1024 * 1024);
        std::fs::write(&path, filler).unwrap();

        let (config, _) = load(path.to_str().unwrap()).unwrap();

        assert_eq!(config.version, CURRENT_CONFIG_VERSION);
        assert!(std::fs::metadata(&path).unwrap().len() < 64 * 1024);
        // 只清理本测试自己的留档，避免并行测试误删别人的备份。
        let prefix = path.file_name().unwrap().to_string_lossy().to_string();
        let _ = std::fs::remove_file(&path);
        let dir = path.parent().unwrap();
        for entry in std::fs::read_dir(dir).unwrap().filter_map(|entry| entry.ok()) {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with(&prefix) && name.contains(".corrupt-") {
                let _ = std::fs::remove_file(entry.path());
            }
        }
    }
}
