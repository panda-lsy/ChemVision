# 当前分支 SDK 移除与验证

> 历史记录：本文为 SDK 移除时的验证快照；随后语音方案的调整见[最新语音说明](14-speech-replacement.md)。

更新日期：2026-10-28。按照项目负责人要求，当前参赛分支移除此前接入的 BlueLM 原生推理 SDK；此前用于 AIGC 挑战赛的历史版本保留。

## 已完成的代码变更

- 删除 Android SDK AAR、原生插件及注册、Dart 桥接、模型路由、设置入口和 SDK 专用权限/依赖；托管 AI 与用户配置的 OpenAI 兼容服务仍保留。
- vivo 云端语音识别是独立功能，源码保留。本轮没有实际设备、服务账号的语音端到端验证。
- 设备里以前保存的模型文件和设置不会自动删除；回归测试检查旧端侧开关为真时不再影响云端路由或绕过模型配置检查。
- 修正既有 Android 版本号回退：未指定 Gradle 覆盖值时使用 Flutter 项目版本。构建前观察到包版本为 `1.0.0+1`，修正后实际安装包为 `1.0.64+65`，与本次候选 `pubspec.yaml` 一致。

## 独立快照验证

| 检查 | 命令或方式 | 结果 |
| --- | --- | --- |
| 依赖 | `flutter pub get --offline --enforce-lockfile` | 成功，使用锁文件和本机缓存 |
| 静态分析 | `flutter analyze --no-pub --no-fatal-infos` | 通过；43 条 info，无 error/warning，[日志](evidence/removal-analysis-20261028.txt) |
| 回归 | `flutter test --no-pub --reporter expanded` | 30 通过、3 个需显式启用的真实网络用例跳过；4 个测试覆盖旧开关、托管路由和兼容 API，[日志](evidence/removal-tests-20261028.txt) |
| Web | `flutter build web --release --no-pub` | 成功；`main.dart.js` 未命中 SDK、旧通道和旧开关标记 |
| Android | `flutter build apk --release --no-pub` | 成功；解包检查 13 个 DEX、原生库或归档条目，未命中相关标记或旧 SDK 原生库名称/哈希；最终权限未包含 SDK 专用权限 |

结构化证据、SHA-256 和检查范围见 [产物验证记录](evidence/removal-artifact-verification-20261028.json)。分析、测试和 Web 使用树 `f0bf01db757919d8e890093e44ee1112870d1968`；Android 使用树 `8cc3ac13385de23afe9eec8b557b52d7d80ba8d2`，两者只差 Android 版本号配置。候选不含用户原有未提交修改；后续仅修改文档与证据。

Android 构建仅在隔离快照临时指定 JDK 17，完成后已移除。测试包使用调试签名；未验证真实设备安装、真实模型调用或真实语音服务。

## 历史记录与交付边界

历史审计 [2026-10-22](01-audit.md)、[2026-10-27 移除前筛查](12-bluelm-rescreen-2026-10-27.md) 及对应证据保留当时事实。旧快照、APK、Git 历史、标签及已公开 Release 保持不变；本轮未推送或调整仓库可见性。历史 SDK 授权和其他第三方权利仍需核验，最终提交前需完成真实演示与版本复核。
