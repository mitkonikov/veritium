#include "flutter_window.h"

#include <optional>

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
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // Remove the native window border (make borderless)
  HWND hwnd = GetHandle();
  LONG style = GetWindowLong(hwnd, GWL_STYLE);
  style &= ~WS_OVERLAPPEDWINDOW;
  style &= ~WS_DLGFRAME;
  style |= WS_POPUP | WS_THICKFRAME;
  SetWindowLong(hwnd, GWL_STYLE, style);
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
              SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "custom_window_controls",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandlePlatformChannel(call.method_name(), call.arguments(), std::move(result));
      });

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
    case WM_NCHITTEST: {
      const LONG border_width = 8; // Resize border width in pixels
      RECT winrect;
      GetWindowRect(hwnd, &winrect);
      const LONG x = ((int)(short)LOWORD(lparam));
      const LONG y = ((int)(short)HIWORD(lparam));
      // Determine if the mouse is on the edge/corner
      if (x >= winrect.left && x < winrect.left + border_width) {
        if (y >= winrect.top && y < winrect.top + border_width)
          return HTTOPLEFT;
        else if (y >= winrect.bottom - border_width && y < winrect.bottom)
          return HTBOTTOMLEFT;
        else
          return HTLEFT;
      } else if (x >= winrect.right - border_width && x < winrect.right) {
        if (y >= winrect.top && y < winrect.top + border_width)
          return HTTOPRIGHT;
        else if (y >= winrect.bottom - border_width && y < winrect.bottom)
          return HTBOTTOMRIGHT;
        else
          return HTRIGHT;
      } else if (y >= winrect.top && y < winrect.top + border_width) {
        return HTTOP;
      } else if (y >= winrect.bottom - border_width && y < winrect.bottom) {
        return HTBOTTOM;
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::HandlePlatformChannel(
    const std::string& method,
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  HWND hwnd = GetHandle();
  if (method == "close") {
    PostMessage(hwnd, WM_CLOSE, 0, 0);
    result->Success();
  } else if (method == "minimize") {
    ShowWindow(hwnd, SW_MINIMIZE);
    result->Success();
  } else if (method == "maximize") {
    if (IsZoomed(hwnd)) {
      ShowWindow(hwnd, SW_RESTORE);
    } else {
      ShowWindow(hwnd, SW_MAXIMIZE);
    }
    result->Success();
  } else if (method == "startDrag") {
    ReleaseCapture();
    SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
    result->Success();
  } else {
    result->NotImplemented();
  }
}