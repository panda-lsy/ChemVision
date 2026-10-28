#include "speech_to_text_windows_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <sapi.h>
#include <iostream>
#include <thread>
#include <string>
#include <functional>

namespace speech_to_text_windows {

#define PARTIAL_RESULT 0
#define FINAL_RESULT 2

// Recognition results can contain quotes and control characters. Preserve
// UTF-8 bytes and escape JSON syntax without logging the recognized text.
static std::string EscapeJson(const std::string& text) {
  static constexpr char hex[] = "0123456789abcdef";
  std::string escaped;
  for (unsigned char ch : text) {
    switch (ch) {
      case '"': escaped += "\\\""; break;
      case '\\': escaped += "\\\\"; break;
      case '\b': escaped += "\\b"; break;
      case '\f': escaped += "\\f"; break;
      case '\n': escaped += "\\n"; break;
      case '\r': escaped += "\\r"; break;
      case '\t': escaped += "\\t"; break;
      default:
        if (ch < 0x20) {
          escaped += "\\u00";
          escaped += hex[ch >> 4];
          escaped += hex[ch & 0x0f];
        } else {
          escaped += static_cast<char>(ch);
        }
    }
  }
  return escaped;
}

// Flutter version detection: Check if GetTaskRunner() is available
// This is a compile-time check to determine the dispatch method
#if defined(FLUTTER_VERSION_MAJOR) && defined(FLUTTER_VERSION_MINOR)
  #if (FLUTTER_VERSION_MAJOR > 3) || (FLUTTER_VERSION_MAJOR == 3 && FLUTTER_VERSION_MINOR >= 40)
    #define HAS_TASK_RUNNER 1
  #else
    #define HAS_TASK_RUNNER 0
  #endif
#else
  // Fallback: Try to detect by checking if GetTaskRunner() exists in the API
  // If the method exists, the linker will succeed; otherwise use fallback
  #ifdef __has_include
    #if __has_include(<flutter/task_runner.h>)
      #define HAS_TASK_RUNNER 1
    #else
      #define HAS_TASK_RUNNER 0
    #endif
  #else
    // Conservative fallback for older compilers
    #define HAS_TASK_RUNNER 0
  #endif
#endif

void SpeechToTextWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "speech_to_text_windows",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<SpeechToTextWindowsPlugin>();
  plugin->m_channel = std::move(channel);
  plugin->m_registrar = registrar;

  plugin->m_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

SpeechToTextWindowsPlugin::SpeechToTextWindowsPlugin()
  : m_cpRecognizer(nullptr)
  , m_cpRecoContext(nullptr)
  , m_cpRecoGrammar(nullptr)
  , m_cpAudio(nullptr)
  , m_initialized(false)
  , m_listening(false) {
  std::cout << "SpeechToTextWindowsPlugin created" << std::endl;
  CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
}

SpeechToTextWindowsPlugin::~SpeechToTextWindowsPlugin() {
  std::cout << "SpeechToTextWindowsPlugin destroyed" << std::endl;

  // Stop also waits for the worker, before releasing the SAPI objects.
  m_alive->store(false);
  Stop(nullptr);
  std::lock_guard<std::mutex> lock(m_mutex);

  if (m_cpRecoGrammar) {
    m_cpRecoGrammar->Release();
    m_cpRecoGrammar = nullptr;
  }
  if (m_cpRecoContext) {
    m_cpRecoContext->Release();
    m_cpRecoContext = nullptr;
  }
  if (m_cpRecognizer) {
    m_cpRecognizer->Release();
    m_cpRecognizer = nullptr;
  }
  if (m_cpAudio) {
    m_cpAudio->Release();
    m_cpAudio = nullptr;
  }

  CoUninitialize();
}

// Template implementation for thread-safe dispatch to UI thread
// This method chooses the appropriate dispatch mechanism based on Flutter version
template<typename Callback>
void SpeechToTextWindowsPlugin::DispatchToUIThread(Callback&& callback) {
#if HAS_TASK_RUNNER
  // Flutter 3.40+: Use the official TaskRunner API
  // This is the recommended approach and eliminates threading warnings
  if (m_registrar) {
    std::cout << "[Dispatch] Using GetTaskRunner()->PostTask() (Flutter 3.40+)" << std::endl;
    m_registrar->GetTaskRunner()->PostTask(std::forward<Callback>(callback));
  } else {
    std::cout << "[Dispatch] Warning: Registrar not available, executing directly" << std::endl;
    callback();
  }
#else
  // Flutter < 3.40: Direct invocation (generates warning but works)
  // GetTaskRunner() is not available in older Flutter versions
  std::cout << "[Dispatch] Using direct call (Flutter < 3.40, threading warning expected)" << std::endl;
  callback();
#endif
}

void SpeechToTextWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const std::string& method_name = method_call.method_name();
  std::cout << "Method called: " << method_name << std::endl;

