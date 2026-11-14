//! 移动端转发型播放后端（Phase 8 批次一）。
//!
//! 形态参考 [`super::test_support::NullPlayer`]：实现 [`PlayerBackend`]
//! 全部方法，但自身不做任何音频解码——播放控制指令经 broadcast 通道转发给
//! 宿主（Flutter / just_audio，Phase 8 批次三承接），宿主回流的真实
//! state/position/duration 经 `report_*` 写回 watch 通道，喂给
//! `service.rs` 的观察者泵（175-211 行：watch → ApplicationEventStream →
//! Flutter 既有事件流）。
//!
//! 接缝（本类型不改动 playback.rs，桌面路径零变化）：
//! - `PlaybackService::play` 先 `prepare()` 取代次令牌
//!   （services/playback.rs:95），再 `play_with_headers(url, generation,
//!   headers)`（:123）；本类型覆写 `play_with_headers` 原样转发
//!   url+generation+headers——国内音源播放依赖自定义请求头，默认实现会
//!   丢弃 headers（core/src/traits/player.rs:124）。
//! - 代次有效性由宿主侧判断（转发事件携带 generation，宿主只执行当前
//!   代次）；mpv 后端的进程内判代在此不可用。
//!
//! 线程模型：转发通道为 `tokio::sync::broadcast`（多订阅者安全，FRB 流
//! 每次订阅拿新 receiver）；回流为 `watch`（取最新值，高频不丢帧），与
//! mpv 后端同构。

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use tokio::sync::{broadcast, mpsc, watch};

use lx_core::model::source::PlayerState;
use lx_core::traits::player::{PlayerBackend, PlayerEvent};

/// 自定义请求头键值对（FRB 可翻译 DTO；国内音源逐请求透传）。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HostHeaderPair {
    pub name: String,
    pub value: String,
}

/// 转发给宿主（Dart 侧 just_audio）的播放指令。
#[derive(Debug, Clone, PartialEq)]
pub enum HostPlayerCommand {
    /// 播放指定 URL；`headers` 为音源解析出的自定义请求头。
    Play {
        url: String,
        generation: u64,
        headers: Vec<HostHeaderPair>,
    },
    Pause,
    Resume,
    Stop,
    Toggle,
    /// 定位到绝对位置（毫秒）。
    Seek {
        position_ms: u64,
    },
    SetVolume {
        volume: u32,
    },
    SetSpeed {
        speed: f64,
    },
}

/// 转发型播放后端。
pub struct HostPlayerBackend {
    generation: AtomicU64,
    commands: broadcast::Sender<HostPlayerCommand>,
    state: watch::Sender<PlayerState>,
    position: watch::Sender<Duration>,
    duration: watch::Sender<Duration>,
    /// 离散事件出口（Ended/Error/Buffering），service.rs 的队列推进消费。
    events: mpsc::UnboundedSender<PlayerEvent>,
    /// 单次交付的接收端（与 mpv 后端 engine.rs:856 同模式：take 后为 None）。
    event_rx: Mutex<Option<mpsc::UnboundedReceiver<PlayerEvent>>>,
    volume: Mutex<u32>,
    speed: Mutex<f64>,
    audio_device: Mutex<String>,
    /// 最近一条未确认送达的 Play（FFI-R01：宿主订阅前 play 的指令会被
    /// broadcast 丢弃；此处挂起，首个订阅者接入时补投，播放意图不再
    /// 静默丢失。stop 清除，新 Play 覆写，补投成功后清空）。
    pending_play: Mutex<Option<HostPlayerCommand>>,
    /// 最近一次宿主回流时刻（FFI-R07：看门狗判「消费者在线但持续无回流」
    /// 的冻结依据；None = 从未回流）。
    last_report: Mutex<Option<std::time::Instant>>,
}

impl Default for HostPlayerBackend {
    fn default() -> Self {
        Self::new()
    }
}

