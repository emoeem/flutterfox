//! 仅测试使用的支撑代码：空播放器后端与空效果端口。

use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use async_trait::async_trait;
use tokio::sync::{mpsc, watch};

use lx_core::model::song::SongInfo;
use lx_core::model::source::{PlayerState, Quality};
use lx_core::traits::player::{PlayerBackend, PlayerEvent};

use super::PlaybackEffects;

/// 什么都不做的播放器：构造服务时占位，库命令测试不触发真实播放。
pub struct NullPlayer {
    generation: AtomicU64,
    state: watch::Sender<PlayerState>,
    position: watch::Sender<Duration>,
    duration: watch::Sender<Duration>,
    volume: std::sync::Mutex<u32>,
}

impl Default for NullPlayer {
    fn default() -> Self {
        Self::new()
    }
}

impl NullPlayer {
    pub fn new() -> Self {
        let (state, _) = watch::channel(PlayerState::Idle);
        let (position, _) = watch::channel(Duration::ZERO);
        let (duration, _) = watch::channel(Duration::ZERO);
        Self {
            generation: AtomicU64::new(0),
            state,
            position,
            duration,
            volume: std::sync::Mutex::new(100),
        }
    }
}

impl PlayerBackend for NullPlayer {
    fn prepare(&self) -> u64 {
        self.generation.fetch_add(1, Ordering::SeqCst) + 1
    }
    fn play(&self, _url: &str, _generation: u64) -> bool {
        false
    }
    fn pause(&self) {}
    fn resume(&self) {}
    fn stop(&self) {}
    fn toggle(&self) {}
    fn seek(&self, _position: Duration) {}
    fn state_watcher(&self) -> watch::Receiver<PlayerState> {
        self.state.subscribe()
    }
    fn position_watcher(&self) -> watch::Receiver<Duration> {
        self.position.subscribe()
    }
    fn duration_watcher(&self) -> watch::Receiver<Duration> {
        self.duration.subscribe()
    }
    fn take_event_receiver(&self) -> Option<mpsc::UnboundedReceiver<PlayerEvent>> {
        None
    }
    fn volume(&self) -> u32 {
        *self.volume.lock().unwrap_or_else(|e| e.into_inner())
    }
    fn set_volume(&self, vol: u32) {
        *self.volume.lock().unwrap_or_else(|e| e.into_inner()) = vol;
    }
    fn volume_up(&self, _delta: u32) {}
    fn volume_down(&self, _delta: u32) {}
}

/// 什么都不做的效果端口。
pub struct NullEffects;

#[async_trait]
impl PlaybackEffects for NullEffects {
    fn existing_download(&self, _song: &SongInfo) -> Option<PathBuf> {
        None
    }
    fn record_history(&self, _song: &SongInfo) {}
    fn prepare_cover(&self, _song: &SongInfo, _show_cover: bool) -> Option<String> {
        None
    }
    async fn load_cover(&self, _url: Option<String>) -> Result<(), String> {
        Ok(())
    }
    async fn cache_cover(&self, _url: Option<String>) -> Option<String> {
        None
    }
    fn cover_url_is_usable(&self, _url: &str) -> bool {
        false
    }
    fn album_cover_notification(&self) -> bool {
        false
    }
    fn track_change_notification(&self) -> bool {
        false
    }
    fn fade_in_ms(&self) -> u64 {
        0
    }
    fn quality(&self) -> Quality {
        Quality::Low128
    }
    fn auto_toggle(&self) -> bool {
        false
    }
}

/// 便捷构造：带空播放器的 Arc。
pub fn null_player() -> Arc<dyn PlayerBackend> {
    Arc::new(NullPlayer::new())
}