  if (method_name == "hasPermission") {
    result->Success(flutter::EncodableValue(true));
  } else if (method_name == "initialize") {
    Initialize(method_call, std::move(result));
  } else if (method_name == "listen") {
    Listen(method_call, std::move(result));
  } else if (method_name == "stop") {
    Stop(std::move(result));
  } else if (method_name == "cancel") {
    Cancel(std::move(result));
  } else if (method_name == "locales") {
    GetLocales(std::move(result));
  } else {
    result->NotImplemented();
  }
}

void SpeechToTextWindowsPlugin::Initialize(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  std::lock_guard<std::mutex> lock(m_mutex);

  if (m_initialized) {
    std::cout << "Already initialized" << std::endl;
    result->Success(flutter::EncodableValue(true));
    return;
  }

  std::cout << "Initializing SAPI speech recognition..." << std::endl;

  try {
    HRESULT hr = S_OK;

    // Create a recognition engine
    hr = CoCreateInstance(CLSID_SpInprocRecognizer, NULL, CLSCTX_INPROC_SERVER,
                         IID_ISpRecognizer, (void**)&m_cpRecognizer);
    if (FAILED(hr)) {
      std::cout << "Failed to create speech recognizer. HRESULT: " << std::hex << hr << std::endl;
      result->Success(flutter::EncodableValue(false));
      return;
    }

    // Create default audio input
    hr = CoCreateInstance(CLSID_SpMMAudioIn, NULL, CLSCTX_INPROC_SERVER,
                         IID_ISpAudio, (void**)&m_cpAudio);
    if (FAILED(hr)) {
      std::cout << "Failed to create audio input. HRESULT: " << std::hex << hr << std::endl;
      result->Success(flutter::EncodableValue(false));
      return;
    }

    // Set the audio input to our recognizer
    hr = m_cpRecognizer->SetInput(m_cpAudio, TRUE);
    if (FAILED(hr)) {
      std::cout << "Failed to set audio input. HRESULT: " << std::hex << hr << std::endl;
      result->Success(flutter::EncodableValue(false));
      return;
    }

    // Create a recognition context
    hr = m_cpRecognizer->CreateRecoContext(&m_cpRecoContext);
    if (FAILED(hr)) {
      std::cout << "Failed to create recognition context. HRESULT: " << std::hex << hr << std::endl;
      result->Success(flutter::EncodableValue(false));
      return;
    }

    // Create a grammar
    hr = m_cpRecoContext->CreateGrammar(0, &m_cpRecoGrammar);
    if (FAILED(hr)) {
      std::cout << "Failed to create grammar. HRESULT: " << std::hex << hr << std::endl;
      result->Success(flutter::EncodableValue(false));
      return;
    }

    // Enable dictation grammar
    hr = m_cpRecoGrammar->LoadDictation(NULL, SPLO_STATIC);
    if (FAILED(hr)) {
      std::cout << "Failed to load dictation grammar. HRESULT: " << std::hex << hr << std::endl;
      result->Success(flutter::EncodableValue(false));
      return;
    }

    m_initialized = true;
    std::cout << "SAPI speech recognition initialized successfully!" << std::endl;
    result->Success(flutter::EncodableValue(true));

  } catch (...) {
    std::cout << "Exception during initialization" << std::endl;
    result->Success(flutter::EncodableValue(false));
  }
}

