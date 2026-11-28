use std::sync::{
    Arc, RwLock,
    atomic::{AtomicUsize, Ordering},
};

use lx_core::model::song::SongInfo;

#[derive(Clone)]
pub struct QueueService {
    songs: Arc<RwLock<Vec<SongInfo>>>,
    index: Arc<AtomicUsize>,
}

impl Default for QueueService {
    fn default() -> Self {
        Self::new()
    }
}

impl QueueService {
    pub fn new() -> Self {
        Self {
            songs: Arc::new(RwLock::new(Vec::new())),
            index: Arc::new(AtomicUsize::new(0)),
        }
    }

    pub fn snapshot(&self) -> (Vec<SongInfo>, usize) {
        let songs = self.songs.read().unwrap_or_else(|e| e.into_inner()).clone();
        let len = songs.len();
        let index = self.index.load(Ordering::Acquire);
        (songs, index.min(len.saturating_sub(1)))
    }

    pub fn replace(&self, songs: Vec<SongInfo>, index: usize) {
        let safe = index.min(songs.len().saturating_sub(1));
        *self.songs.write().unwrap_or_else(|e| e.into_inner()) = songs;
        self.index.store(safe, Ordering::Release);
    }

    pub fn add(&self, song: SongInfo, next: bool) -> usize {
        let mut songs = self.songs.write().unwrap_or_else(|e| e.into_inner());
        if songs.is_empty() {
            songs.push(song);
            self.index.store(0, Ordering::Release);
            return 0;
        }
        let current = self.index.load(Ordering::Acquire);
        let pos = if next {
            current.saturating_add(1).min(songs.len())
        } else {
            songs.len()
        };
        songs.insert(pos, song);
        pos
    }

    pub fn remove(&self, index: usize) -> Option<SongInfo> {
        let mut songs = self.songs.write().unwrap_or_else(|e| e.into_inner());
        if index >= songs.len() {
            return None;
        }
        let removed = songs.remove(index);
        let current = self.index.load(Ordering::Acquire);
        let next = if songs.is_empty() {
            0
        } else if index < current {
            current - 1
        } else {
            current.min(songs.len() - 1)
        };
        self.index.store(next, Ordering::Release);
        Some(removed)
    }

    /// 队内移动（Batch F §9.1 P2-09 收口）：拖拽排序的真实后端语义。
    ///
    /// 当前播放条目身份保持：移动跨越当前索引时同步修正索引，避免
    /// 「拖完之后正在播的歌错位」。越界/原地移动返回 false（幂等）。
    pub fn move_item(&self, from: usize, to: usize) -> bool {
        let mut songs = self.songs.write().unwrap_or_else(|e| e.into_inner());
        if from >= songs.len() || to >= songs.len() || from == to {
            return false;
        }
        let item = songs.remove(from);
        songs.insert(to, item);
        let current = self.index.load(Ordering::Acquire);
        let next = if current == from {
            to
        } else if from < current && to >= current {
            current - 1
        } else if from > current && to <= current {
            current + 1
        } else {
            current
        }
        .min(songs.len() - 1);
        self.index.store(next, Ordering::Release);
        true
    }

    pub fn clear(&self) {
        self.replace(Vec::new(), 0);
    }

    pub fn set_index(&self, index: usize) {
        let len = self.songs.read().unwrap_or_else(|e| e.into_inner()).len();
        self.index
            .store(index.min(len.saturating_sub(1)), Ordering::Release);
    }
}

#[cfg(test)]
mod tests {
    use super::QueueService;
    use lx_core::model::song::SongInfo;
    use lx_core::model::source::SourceId;

    fn song(id: &str) -> SongInfo {
        SongInfo::new(id.into(), SourceId::Kw, id.into(), "artist".into())
    }

    #[test]
    fn add_next_and_end_keep_current_index_stable() {
        let queue = QueueService::new();
        queue.add(song("a"), false);
        queue.add(song("b"), true);
        queue.add(song("c"), false);
        let (songs, index) = queue.snapshot();
        assert_eq!(
            songs.iter().map(|s| s.id.as_str()).collect::<Vec<_>>(),
            vec!["a", "b", "c"]
        );
        assert_eq!(index, 0);
    }

    #[test]
    fn remove_before_current_adjusts_index() {
        let queue = QueueService::new();
        queue.replace(vec![song("a"), song("b"), song("c")], 2);
        queue.remove(0);
        let (songs, index) = queue.snapshot();
        assert_eq!(songs.len(), 2);
        assert_eq!(songs[index].id, "c");
        assert_eq!(index, 1);
    }

    // ── Batch F §9.1 P2-09：队内移动（拖拽排序真实后端语义）──

    #[test]
    fn move_item_reorders_and_keeps_playing_identity() {
        let queue = QueueService::new();
        queue.replace(vec![song("a"), song("b"), song("c")], 1);
        // 把正在播的 b 从 1 拖到 0：索引跟随条目身份。
        assert!(queue.move_item(1, 0));
        let (songs, index) = queue.snapshot();
        assert_eq!(
            songs.iter().map(|s| s.id.as_str()).collect::<Vec<_>>(),
            vec!["b", "a", "c"]
        );
        assert_eq!(index, 0, "当前播放条目身份保持");
        assert_eq!(songs[index].id, "b");
    }

    #[test]
    fn move_item_crossing_current_adjusts_index() {
        let queue = QueueService::new();
        queue.replace(vec![song("a"), song("b"), song("c"), song("d")], 0);
        // 把 a(0, 正在播) 拖到最后：其余条目前移，索引跟随到末位。
        assert!(queue.move_item(0, 3));
        let (songs, index) = queue.snapshot();
        assert_eq!(
            songs.iter().map(|s| s.id.as_str()).collect::<Vec<_>>(),
            vec!["b", "c", "d", "a"]
        );
        assert_eq!(index, 3);
        assert_eq!(songs[index].id, "a");
    }

    #[test]
    fn move_item_after_current_shifts_index_back() {
        let queue = QueueService::new();
        queue.replace(vec![song("a"), song("b"), song("c"), song("d")], 1);
        // 移动的条目在当前播放之后且目标在当前之前 → 当前索引 +1。
        assert!(queue.move_item(3, 0));
        let (_, index) = queue.snapshot();
        assert_eq!(index, 2);
    }

    #[test]
    fn move_item_out_of_range_or_same_position_is_idempotent() {
        let queue = QueueService::new();
        queue.replace(vec![song("a"), song("b")], 0);
        assert!(!queue.move_item(2, 0), "越界 from");
        assert!(!queue.move_item(0, 2), "越界 to");
        assert!(!queue.move_item(1, 1), "原地移动幂等");
        let (songs, index) = queue.snapshot();
        assert_eq!(index, 0);
        assert_eq!(songs[0].id, "a");
    }
}
