package com.example.voicefox_flutter

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.android.FlutterActivity

// audio_service 前台媒体服务要求宿主 Activity 继承 AudioServiceActivity
// （MediaBrowser 连接与媒体按钮派发，Phase 8 批次三）。
class MainActivity : AudioServiceActivity()