void SpeechToTextWindowsPlugin::Listen(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  std::lock_guard<std::mutex> lock(m_mutex);

  if (!m_initialized || !m_cpRecoGrammar) {
    std::cout << "Speech recognition not initialized" << std::endl;
    result->Error("NOT_INITIALIZED", "Speech recognition not initialized");
    return;
  }

  if (m_listening) {
    std::cout << "Already listening" << std::endl;
    result->Success(flutter::EncodableValue(true));
    return;
  }

  std::cout << "Starting speech recognition..." << std::endl;

  try {
    // Activate the grammar
    HRESULT hr = m_cpRecoGrammar->SetDictationState(SPRS_ACTIVE);
    if (FAILED(hr)) {
      std::cout << "Failed to activate dictation. HRESULT: " << std::hex << hr << std::endl;
      result->Success(flutter::EncodableValue(false));
      return;
    }

    m_listening = true;
    SendStatus("listening");
    std::cout << "Speech recognition listening started!" << std::endl;
    // Start recognition thread
    m_worker = std::thread([this]() {
      std::cout << "Recognition thread started" << std::endl;

      SPEVENT event;
      ULONG fetched = 0;

      while (m_listening && m_cpRecoContext) {
        HRESULT hr = m_cpRecoContext->GetEvents(1, &event, &fetched);

        if (SUCCEEDED(hr) && fetched > 0) {
          std::cout << "Speech event received. Event ID: " << event.eEventId << std::endl;

          switch (event.eEventId) {
            case SPEI_RECOGNITION: {
              std::cout << "SPEI_RECOGNITION event" << std::endl;
              ISpRecoResult* pResult = reinterpret_cast<ISpRecoResult*>(event.lParam);
              if (pResult) {
                LPWSTR pwszText;
                hr = pResult->GetText(SP_GETWHOLEPHRASE, SP_GETWHOLEPHRASE,
                                    TRUE, &pwszText, NULL);
                if (SUCCEEDED(hr) && pwszText) {
                  // Convert to UTF-8
                  int size = WideCharToMultiByte(CP_UTF8, 0, pwszText, -1,
                                               nullptr, 0, nullptr, nullptr);
                  if (size > 0) {
                    std::string utf8Text(size, '\0');
                    WideCharToMultiByte(CP_UTF8, 0, pwszText, -1,
                                      &utf8Text[0], size, nullptr, nullptr);
                    utf8Text.resize(size - 1);
                    SendTextRecognition(utf8Text, true);
                  }
                  CoTaskMemFree(pwszText);
                }
                pResult->Release();
              }
              break;
            }
            case SPEI_HYPOTHESIS: {
              std::cout << "SPEI_HYPOTHESIS event" << std::endl;
              ISpRecoResult* pResult = reinterpret_cast<ISpRecoResult*>(event.lParam);
              if (pResult) {
                LPWSTR pwszText;
                hr = pResult->GetText(SP_GETWHOLEPHRASE, SP_GETWHOLEPHRASE,
                                    TRUE, &pwszText, NULL);
                if (SUCCEEDED(hr) && pwszText) {
                  // Convert to UTF-8
                  int size = WideCharToMultiByte(CP_UTF8, 0, pwszText, -1,
                                               nullptr, 0, nullptr, nullptr);
                  if (size > 0) {
                    std::string utf8Text(size, '\0');
                    WideCharToMultiByte(CP_UTF8, 0, pwszText, -1,
                                      &utf8Text[0], size, nullptr, nullptr);
                    utf8Text.resize(size - 1);
                    SendTextRecognition(utf8Text, false);
                  }
                  CoTaskMemFree(pwszText);
                }
                pResult->Release();
              }
              break;
            }
            case SPEI_SOUND_START:
              std::cout << "Sound detected!" << std::endl;
              SendStatus("soundDetected");
              break;
            case SPEI_SOUND_END:
              std::cout << "Sound ended" << std::endl;
              SendStatus("soundEnded");
              break;
          }
        }

        Sleep(50); // Small delay to prevent busy waiting
      }

      std::cout << "Recognition thread ended" << std::endl;
    });
    result->Success(flutter::EncodableValue(true));

  } catch (...) {
    m_listening = false;
    if (m_cpRecoGrammar) {
      m_cpRecoGrammar->SetDictationState(SPRS_INACTIVE);
    }
    std::cout << "Exception during listen" << std::endl;
    result->Success(flutter::EncodableValue(false));
  }
}

