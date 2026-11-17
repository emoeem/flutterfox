#include "flutter_window.h"

#include <optional>
#include <thread>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
    // P0-W1:首帧回调即 Show,随后挂检测式自愈(见 ScheduleWhiteScreenHeal)。
    this->ScheduleWhiteScreenHeal();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

// ── P0-W1 检测式自愈 ─────────────────────────────────────────────────────
//
// 现象(2026-11-18 会话实证,846bbfe 同现,概率性):冷启动在首帧回调
// Show() 之后,DWM 不合成客户区内容 → 窗口白屏,直到任意一次真实
// WM_SIZE(实测 Win+Left 贴靠/程序性 SetWindowPos ±1px)立即恢复。同族
// 于已登记的 P2-08「GL frame timeout」;QXL/ANGLE 虚拟显卡环境态敏感
// (同一构建前一日正常、当日 4 连现、数小时后自愈,根因在引擎/合成层,
// 应用层无法修复呈现本身)。
//
// 自愈策略:首帧回调 + 2s 后,从屏幕 DC 采样客户区的**合成真值**
// (GetDC(nullptr) 读的是 DWM 合成到屏幕上的像素,不是交换链内容——
// 2026-11-18 取证实证 PrintWindow(PW_RENDERFULLCONTENT) 在白屏形态下
// 仍能取到交换链内的帧,不能用作检测源)。若样本近全白(应用默认深色
// 主题下不可能是稳态),以 SetWindowPos ±1px 往返触发真实 WM_SIZE 强制
// 交换链/合成重建,最多两轮。误触发代价 = 一次 1px 尺寸往返(视觉无感),
// 覆盖场景代价分析:浅色主题用户、检测窗口被其他白色窗口遮挡 → 同为
// 无害误触发;不做检测的代价 = 冷启动白屏(阻断级)。裁决:检测式自愈。
void FlutterWindow::ScheduleWhiteScreenHeal() {
  std::thread([hwnd = GetHandle()]() {
    // 首帧已呈现,给 DWM/合成器一个正常合成窗口;白屏形态下这个等待
    // 之后屏幕上仍是白。
    Sleep(2000);
    auto looksWhiteOnScreen = [hwnd]() -> bool {
      if (!IsWindow(hwnd)) {
        return false;
      }
      RECT rc{};
      if (!GetClientRect(hwnd, &rc)) {
        return false;
      }
      const LONG width = rc.right - rc.left;
      const LONG height = rc.bottom - rc.top;
      if (width < 200 || height < 200) {
        return false;
      }
      POINT top_left{rc.left, rc.top};
      if (!ClientToScreen(hwnd, &top_left)) {
        return false;
      }
      const HDC screen = ::GetDC(nullptr);
      if (screen == nullptr) {
        return false;
      }
      int white = 0;
      int total = 0;
      for (const double fx : {0.03, 0.33, 0.5, 0.67, 0.95}) {
        for (const double fy : {0.05, 0.5, 0.93}) {
          const COLORREF c =
              ::GetPixel(screen, top_left.x + static_cast<LONG>(width * fx),
                         top_left.y + static_cast<LONG>(height * fy));
          total++;
          if (GetRValue(c) >= 240 && GetGValue(c) >= 240 &&
              GetBValue(c) >= 240) {
            white++;
          }
        }
      }
      ::ReleaseDC(nullptr, screen);
      // 深色主题稳态下 0/15 白;白屏形态 15/15。允许 1 个采样误差
      // (光标/通知等叠压),≥2 个非白像素即认定已渲染。
      return white >= total - 1;
    };
    for (int attempt = 1; attempt <= 2; attempt++) {
      if (!looksWhiteOnScreen()) {
        return;  // 已正常呈现(或窗口已销毁):不做任何多余动作。
      }
      std::fwprintf(stderr, L"voicefox: P0-W1 white client area detected on "
                            L"screen, forcing WM_SIZE (attempt %d)\n",
                    attempt);
      RECT r{};
      if (!GetWindowRect(hwnd, &r)) {
        return;
      }
      const LONG w = r.right - r.left;
      const LONG h = r.bottom - r.top;
      if (w <= 0 || h <= 0) {
        return;
      }
      // ±1px 往返 = 两次真实 WM_SIZE,强制交换链与合成器重建。
      ::SetWindowPos(hwnd, nullptr, r.left, r.top, w + 1, h, 0);
      Sleep(250);
      ::SetWindowPos(hwnd, nullptr, r.left, r.top, w, h, 0);
      Sleep(900);
    }
    std::fwprintf(stderr, L"voicefox: P0-W1 heal attempts exhausted, giving "
                          L"up (window stays as-is)\n");
  }).detach();
}
