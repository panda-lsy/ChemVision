# BlueLM 完整筛查记录

筛查日期：2026-10-27（北京时间）。当前工作区分支 `competition/openatom-2026`，HEAD `a02b1d8`。筛查包含当前源码及用户既有未提交改动、Android 构建配置和现有制品、公开仓库分支/标签、最新公开 Release、参赛材料；未读取私人合同内容、未修改业务代码或远端仓库。

**结论：BlueLM 尚未从当前代码、Android 构建依赖、公开仓库主分支和最新公开 Android Release 中排除。** 默认端侧开关关闭，只决定默认是否尝试推理，不决定 SDK 是否随源码或安装包分发。

## 源码与运行时

| 项目 | 证据 | 判断 |
| --- | --- | --- |
| 本地 SDK | `android/app/libs/llm-sdk-release.aar`，1,602,430 字节，SHA-256 `27a03adc7ef39f1f69f9eb3569b28b8abb35380282f0eb2c57bb0757a1d640e0` | Git 已跟踪；AAR 中有 `com.vivo.llmsdk` 类和 ARM64 原生库 |
| Android 依赖 | `android/app/build.gradle.kts:69` | `fileTree` 引入 `libs` 下所有 `.aar`；未发现将该 AAR 排除的配置 |
| Android 原生桥 | `android/app/src/main/kotlin/com/chemvision/chemvision/BlueLmPlugin.kt` | 直接引用 SDK 类型，通过 `com.chemvision/bluelm` MethodChannel 提供能力 |
| 启动时注册 | `android/app/src/main/kotlin/com/chemvision/chemvision/MainActivity.kt:12` | 无条件注册插件；启动时还检查并可能引导授予所有文件访问权限，与端侧开关无关 |
| 权限和混淆 | `AndroidManifest.xml:6`、`proguard-rules.pro:3` | 存储、厂商权限及可选原生库声明仍在；保留 SDK 类的 ProGuard 规则仍在 |
| Flutter 服务和路由 | `lib/services/bluelm_service.dart`、`lib/services/model_router.dart:24` | 开关开启时尝试端侧文本推理，异常时回退云端；多模态路径不使用该端侧实现 |
| 设置入口 | `lib/ui/pages/settings_page.dart:100`、`:452` | 默认值关闭，历史 SharedPreferences 中的 `bluelm_use_local` 可能为真；仍可在设置页切换及测试 |
| 其他路由 | `lib/services/real_structure_service.dart:84` | 端侧开关还会影响名称解析的云模型配置检查；Agent、反应补全及名称解析调用文本路由 |

`lib/services/asr_service_io.dart` 中 vivo 云端语音识别是独立功能；不能仅凭供应商名称把它归入 BlueLM 或直接删除。

SDK 和原生库的存在不等于蓝心模型权重已被包含或公开。代码默认模型路径指向 Android 设备上的 `/sdcard/1225/...`；在 `lib/`、`android/`、`assets/`、`tools/` 中按 `.gguf`、`.safetensors`、`.onnx`、`.tflite`、`.pth`、`.pt` 常见后缀搜索未命中，但这不是对所有格式、忽略目录或设备文件的完整排查。

## 本地构建与制品

- 旧 `build/app/outputs/flutter-apk/app-debug.apk`（2026-07-02）和 `app-release.apk`（2026-07-06）的 DEX 均检出 `com/vivo/llmsdk`，也含 `libllm_apu_7b.so`、`libllm_base_7b.so`、`libllm_jni.so`、`libvivo_tokenizer.so`。它们是旧产物，不能单独证明 10 月源码的新构建结果。
- 2026-10-22 的两个 Web 产物的 `main.dart.js` 均含 `com.chemvision/bluelm`、`bluelm_use_local` 字符串；Web 目录未发现 AAR 或 `.so`。字符串表明相关客户端代码仍可能进入 Web 构建，**不证明浏览器拥有或运行原生 BlueLM SDK**。
- 被忽略的 `build/openatom-candidate-20261022/` 源码快照、`build/openatom-baseline-20261022.zip` 和 Android 中间产物中仍有相关文件。`miniprogram_mpflutter` 是被忽略的独立仓库，也有同名服务，是否属于本次交付待负责人确定。
- 隔离快照中 Android 配置、Manifest、插件与当前工作区在统一换行后内容一致，AAR 字节完全相同；快照不含原有未提交的设置页及其他用户改动，因此不是对当前工作区全部内容的构建复现。
- 快照首次 `flutter build apk --release --no-pub` 使用本机 Java 25 失败；在**隔离快照**的 `android/gradle.properties` 临时指定本机 JDK 17 后进行了第二次构建。本项的最终结果和新 APK 检查结果见本文件末尾的构建记录。

## 公开仓库、历史与 Release

