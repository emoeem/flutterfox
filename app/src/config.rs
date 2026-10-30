//! 兼容垫片：配置加载/保存实现已统一到 voicefox-runtime::config_loader。
//! 保留 crate::config::loader::* 路径，TUI 无需改动引用方式。
pub use voicefox_runtime::config_loader as loader;
