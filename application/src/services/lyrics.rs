use std::sync::Arc;
use std::time::Duration;

use lx_core::model::lyric::LyricState;
use lx_core::model::song::SongInfo;
use lx_lyric::service::LyricService;

#[derive(Clone)]
pub struct LyricsService {
    inner: Arc<LyricService>,
}

impl LyricsService {
    pub fn new(inner: Arc<LyricService>) -> Self {
        Self { inner }
    }

    pub async fn load(&self, song: &SongInfo, generation: u64) -> Result<LyricState, String> {
        self.inner
            .load(song, generation)
            .await
            .map_err(|e| e.to_string())?;
        Ok(self.inner.current_state())
    }

    /// 开启新一次歌词加载前取过期令牌（P2-17：令牌必须来自本服务代次）。
    pub fn prepare(&self) -> u64 {
        self.inner.prepare()
    }

    pub fn update_position(&self, position: Duration) {
        self.inner.update_position(position);
    }

    pub fn state(&self) -> LyricState {
        self.inner.current_state()
    }

    pub fn set_translation_enabled(&self, enabled: bool) {
        self.inner.set_translation_enabled(enabled);
    }

    pub fn set_yrc_enabled(&self, enabled: bool) {
        self.inner.set_yrc_enabled(enabled);
    }

    pub fn set_offset_ms(&self, offset_ms: i32) {
        self.inner.set_offset_ms(offset_ms);
    }
}