void SpeechToTextWindowsPlugin::Stop(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  bool was_listening = false;
  {
    std::lock_guard<std::mutex> lock(m_mutex);
    was_listening = m_listening.exchange(false);
    if (was_listening && m_cpRecoGrammar) {
      m_cpRecoGrammar->SetDictationState(SPRS_INACTIVE);
    }
  }
  if (m_worker.joinable()) {
    m_worker.join();
  }
  if (was_listening) {
    SendStatus("notListening");
  }

  if (result) {
    result->Success(flutter::EncodableValue(nullptr));
  }
}

void SpeechToTextWindowsPlugin::Cancel(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::cout << "Canceling speech recognition..." << std::endl;
  Stop(std::move(result));
}

void SpeechToTextWindowsPlugin::GetLocales(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  flutter::EncodableList locales;
  locales.push_back(flutter::EncodableValue("en-US:English (United States)"));
  locales.push_back(flutter::EncodableValue("en-GB:English (United Kingdom)"));

  result->Success(flutter::EncodableValue(locales));
}

void SpeechToTextWindowsPlugin::SendTextRecognition(const std::string& text, bool is_final) {
  if (m_channel) {
    // Build JSON result with all required fields for compatibility
    const std::string escaped_text = EscapeJson(text);
    std::string json_result = "{\"recognizedWords\":\"" + escaped_text +
                             "\",\"finalResult\":" + (is_final ? "true" : "false") +
                             ",\"alternates\":[{\"recognizedWords\":\"" + escaped_text +
                             "\",\"confidence\":-1.0}],\"resultType\":" +
                             (is_final ? std::to_string(FINAL_RESULT) : std::to_string(PARTIAL_RESULT)) + "}";

    // Dispatch to UI thread using version-aware helper
    // Captures channel pointer and json_result by value for thread safety
    auto channel = m_channel.get();
    auto alive = m_alive;
    DispatchToUIThread([channel, json_result, alive]() {
      if (!alive->load()) return;
      channel->InvokeMethod("textRecognition",
          std::make_unique<flutter::EncodableValue>(json_result));
    });
  }
}

void SpeechToTextWindowsPlugin::SendError(const std::string& error) {
  if (m_channel) {
    std::cout << "Sending error: " << error << std::endl;

    // Dispatch to UI thread using version-aware helper
    auto channel = m_channel.get();
    auto alive = m_alive;
    DispatchToUIThread([channel, error, alive]() {
      if (!alive->load()) return;
      channel->InvokeMethod("notifyError",
          std::make_unique<flutter::EncodableValue>(error));
    });
  }
}

void SpeechToTextWindowsPlugin::SendStatus(const std::string& status) {
  if (m_channel) {
    std::cout << "Sending status: " << status << std::endl;

    // Dispatch to UI thread using version-aware helper
    auto channel = m_channel.get();
    auto alive = m_alive;
    DispatchToUIThread([channel, status, alive]() {
      if (!alive->load()) return;
      channel->InvokeMethod("notifyStatus",
          std::make_unique<flutter::EncodableValue>(status));
    });
  }
}

}  // namespace speech_to_text_windows

// C API export for Flutter plugin registration
extern "C" __declspec(dllexport) void SpeechToTextWindowsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  speech_to_text_windows::SpeechToTextWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