impl HostPlayerBackend {
    pub fn new() -> Self {
        let (commands, _) = broadcast::channel(64);
        let (state, _) = watch::channel(PlayerState::Idle);
        let (position, _) = watch::channel(Duration::ZERO);
        let (duration, _) = watch::channel(Duration::ZERO);
        let (events, event_rx) = mpsc::unbounded_channel();
        Self {
            generation: AtomicU64::new(0),
            commands,
            state,
            position,
            duration,
            events,
            event_rx: Mutex::new(Some(event_rx)),
            volume: Mutex::new(100),
            speed: Mutex::new(1.0),
            audio_device: Mutex::new("auto".to_owned()),
            pending_play: Mutex::new(None),
            last_report: Mutex::new(None),
        }
    }

    /// 订阅转发指令流（Rust→Dart 反向信号面）。
    ///
    /// FFI-R01：若这是当前唯一消费者且存在挂起的 Play（宿主上线前下发），
    /// 立即补投——广播通道无法追溯订阅前丢掉的指令，补投保证播放意图
    /// 最终送达。补投成功后清空挂起槽，二次订阅不重复投递。
    pub fn subscribe(&self) -> broadcast::Receiver<HostPlayerCommand> {
        let receiver = self.commands.subscribe();
        if self.commands.receiver_count() == 1 {
            let pending = self
                .pending_play
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .clone();
            if let Some(command) = pending {
                if self.commands.send(command).is_ok() {
                    *self.pending_play.lock().unwrap_or_else(|e| e.into_inner()) = None;
                }
            }
        }
        receiver
    }

    /// 宿主回流真实播放状态（Dart→Rust）。
    ///
    /// 用 `send_replace` 而非 `send`：后者在无接收者时返回 SendError 并
    /// 丢弃值（宿主订阅前 report 会丢），`send_replace` 无条件更新共享槽，
    /// 之后订阅的观察者立即读到最新值。
    pub fn report_state(&self, state: PlayerState) {
        self.touch_report();
        self.state.send_replace(state);
    }

    /// 宿主回流真实媒体进度。
    pub fn report_position(&self, position: Duration) {
        self.touch_report();
        self.position.send_replace(position);
    }

    /// 宿主回流真实总时长（时长未知报 0，UI 层按 `--:--` 规则呈现）。
    pub fn report_duration(&self, duration: Duration) {
        self.touch_report();
        self.duration.send_replace(duration);
    }

    /// 宿主回流离散事件（Ended/Error/Buffering），service.rs 的队列推进消费。
    pub fn report_event(&self, event: PlayerEvent) {
        self.touch_report();
        let _ = self.events.send(event);
    }

    /// 刷新「宿主最近回流」时间戳（FFI-R07 看门狗的冻结判据）。
    fn touch_report(&self) {
        *self.last_report.lock().unwrap_or_else(|e| e.into_inner()) =
            Some(std::time::Instant::now());
    }

    /// 存活检查单步（FFI-R07）。返回是否发生了强制回落。
    ///
    /// 判据（仅 Loading/Playing 态需要看护）：
    /// - 宿主消失：无消费者且无挂起 Play → 强制回落 Stopped（有挂起 Play
    ///   时不回落：播放意图仍待补投送达，回落会造成「可恢复却误报停止」）；
    /// - 宿主冻结：消费者在线但超过 `max_silence` 无任何回流 → 强制回落
    ///   Stopped（回流断流意味着 just_audio 侧已失联，保留 Playing 是假象）。
    ///
    /// 强制回落经 watch `send_replace` 生效，service.rs 观察者泵会把它
    /// 广播成正常状态迁移，UI 与队列推进路径零特殊处理。
    pub fn liveness_tick(&self, max_silence: Duration) -> bool {
        if !matches!(
            *self.state.borrow(),
            PlayerState::Loading | PlayerState::Playing
        ) {
            return false;
        }
        let host_gone = self.commands.receiver_count() == 0
            && self
                .pending_play
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .is_none();
        let reported_recently = self
            .last_report
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .map_or(false, |t| t.elapsed() <= max_silence);
        if host_gone || (self.commands.receiver_count() > 0 && !reported_recently) {
            self.state.send_replace(PlayerState::Stopped);
            return true;
        }
        false
    }

