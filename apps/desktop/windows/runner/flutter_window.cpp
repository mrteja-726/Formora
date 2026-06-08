#include "flutter_window.h"

#include <optional>
#include <string>
#include <vector>
#include <UIAutomation.h>
#include <wrl/client.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

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

  // Setup Formora Autofill Method Channel
  autofill_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "formora/autofill",
      &flutter::StandardMethodCodec::GetInstance());

  autofill_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("isAccessibilityTrusted") == 0) {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name().compare("getFocusedElement") == 0) {
          Microsoft::WRL::ComPtr<IUIAutomation> uia;
          HRESULT hr = CoCreateInstance(CLSID_CUIAutomation, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&uia));
          if (FAILED(hr)) {
            result->Success(flutter::EncodableMap{
              {flutter::EncodableValue("success"), flutter::EncodableValue(false)}
            });
            return;
          }

          Microsoft::WRL::ComPtr<IUIAutomationElement> element;
          hr = uia->GetFocusedElement(&element);
          if (FAILED(hr) || !element) {
            result->Success(flutter::EncodableMap{
              {flutter::EncodableValue("success"), flutter::EncodableValue(false)}
            });
            return;
          }

          flutter::EncodableMap res_map;
          res_map[flutter::EncodableValue("success")] = flutter::EncodableValue(true);

          BSTR bstr_name = nullptr;
          if (SUCCEEDED(element->get_CurrentName(&bstr_name)) && bstr_name) {
            res_map[flutter::EncodableValue("name")] = flutter::EncodableValue(Utf8Encode(bstr_name));
            SysFreeString(bstr_name);
          }

          BSTR bstr_id = nullptr;
          if (SUCCEEDED(element->get_CurrentAutomationId(&bstr_id)) && bstr_id) {
            res_map[flutter::EncodableValue("id")] = flutter::EncodableValue(Utf8Encode(bstr_id));
            SysFreeString(bstr_id);
          }

          BSTR bstr_class = nullptr;
          if (SUCCEEDED(element->get_CurrentClassName(&bstr_class)) && bstr_class) {
            res_map[flutter::EncodableValue("className")] = flutter::EncodableValue(Utf8Encode(bstr_class));
            SysFreeString(bstr_class);
          }

          CONTROLTYPEID control_type = 0;
          if (SUCCEEDED(element->get_CurrentControlType(&control_type))) {
            res_map[flutter::EncodableValue("controlType")] = flutter::EncodableValue(static_cast<int32_t>(control_type));
          }

          result->Success(flutter::EncodableValue(res_map));
        } else if (call.method_name().compare("triggerAutofill") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("BAD_ARGS", "Expected map containing 'value'");
            return;
          }

          auto val_it = arguments->find(flutter::EncodableValue("value"));
          if (val_it == arguments->end()) {
            result->Error("BAD_ARGS", "Missing key 'value'");
            return;
          }

          std::string fill_value = std::get<std::string>(val_it->second);
          std::wstring w_value = Utf8Decode(fill_value);

          Microsoft::WRL::ComPtr<IUIAutomation> uia;
          HRESULT hr = CoCreateInstance(CLSID_CUIAutomation, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&uia));
          if (FAILED(hr)) {
            result->Success(flutter::EncodableValue(false));
            return;
          }

          Microsoft::WRL::ComPtr<IUIAutomationElement> element;
          hr = uia->GetFocusedElement(&element);
          if (FAILED(hr) || !element) {
            result->Success(flutter::EncodableValue(false));
            return;
          }

          // Try ValuePattern SetValue
          IUIAutomationValuePattern* val_pattern = nullptr;
          hr = element->GetCurrentPatternAs(UIA_ValuePatternId, IID_PPV_ARGS(&val_pattern));
          if (SUCCEEDED(hr) && val_pattern) {
            BSTR bstr_val = SysAllocString(w_value.c_str());
            hr = val_pattern->SetValue(bstr_val);
            SysFreeString(bstr_val);
            val_pattern->Release();
            if (SUCCEEDED(hr)) {
              result->Success(flutter::EncodableValue(true));
              return;
            }
          }

          // Keyboard simulation fallback (Ctrl+A -> Backspace -> Type)
          std::vector<INPUT> inputs;

          // Ctrl + A
          INPUT ctrl_a[4] = {};
          for (int i = 0; i < 4; ++i) ctrl_a[i].type = INPUT_KEYBOARD;
          ctrl_a[0].ki.wVk = VK_CONTROL;
          ctrl_a[1].ki.wVk = 'A';
          ctrl_a[2].ki.wVk = 'A';
          ctrl_a[2].ki.dwFlags = KEYEVENTF_KEYUP;
          ctrl_a[3].ki.wVk = VK_CONTROL;
          ctrl_a[3].ki.dwFlags = KEYEVENTF_KEYUP;

          for (int i = 0; i < 4; ++i) inputs.push_back(ctrl_a[i]);

          // Backspace
          INPUT backspace[2] = {};
          backspace[0].type = INPUT_KEYBOARD;
          backspace[0].ki.wVk = VK_BACK;
          backspace[1].type = INPUT_KEYBOARD;
          backspace[1].ki.wVk = VK_BACK;
          backspace[1].ki.dwFlags = KEYEVENTF_KEYUP;

          inputs.push_back(backspace[0]);
          inputs.push_back(backspace[1]);

          SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
          inputs.clear();

          Sleep(50);

          // Unicode typing
          for (wchar_t ch : w_value) {
            INPUT input_down = {};
            input_down.type = INPUT_KEYBOARD;
            input_down.ki.wVk = 0;
            input_down.ki.wScan = ch;
            input_down.ki.dwFlags = KEYEVENTF_UNICODE;
            inputs.push_back(input_down);

            INPUT input_up = {};
            input_up.type = INPUT_KEYBOARD;
            input_up.ki.wVk = 0;
            input_up.ki.wScan = ch;
            input_up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
            inputs.push_back(input_up);
          }

          SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
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

std::string FlutterWindow::Utf8Encode(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
  std::string strTo(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
  return strTo;
}

std::wstring FlutterWindow::Utf8Decode(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
  std::wstring wstrTo(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
  return wstrTo;
}
