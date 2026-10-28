# 语音识别替换与验证

更新：2026-10-28。语音输入改用 `speech_to_text` 7.4.0 调用设备或浏览器提供的短语音识别能力，不再接入此前的 vivo 专用语音接口，也不需要单独设置旧语音 API Key。

## 实现与数据边界

- Android 通过系统语音识别服务，Web 使用浏览器语音识别能力，Windows 通过系统语音接口。权限、语言包、浏览器支持和服务网络条件决定实际可用性；不能声称一定离线。
- 音频可能由操作系统或浏览器选择的服务商处理；界面和隐私说明已提示。麦克风权限由语音功能在使用时请求，不再在应用启动时主动请求。
- 专用语音 Key 不再读取；历史共享键仅供旧文本模型配置迁移，不用于语音。设备中已有设置不会被自动删除。
- 识别结果与等待状态分离；服务不可用、权限错误、超时或空结果显示失败，不再将占位文字填入输入框。取消后丢弃迟到结果，不在应用日志输出识别文字。
- 上游 Windows 实现为 BSD-3-Clause，本仓库保留其许可并说明本地修改：移除识别文字控制台日志，处理 JSON 转义和缓冲区长度；未取得真实置信度时标为缺失；修复停止和销毁时的工作线程管理。Windows 实际识别仍需目标设备验证。

## 已执行的验证

| 检查 | 结果 |
| --- | --- |
| `flutter analyze --no-pub --no-fatal-infos` | 通过；43 条 info，无 error/warning，[日志](evidence/speech-analysis-20261028.txt) |
| `flutter test --no-pub --reporter expanded` | 40 通过、3 个真实网络测试默认跳过；新增 10 个模拟后端和组件测试，[日志](evidence/speech-tests-20261028.txt) |
| `flutter build web --release --no-pub` | 成功 |
| `flutter build apk --release --no-pub` | 成功；JDK 17 仅在隔离快照临时指定 |
| `flutter build windows --release --no-pub` | 成功；包含经修改的语音适配插件 |
| 产物检查 | APK 含系统识别服务查询声明和麦克风权限；未命中旧语音端点或 BlueLM 标记/原生库。Windows 插件二进制未命中旧识别文本日志标记；哈希和权限见[记录](evidence/speech-artifacts-20261028.json) |

这些测试在排除用户原有未提交改动的本地候选快照中执行，语音测试使用模拟后端。Android 设备未获得 ADB 授权，本轮没有实际录音或真实识别结果；iOS 未构建验证。Android 验证包使用调试签名，不是正式发布包。

## 使用与后续验收

在输入页点击麦克风，按系统提示授权后说出短句；识别文本回填输入框，用户可编辑后提交。若系统不提供相应语言或浏览器不支持语音识别，应提示不可用，并可继续使用文字输入。正式演示前应在目标 Android、Windows 和浏览器上逐一检查权限、中文识别、取消、网络断开和无语音输入；不要将模拟测试当作识别效果数据。

上游资料：[speech_to_text 7.4.0](https://pub.dev/packages/speech_to_text/versions/7.4.0)、[Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer)、[Web Speech API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API)。