    /// 启动常驻存活看门狗（FFI-R07）。
    ///
    /// `std` 线程而非 tokio 任务：new_host 引导路径无 tokio 上下文（FFI 同步
    /// 入口），且看门狗只需 sleep+check，不需要异步 IO。线程持 `Arc<Self>`，
    /// 生命周期与后端一致（进程级，与 R12 登记的「无优雅关停」现状一致）。
    /// `interval`/`max_silence` 可注入，测试用小值驱动。
    pub fn start_liveness_watchdog(self: &Arc<Self>, interval: Duration, max_silence: Duration) {
        let backend = Arc::clone(self);
        let spawned = std::thread::Builder::new()
            .name("voicefox-host-watchdog".to_owned())
            .spawn(move || {
                loop {
                    std::thread::sleep(interval);
                    backend.liveness_tick(max_silence);
                }
            });
        if let Err(error) = spawned {
            eprintln!(
                "voicefox: 存活看门狗线程启动失败（{error}）；宿主断连将无法自动回落 Stopped"
            );
        }
    }
}

impl PlayerBackend for HostPlayerBackend {
    fn prepare(&self) -> u64 {
        self.generation.fetch_add(1, Ordering::SeqCst) + 1
    }

    fn play(&self, url: &str, generation: u64) -> bool {
        self.play_with_headers(url, generation, &[])
    }

    fn play_with_headers(&self, url: &str, generation: u64, headers: &[(String, String)]) -> bool {
        // 无订阅者（宿主尚未上线）时指令会被 broadcast 丢弃但不阻塞服务层；
        // 同时挂起整条指令，首个订阅者接入时由 subscribe() 补投（FFI-R01），
        // 播放意图不再静默丢失。宿主上线后以 generation 判代执行。
        let command = HostPlayerCommand::Play {
            url: url.to_owned(),
            generation,
            headers: headers
                .iter()
                .map(|(name, value)| HostHeaderPair {
                    name: name.clone(),
                    value: value.clone(),
                })
                .collect(),
        };
        *self.pending_play.lock().unwrap_or_else(|e| e.into_inner()) = Some(command.clone());
        let _ = self.commands.send(command);
        self.state.send_replace(PlayerState::Loading);
        true
    }

    fn pause(&self) {
        let _ = self.commands.send(HostPlayerCommand::Pause);
    }

    fn resume(&self) {
        let _ = self.commands.send(HostPlayerCommand::Resume);
    }

    fn stop(&self) {
        // stop 表达「放弃播放意图」：清除挂起 Play，避免 subscribe() 补投
        // 一条用户已取消的播放（FFI-R01 配套）。
        *self.pending_play.lock().unwrap_or_else(|e| e.into_inner()) = None;
        let _ = self.commands.send(HostPlayerCommand::Stop);
        self.state.send_replace(PlayerState::Stopped);
        self.position.send_replace(Duration::ZERO);
    }

    fn toggle(&self) {
        let _ = self.commands.send(HostPlayerCommand::Toggle);
    }