通过 GitHub 只读元数据及 `git ls-remote` 核验，仓库 [`panda-lsy/ChemVision`](https://github.com/panda-lsy/ChemVision) 当前为**公开**；这是已有状态，本次没有改变可见性。远端 `main` 指向 `626e4a6777fb1e73ed4ee09dcfad283c40447fb5`，其 `android/app/libs/llm-sdk-release.aar` Git blob 为 `40ad0456c3f3f5f56b84f389e563a5f563bac189`，与本地 AAR 相同。远端分支指针与本地缓存一致。

| 范围 | 检查结果 |
| --- | --- |
| `main`、`ChemEdu` | 分支顶端均含 AAR；本地 `competition/openatom-2026` 和 `backup/before-revert` 也含 AAR |
| `feature/web-deploy` | 分支顶端和该分支历史不含该 AAR；这是较早分支，不代表公开仓库整体不含 SDK |
| Git 历史 | AAR 首次加入 `0982a78`，日期 2026-06-24。后续“去除蓝心大模型注名”提交只调整部分名称，没有删除 SDK |
| 远端标签 | 2026-10-27 只读列出 44 个远端标签；按远端标签对象对应的本地提交树检查，42 个含该 AAR、2 个不含 |
| 最新正式 Release | [`v1.0.64+65`](https://github.com/panda-lsy/ChemVision/releases/tag/v1.0.64%2B65)，2026-10-08 18:06:04 北京时间；`app-release.apk` 大小 101,545,460 字节 |

**最新公开 Release APK 已直接验证**：通过 HTTP Range 读取该 APK 的 ZIP 中央目录和 `lib/arm64-v8a/libllm_jni.so`，无需下载整个安装包。目录包含 `libllm_apu_7b.so`、`libllm_base_7b.so`、`libllm_jni.so`、`libvivo_tokenizer.so`；其中实际读取并解压的 `libllm_jni.so` SHA-256 为 `926720995c88a6e18616f841edff6074874e98b3b3e1f57e4d73c1757b2faba6`，与当前 AAR 内同名文件**字节完全一致**。检查证明该公开 APK 包含 SDK 原生库，不证明实际设备推理成功。

仅从未来提交删除 AAR 并不能自动清除既有公开的 Git 历史、标签、Release 资产、克隆或第三方缓存；任何远端历史改写、删除制品、权限或可见性变更都需要负责人明确授权。

## 许可、隐私和参赛材料

- 扫描 AAR 及其 `classes.jar`，没有发现 LICENSE、NOTICE、COPYRIGHT 或 POM 元数据。本地文档对某个开源模型的描述不足以证明 AAR、原生库及模型权重各自具有再分发授权；不等于已经认定侵权。应向权利人核验实际版本的授权原件和适用范围。
- `BlueLmPlugin.kt:84`、`:120` 附近将提示词前 50 字和回复前 100 字写入 Logcat，存在敏感内容暴露风险。隔离快照新 Release 的 DEX 仍含相应日志字符串，但未在设备上确认日志是否实际输出，也没有证据表明发生过泄漏。
- 仓库 `README.md`、`NOTICE`、赛事架构/治理/清单，以及 `tools/update_goai_ppt.py` 存在 BlueLM 描述。2026-10-22 PDF 审阅稿第 6、12、14 页也提及该依赖；它们是历史说明，并非 SDK 已排除的证据。
- 对公开分发的完整性与权利链的核验仍为参赛前阻断项；不能仅通过隐藏设置开关或删除文档名称关闭该风险。

## 建议后续处理（尚未执行）

1. 先由负责人确认是否继续保留端侧功能和现有可再分发授权，记录 SDK、原生库、权重分别对应的许可。
2. 若决定排除，需覆盖 Flutter 设置与路由、原生注册、Gradle 依赖/混淆、Manifest 权限、AAR 以及相关文档和源码快照；保留独立的 vivo ASR。用户现有未提交设置页改动需要合并保护。
3. 使用干净检出构建 Android Debug/Release 和 Web，检查 APK 的 DEX、`.so`、AAR，以及默认配置和其他功能；重新核对工具与参赛材料。
4. 已公开的主分支、历史、标签及 Release 资产分别拟定处理方案，先说明影响与恢复方式，再由用户决定是否授权远端变更。

本次筛查没有进行上述移除或远端变更；未验证所有设备型号、所有历史 Release 安装包、被忽略目录中的全部私人内容，也没有进行法律结论或原生推理成功率测试。

## 隔离快照 Android 构建记录

1. 默认本机 Java 25 的首次构建退出 1，日志的错误内容为 `25.0.3`；未获取足够诊断信息确认具体根因。
2. 在隔离快照临时追加 `org.gradle.java.home=D:/Applications/Java/Java17` 后，`flutter build apk --release --no-pub` 退出 0，Gradle 日志记录 537.6 秒。验证后已移除快照中这一临时设置；项目原有配置没有修改，生成的 APK 仅用于本地验证。
3. 新 APK 大小 101,431,516 字节，SHA-256 `0da89f93534209c5af82e7a211dafb83f535f41753fa43321c5d89f884fa709b`。其 `classes.dex` 包含 `Lcom/vivo/llmsdk/` 和相关日志字符串。
4. APK 中的 `libcvkit_camera.so`、`libllm_apu_7b.so`、`libllm_base_7b.so`、`libllm_jni.so`、`libvivo_tokenizer.so` 均与 AAR 中相应文件字节一致。这里核查了 AAR 的全部 5 个 ARM64 原生库；远端 APK 的 Range 检查实际逐字节核验了其中 `libllm_jni.so`。
5. 对新 APK 执行 `aapt dump permissions`，确认最终 Manifest 中仍有 `MANAGE_EXTERNAL_STORAGE`、读写外部存储（最高 SDK 32）、`mediatek.permission.ACCESS_APU_SYS` 和 `vivo.aiservice.permission.AISERVICE_ACCESS`。这证明声明被打包，不证明用户已授予这些权限。
6. 结构化记录见 [`evidence/bluelm-rescreen-2026-10-27.json`](evidence/bluelm-rescreen-2026-10-27.json)，两次构建日志分别为 `evidence/bluelm-build-java25.txt` 和 `evidence/bluelm-build-jdk17.txt`。本地快照与工作区 Android 相关文件的比较只忽略文本换行差异；不代表全部未提交工作已纳入快照。
