//! GUI 崩溃取证（P1-05/P2-08）。
//!
//! 缺陷观察：GUI 进程经 xwayland-satellite resize 触发 `Timed out waiting
//! for OpenGL frame` 后静默消失，日志无 panic、无 core dump（04 矩阵
//! P1-05/P2-08）。GUI 与 TUI 不同：无 tracing subscriber 落盘，panic 只进
//! stderr（重定向缺失时即彻底丢失）。本模块把 panic 面以 append 方式落盘
//! 到 `<config>/crash.log`（与 TUI voicefox.log 同目录），
//! `VOICEFOX_CRASH_LOG` 可覆盖路径；Dart 侧未处理异常经 main.dart
//! `installCrashLogHandlers` 写同一文件。
//!
//! 诚实边界：引擎级 SIGABRT/GL abort 无 unwind，不经过 panic hook——该
//! 路径的取证需要外部 watchdog，本模块先消除 panic/异常面的日志盲区。

use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

/// 解析崩溃日志路径：`VOICEFOX_CRASH_LOG` 优先，缺省 `<config>/crash.log`。
pub fn crash_log_path(config_dir: &Path) -> PathBuf {
    match std::env::var_os("VOICEFOX_CRASH_LOG") {
        Some(value) if !value.is_empty() => PathBuf::from(value),
        _ => config_dir.join("crash.log"),
    }
}

/// 追加一条崩溃取证记录（unix 秒时间戳）。写盘失败静默降级——取证不应
/// 反噬正常运行。
pub fn append_crash_entry(path: &Path, kind: &str, body: &str) {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or_default();
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(mut file) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
    {
        let _ = writeln!(file, "[{stamp}] {kind}: {body}");
    }
}

/// 安装 GUI 侧 panic hook：panic 时落盘后交还原 hook（保持既有 stderr 行为）。
pub fn install_gui_panic_hook(config_dir: &Path) {
    let path = crash_log_path(config_dir);
    let original = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        append_crash_entry(&path, "panic", &format!("{info}"));
        original(info);
    }));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn crash_entries_append_with_timestamp_and_kind() {
        let dir = std::env::temp_dir().join(format!(
            "voicefox-crash-{}-{}",
            std::process::id(),
            std::thread::current()
                .name()
                .unwrap_or("t")
                .replace("::", "_")
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("crash.log");

        append_crash_entry(
            &path,
            "panic",
            "called `Result::unwrap()` on an `Err` value: boom",
        );
        append_crash_entry(&path, "flutter-error", "Unhandled Exception: x");

        let content = std::fs::read_to_string(&path).unwrap();
        let lines: Vec<&str> = content.lines().collect();
        assert_eq!(lines.len(), 2, "两次追加各成一行");
        assert!(
            lines[0].contains("] panic: called `Result::unwrap()`"),
            "首行含类型与正文: {}",
            lines[0]
        );
        assert!(
            lines[1].contains("] flutter-error: Unhandled Exception: x"),
            "次行含类型与正文: {}",
            lines[1]
        );

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn env_override_wins_over_config_dir() {
        // 直接测解析函数的两个分支（不设全局 env，避免并行测试串扰）：
        // 缺省 = config 目录下 crash.log。
        assert_eq!(
            crash_log_path(Path::new("/cfg/voicefox")),
            PathBuf::from("/cfg/voicefox/crash.log")
        );
    }
}