    fn seek(&self, position: Duration) {
        let _ = self.commands.send(HostPlayerCommand::Seek {
            position_ms: position.as_millis() as u64,
        });
        // 回流跟随宿主报告；本地乐观写避免 UI 等待往返抖动。
        self.position.send_replace(position);
    }

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
        // 单次交付：service.rs 引导时拿走；重复 take 返回 None（与 mpv
        // 后端 engine.rs:856 同模式）。
        self.event_rx
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .take()
    }

    fn volume(&self) -> u32 {
        *self.volume.lock().unwrap_or_else(|e| e.into_inner())
    }

    fn set_volume(&self, vol: u32) {
        let clamped = vol.clamp(0, 100);
        *self.volume.lock().unwrap_or_else(|e| e.into_inner()) = clamped;
        let _ = self
            .commands
            .send(HostPlayerCommand::SetVolume { volume: clamped });
    }

    fn volume_up(&self, delta: u32) {
        let current = self.volume();
        self.set_volume(current.saturating_add(delta).min(100));
    }

    fn volume_down(&self, delta: u32) {
        let current = self.volume();
        self.set_volume(current.saturating_sub(delta));
    }

    fn playback_speed(&self) -> f64 {
        *self.speed.lock().unwrap_or_else(|e| e.into_inner())
    }

    fn set_playback_speed(&self, speed: f64) {
        *self.speed.lock().unwrap_or_else(|e| e.into_inner()) = speed;
        let _ = self.commands.send(HostPlayerCommand::SetSpeed { speed });
    }

    fn audio_output_device(&self) -> String {
        self.audio_device
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone()
    }

    fn set_audio_output_device(&self, device: &str) {
        // 设备枚举/路由由宿主桥接（AudioManager.getDevices，批次五）；
        // 此处只记录当前选择，不转发。
        *self.audio_device.lock().unwrap_or_else(|e| e.into_inner()) = device.to_owned();
    }

    fn fade_in(&self, _duration: Duration) {
        // 淡入为 mpv 音频曲线特性；宿主侧如需等价能力由批次三自行实现。
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// prepare 代次单调递增，play_with_headers 原样转发 url+generation+headers。
    #[test]
    fn forwards_play_with_headers_and_generation() {
        let backend = HostPlayerBackend::new();
        let mut rx = backend.subscribe();

        let g1 = backend.prepare();
        let g2 = backend.prepare();
        assert_eq!(g1, 1);
        assert_eq!(g2, 2);

        let accepted = backend.play_with_headers(
            "https://example.com/a.mp3",
            g2,
            &[("Referer".to_owned(), "https://example.com".to_owned())],
        );
        assert!(accepted);

        let command = rx.try_recv().unwrap();
        assert_eq!(
            command,
            HostPlayerCommand::Play {
                url: "https://example.com/a.mp3".to_owned(),
                generation: 2,
                headers: vec![HostHeaderPair {
                    name: "Referer".to_owned(),
                    value: "https://example.com".to_owned(),
                }],
            }
        );
    }

    /// 控制指令转发 + 回流写入 watch（喂 service.rs 观察者泵）。
    #[test]
    fn controls_forward_and_reports_backfill_watchers() {
        let backend = HostPlayerBackend::new();
        let mut rx = backend.subscribe();

        backend.pause();
        backend.resume();
        backend.seek(Duration::from_millis(42_000));
        backend.set_volume(37);
        backend.set_playback_speed(1.25);

        assert_eq!(rx.try_recv().unwrap(), HostPlayerCommand::Pause);
        assert_eq!(rx.try_recv().unwrap(), HostPlayerCommand::Resume);
        assert_eq!(
            rx.try_recv().unwrap(),
            HostPlayerCommand::Seek {
                position_ms: 42_000
            }
        );
        assert_eq!(
            rx.try_recv().unwrap(),
            HostPlayerCommand::SetVolume { volume: 37 }
        );
        assert_eq!(
            rx.try_recv().unwrap(),
            HostPlayerCommand::SetSpeed { speed: 1.25 }
        );
        assert_eq!(backend.volume(), 37);
        assert_eq!(backend.playback_speed(), 1.25);

        // 回流：宿主上报真实值，观察者立即可读。
        backend.report_state(PlayerState::Playing);
        backend.report_position(Duration::from_millis(5_000));
        backend.report_duration(Duration::from_millis(244_000));
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Playing);
        assert_eq!(backend.position_watcher().borrow().as_millis(), 5_000_u128);
        assert_eq!(
            backend.duration_watcher().borrow().as_millis(),
            244_000_u128
        );
    }

    /// play 后状态进 Loading；stop 归 Stopped 且进度清零（不伪造进度）。
    #[test]
    fn play_sets_loading_and_stop_resets_position() {
        let backend = HostPlayerBackend::new();
        let mut rx = backend.subscribe();

        backend.play("https://example.com/b.mp3", backend.prepare());
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Loading);
        let _ = rx.try_recv().unwrap();

        backend.report_position(Duration::from_millis(9_000));
        backend.stop();
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Stopped);
        assert!(backend.position_watcher().borrow().is_zero());
        assert!(matches!(rx.try_recv().unwrap(), HostPlayerCommand::Stop));
    }

    /// FFI-R01：无订阅者时 play 不阻塞也不报错，且指令挂起；首个订阅者
    /// 接入即补投，播放意图不再静默丢失（旧语义「丢弃但接受」废弃）。
    #[test]
    fn pending_play_replayed_on_first_subscribe() {
        let backend = HostPlayerBackend::new();
        let generation = backend.prepare();
        assert!(backend.play("https://example.com/c.mp3", generation));
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Loading);

        // 订阅前无消费者：broadcast 丢弃指令，但挂起槽已保留。
        let mut rx = backend.subscribe();
        let command = rx.try_recv().unwrap();
        assert!(
            matches!(
                &command,
                HostPlayerCommand::Play { url, generation: g, .. }
                if url == "https://example.com/c.mp3" && *g == generation
            ),
            "首个订阅者应收到补投的挂起 Play，实际 {command:?}"
        );
        // 补投成功后挂起槽清空：二次订阅不重复投递。
        let mut rx2 = backend.subscribe();
        assert!(
            rx2.try_recv().is_err(),
            "补投后的挂起槽应已清空，二次订阅不得重复收到 Play"
        );
        let _ = rx2;
    }

    /// FFI-R01 配套：stop 表达放弃播放意图，挂起 Play 必须清除，
    /// 不得在订阅时补投一条用户已取消的播放。
    #[test]
    fn stop_clears_pending_play() {
        let backend = HostPlayerBackend::new();
        backend.play("https://example.com/d.mp3", backend.prepare());
        backend.stop();

        let mut rx = backend.subscribe();
        assert!(
            rx.try_recv().is_err(),
            "挂起 Play 已被 stop 清除，订阅时不应补投"
        );
    }

    /// FFI-R07：存活检查仅在「宿主消失（曾在线后全部掉线）/宿主冻结」时
    /// 强制回落 Stopped；有挂起 Play（补投语义）或回流新鲜时不干预。
    #[test]
    fn liveness_tick_forces_stopped_only_when_host_gone() {
        let backend = HostPlayerBackend::new();

        // 场景 1：宿主曾在线（补投已清挂起槽）后全部掉线 → 强制 Stopped。
        backend.play("https://example.com/e.mp3", backend.prepare());
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Loading);
        {
            let mut rx = backend.subscribe();
            let _ = rx.try_recv(); // 消费补投，挂起槽清空
        } // rx 掉线：receiver_count 归 0，播放中宿主消失
        assert!(
            backend.liveness_tick(Duration::from_secs(20)),
            "无消费者且无挂起意图的 Loading 态应回落"
        );
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Stopped);

        // 场景 2：有挂起 Play（宿主从未上线，补投语义在途）→ 不回落。
        backend.play("https://example.com/f.mp3", backend.prepare());
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Loading);
        assert!(!backend.liveness_tick(Duration::from_secs(20)));
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Loading);

        // 场景 3：消费者在线且回流新鲜 → 不回落。
        let mut rx = backend.subscribe();
        let _ = rx.try_recv(); // 消费 subscribe() 补投的挂起 Play
        backend.report_state(PlayerState::Playing);
        assert!(!backend.liveness_tick(Duration::from_secs(20)));
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Playing);

        // 场景 4：消费者在线但远超静默阈值无回流 → 判冻结回落。
        assert!(
            backend.liveness_tick(Duration::ZERO),
            "回流断流的 Playing 态应回落（保留 Playing 是假象）"
        );
        assert_eq!(*backend.state_watcher().borrow(), PlayerState::Stopped);
    }

    /// 宿主回流 Ended/Error 事件经事件出口交付（单次 take 后由消费方持有）。
    #[test]
    fn report_event_reaches_consumer() {
        let backend = HostPlayerBackend::new();
        let mut rx = backend
            .take_event_receiver()
            .expect("首次 take 必须拿到接收端");
        assert!(
            backend.take_event_receiver().is_none(),
            "二次 take 返回 None"
        );

        backend.report_event(PlayerEvent::Ended { generation: 3 });
        backend.report_event(PlayerEvent::Error {
            generation: 3,
            message: "解码失败".to_owned(),
        });
        assert!(matches!(
            rx.try_recv().unwrap(),
            PlayerEvent::Ended { generation: 3 }
        ));
        assert!(matches!(
            rx.try_recv().unwrap(),
            PlayerEvent::Error { generation: 3, .. }
        ));
    }
}
