# ChemVision

化学结构解析、可视化编辑与 AI 辅助学习工具。Flutter/Dart 客户端以 SMILES 衔接化学数据库、编辑器和教学流程。

当前应用版本见 `pubspec.yaml`（本轮基线 1.0.64+65），不以历史 README 的 v3.x 宣传标题代替实际发行号。参赛审计、已验证范围和遗留项见 [开放原子 2026 工作包](docs/competitions/openatom-2026/README.md)。

## 能力与边界

| 能力 | 实现与验证范围 |
| --- | --- |
| 名称→结构 | 中文通过 LLM 规范化，随后 PubChem 查询、OPSIN 回退；英文名称可直接走化学数据库。外部服务需联网 |
| 结构显示与编辑 | SmilesDrawer 渲染，Ketcher 编辑器嵌入 WebView/iframe；不是自研编辑器 |
| 图像→SMILES | DECIMER OCSR 客户端与可自部署 Python 包装服务；本项目不提供自训识别模型或准确率保证 |
| SMILES 基础检查 | 括号、标记、环闭合等启发式检查；不等同于严格价态、化学正确性或模型置信度 |
| 收藏/历史/学习记录 | Hive 本地存储；模型配置与结构缓存使用 SharedPreferences |
| 教学 Agent | 预设关键词任务规划→工具注册表→知识点→LLM；含讲解、辅导、诊断、规划、出题、错因分析和对话；不是大模型自主规划算法 |
| 知识库 | 31 个手工知识点，SMILES 子串与名称关键词匹配；存在误匹配，不是化学子图检索 |
| 反应补全 | 本地反应库、可选 Embedding 检索和 LLM；化学方程式、机理和引用必须人工核对 |
| 账号与托管 AI | 可选 Supabase Auth、RLS 与 Edge Functions；需按后端指南配置/部署，不能仅因源码存在宣称线上可用 |
| 语音输入 | vivo 云端 ASR 是独立功能，需配置服务和授权；当前版本已移除内嵌端侧推理 SDK |

没有真实用户规模、教学收益或性能提升的公开验证结论。生成练习题/分析错误不会自动计为学生已答对/答错；掌握度为行为启发式汇总，不能替代正式评价。

## 本地安装与运行

验证工具链：Flutter 3.41.8（stable）、Dart 3.11.5；原多平台 CI 使用 3.41.9。首次运行需联网获取依赖。Android 使用 JDK 17、最低 API 28、arm64；Windows 构建需 Visual Studio C++ 工具链。iOS 未在本次 Windows 环境验证。

```sh
flutter pub get
flutter run -d chrome
```

浏览器 CORS 与 WebView/原生平台能力不同；Web 是当前首选参赛验证目标。未配置 Supabase 也可进入访客界面。AI 默认走托管方式，访客需要在设置页切换“自带 API”，填写 OpenAI 兼容 Base URL、模型 ID 与密钥；图像识别还需可用 DECIMER 端点。纯英文数据库查询不等于调用过 LLM。不要把 API Key 写进代码或构建参数。

自带 AI 服务应允许演示站点 CORS；可以选择自己有权使用的本地 OpenAI 兼容服务。开发代理 `tools/openai_compatible_proxy.js` 默认只监听 `127.0.0.1:8787`，可通过 `AI_TARGET` 指定目标 origin；它不是生产网关，也不会注入密钥。

```sh
node tools/openai_compatible_proxy.js
flutter build web --release
flutter build windows --release
flutter build apk --release
```

Web 产物在 `build/web/`；使用 HTTP 静态服务运行，不要双击本地 HTML。Ketcher/SmilesDrawer 资源随 Flutter assets 打包。Android 当前 release 使用调试签名，不能称正式签名发行；端侧 SDK 移除后的候选快照构建和拆包结果见[验证记录](docs/competitions/openatom-2026/13-current-removal-status.md)。

账号与托管 AI 配置详见 [后端指南](docs/backend-auth.md)。前端仅注入 Supabase URL/publishable key；service-role/上游 AI 密钥仅可置于服务端。DECIMER 可部署入口为 `tools/decimer_hf_space/Dockerfile` 与其锁定依赖；权重首次下载、服务健康和资源配额需实际验证。

## 验证

```sh
flutter analyze --no-fatal-infos
flutter test --reporter expanded
python tools/competition_audit.py --history --output audit.json
flutter build web --release
```

历史静态提示仍会输出，error/warning 阻断。测试桩验证编排与失败路径，不构成真实 AI/OCSR 效果评测。`competition_audit.py` 仅做有范围限制的秘密模式扫描、HTML 引用检查和本机 Pub 许可证文件盘点，不是法律或完整漏洞审计。

新增 Quality workflow 检查 PR/参赛分支；原 `flutter-build.yml` 在 main 推送时还会递增版本、部署 Pages 和发布 Release。未经负责人确认不要推送 main。CI 文件存在不代表远端已运行成功。

## 架构

```text
Flutter UI / Riverpod
  ├─ NameToStructureService → 中文 LLM 规范化 → PubChem → OPSIN
  ├─ ImageStructureService → DECIMER → 轻量 SMILES 检查 → PubChem 候选
  ├─ Ketcher / SmilesDrawer → SMILES / SVG → 收藏与历史
  └─ TaskPlanner → AgentOrchestrator → ToolRegistry
       ├─ OCSR / 化合物查询 / 手工知识库
       ├─ ModelRouter → OpenAI 兼容 API / Supabase AI
       └─ LearningRecordService → 画像汇总 → 诊断与规划上下文
```

模块和接口详情见 [参赛架构文档](docs/competitions/openatom-2026/04-architecture.md)。

## 数据与安全

本地存储不代表没有外部传输：OCSR 接收图片，ASR 接收音频，PubChem/OPSIN 接收名称或结构；模型可接收问题、结构、工具结果、对话历史和学情汇总；账号服务处理邮箱/第三方身份。API Key 在 SharedPreferences 中没有专用加密保护。使用脱敏、获授权样本，遵守服务方条款，详见 [SECURITY.md](SECURITY.md)。不声称已获得隐私合规认证。

## 开源与贡献

自有代码沿用既有 README 的 MIT 选择，标准文本见 [LICENSE](LICENSE)；第三方文件不因此变成 MIT。依赖、来源和待核验项见 [NOTICE](NOTICE) 及 [治理计划](docs/competitions/openatom-2026/09-governance-roadmap.md)。历史提交和已有 Release 保留此前参赛版本，不等于当前源码仍依赖其中的 SDK；全部权利人和素材来源仍须核验。

贡献步骤见 [CONTRIBUTING.md](CONTRIBUTING.md)。未来计划包括严格化学校验、教材关联改进与教师实测，均尚未完成；不在本次短周期进行框架迁移或大规模重构。
