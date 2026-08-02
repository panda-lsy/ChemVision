<div align="center">

# ChemVISION

### 化学结构式智能生成、编辑与学习助手 · ChemEdu Agent

![Version](https://img.shields.io/badge/version-v3.0-38d5c1?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Flutter%20Android-4FC3F7?style=flat-square)
![AI](https://img.shields.io/badge/AI-BlueLM-7C4DFF?style=flat-square)
![Agent](https://img.shields.io/badge/Agent-ChemEdu-FF7043?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

**通用大模型「能说化学，却不能画化学」——ChemVISION 补齐这条裂缝。**
**ChemEdu Agent 让大模型「能教化学」——作业辅导 → 学情诊断 → 学习规划完整闭环。**

</div>

---

## 核心问题

现有大语言模型在化学领域呈现典型的「能说不能画」缺陷：无法将自然语言描述映射为规范的键线式结构图，SMILES 输出错误率高，且完全缺失中文 IUPAC 命名的专项支持。生成后若存在错误，用户必须切换到 ChemDraw 等专业 PC 端软件才能修正。

**ChemVISION 让大模型「能画化学」，更让用户「能改化学」。**

## 核心功能

| 功能 | 描述 | 状态 |
| ---- | ---- | ---- |
| **自然语言 → 结构式生成** | 输入化学名称/分子式/中文俗名，AI 解析生成 SMILES 并渲染 SVG 键线式结构图 | 已实现 |
| **解析模式 / 推测模式** | 解析模式：精确翻译中文名→英文 IUPAC→SMILES；推测模式：根据用途描述生成候选名称 | 已实现 |
| **化学规则校验** | 原子价态、键连接合法性、分子式反向比对，校验不通过自动重生成 | 已实现 |
| **反应方程式语义补全** | 输入不完整反应信息，RAG + LLM 推断完整方程式、反应条件、机理来源 | 已实现 |
| **课本印刷体结构识别** | 拍摄课本结构式，多模态 LLM 识别转换为 SMILES，完整度评分 + 候选补全 | 已实现 |
| **交互式 JSME 编辑器** | 嵌入 JSME 分子编辑器，支持键型修改、原子编辑、消除笔、深色/浅色主题 | 已实现 |
| **SMILES 命名解析** | SMILES → IUPAC 名称 / 中文名双向解析（OPSIN + PubChem + LLM 三路回退） | 已实现 |
| **收藏与历史** | 结构卡片收藏夹、搜索历史管理、错题本 | 已实现 |
| **语音输入** | 语音识别输入化学名称（ASR 服务） | 已实现 |
| **图片识别输入** | 拍照/相册选取图片，OCR + 多模态 LLM 识别化学名称 | 已实现 |
| **ChemEdu Agent** | 作业辅导/学情诊断/学习规划/同类题训练/错因分析/自由对话 6 大教育任务 | 已实现 |
| **学情画像** | 知识点掌握度雷达图 + 统计 + 薄弱点列表(本地 Hive 持久化) | 已实现 |
| **学习记录闭环** | 扫描/练习行为自动写入学习记录,反馈到画像与诊断 | 已实现 |

## 交互流程

```
用户输入 → 意图识别 → 结构推理 → 规则校验 → 渲染输出 → 卡片收藏
  (端侧)     (端侧)     (云端)      (本地)      (本地)      (本地)
```

以「苯甲酸」为例：

1. **输入** — 键入「苯甲酸」、语音输入或拍照识别
2. **结构推理** — 云端 BlueLM API 输出 SMILES: `c1ccc(cc1)C(=O)O`
3. **规则校验** — 本地 SMILES 语法校验（括号平衡、环闭合、价态合理性）
4. **渲染输出** — SVG 键线式图 + 分子式 C₇H₆O₂ + 分子量 122.12
5. **命名解析** — SMILES → IUPAC 名称 / 中文名（PubChem + OPSIN + LLM 回退）
6. **卡片收藏** — 加入收藏夹，支持历史记录回溯

## 技术架构

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter 应用层                         │
│  Riverpod 状态管理 │ InAppWebView │ JSME 编辑器 │ SVG 渲染 │
├─────────────────────────────────────────────────────────┤
│                    服务层                                 │
│  VivoAigcClient │ PubChemClient │ OPSIN │ OcrService    │
├─────────────────────────────────────────────────────────┤
│                    数据层                                 │
│  SharedPreferences │ 结构缓存 │ 收藏夹 │ 知识库 │ 搜索历史 │
├─────────────────────────────────────────────────────────┤
│                    云端 API                               │
│  BlueLM Chat/多模态/Embedding │ PubChem REST │ OPSIN     │
└─────────────────────────────────────────────────────────┘
```

### 技术栈

| 层级 | 技术 |
| ---- | ---- |
| 框架 | Flutter 3.41+ (Dart)，Riverpod 状态管理 |
| AI 底座 | vivo 蓝心大模型（BlueLM）文本/多模态/Embedding |
| 中间表示 | SMILES（解耦 LLM 推理与渲染） |
| 规则校验 | 纯 Dart SMILES 语法校验（括号平衡、环闭合、价态、连通性） |
| 结构渲染 | JSME 编辑器（GWT）+ SmilesDrawer（SVG 键线式图） |
| 命名解析 | PubChem REST API + OPSIN + LLM 三路回退 |
| 化学数据库 | PubChem（结构查询、相似性搜索、属性查询） |
| 反应知识库 | 本地 SharedPreferences + RAG（Embedding 检索 + LLM 补全） |
| 语音识别 | ASR 服务 |
| 图片识别 | OCR 服务 + 多模态 LLM |

## 项目结构

```
lib/
├── config/                  # 应用配置
│   └── app_config.dart
├── models/                  # 数据模型
│   ├── structure_result.dart
│   ├── reaction_completion_result.dart
│   ├── structure_recognition_result.dart
│   └── adapters/           # JSON 序列化适配器
├── providers/               # Riverpod 状态管理
│   ├── structure_controller.dart
│   ├── structure_recognition_controller.dart
│   ├── theme_mode_provider.dart
│   └── ...
├── services/                # 业务服务
│   ├── vivo_aigc_client.dart         # BlueLM API 客户端
│   ├── real_structure_service.dart   # PubChem + OPSIN + LLM 结构服务
│   ├── reaction_completion_service.dart  # 反应方程式补全
│   ├── image_structure_service.dart  # 图像结构识别
│   ├── ocr_service.dart              # OCR 服务
│   ├── favorites_service.dart        # 收藏夹
│   ├── search_history_service.dart   # 搜索历史
│   └── ai_settings_store.dart        # AI 设置持久化
├── theme/                   # 主题与配色
│   ├── app_theme.dart
│   └── app_colors.dart
├── ui/
│   ├── pages/               # 页面
│   │   ├── input_page.dart           # 首页（文本/语音/图片输入）
│   │   ├── loading_page.dart         # 加载动效
│   │   ├── result_page.dart          # 结构卡片结果页
│   │   ├── structure_editor_page.dart # JSME 编辑器页
│   │   ├── reaction_page.dart        # 反应方程式补全页
│   │   ├── structure_recognition_page.dart # 印刷体识别页
│   │   ├── smiles_name_resolve_page.dart   # SMILES 命名解析页
│   │   ├── favorites_page.dart       # 收藏夹
│   │   ├── settings_page.dart        # 设置页
│   │   └── splash_page.dart          # 启动页
│   └── widgets/             # 可复用组件
│       ├── jsme_editor_view_mobile.dart  # JSME 编辑器（移动端）
│       ├── structure_view_mobile.dart    # 结构预览（移动端）
│       ├── voice_input_overlay.dart      # 语音输入浮层
│       ├── glass_panel.dart              # 毛玻璃面板
│       └── ...
└── utils/                   # 工具类
    ├── smiles_validator.dart   # SMILES 语法校验
    └── js_utils.dart           # JS 交互工具

assets/
├── web/                     # Web 渲染资源
│   ├── editor_jsme.html     # JSME 编辑器 HTML
│   ├── editor_jsme.js       # JSME 编辑器桥接脚本（主题/皮肤/SVG 重映射）
│   ├── jsme_sw.js           # Service Worker（GWT 资源加载）
│   └── jsa.css              # JSME 主题样式
├── prompts/                 # LLM Prompt 模板
│   └── image_to_smiles.txt  # 多模态化学结构识别 prompt
├── js/                      # 其他 JS 资源
└── icon.png                 # 应用图标
```

## 快速开始

### 环境要求

- Flutter 3.41+ (Dart SDK)
- Android SDK (API 24+)
- vivo BlueLM API Key（在设置页配置）

### 编译运行

```bash
# 获取依赖
flutter pub get

# 调试模式运行
flutter run

# 编译发布版 APK
flutter build apk --release

# 编译拆分 ABI 版本（推荐）
flutter build apk --split-per-abi
```

**输出位置**：`build/app/outputs/flutter-apk/`

### 安装到手机

```bash
# USB 调试
flutter run

# ADB 安装
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 核心设计决策

### 为什么用 SMILES 作为中间表示？

SMILES 是化学结构的文本表示，解耦了 LLM 推理与图形渲染：

- LLM 只需输出文本，避免直接生成图形的不稳定性
- 规则校验层可对 SMILES 进行语法校验（纯 Dart 实现，无需 RDKit）
- 渲染层可独立优化，支持 JSME 编辑器和 SmilesDrawer 双渲染

### 为什么用 JSME 而非自研编辑器？

JSME 是成熟的开源化学结构编辑器（Java→GWT→JavaScript），提供完整的化学编辑能力（键型、原子、环、基团、消除笔），通过 InAppWebView 嵌入 Flutter 应用，配合自定义 SVG 皮肤重映射实现深色主题适配。

### 多路回退策略

化学名称解析采用三路回退：PubChem 精确查询 → OPSIN IUPAC 解析 → LLM 推理，确保覆盖面最大化。SMILES 命名解析同样采用 PubChem 属性查询 → OPSIN 转换 → LLM 推断的回退链。

## ChemEdu Agent — 化学教育智能体

面向 GOAI 世界人工智能开源大赛「AI+教育」赛道,在原有结构式能力之上构建的教育 Agent 闭环。

### Agent 能力闭环

对应赛题"任务理解 → 多轮交互 → 任务规划 → 工具调用 → 知识增强 → 上下文管理 → 结果交付"七环节:

| 任务类型 | 触发方式 | 工具链路 | 教育价值 |
|---------|---------|---------|---------|
| **作业辅导** | 拍照 | OCSR → PubChem → 知识图谱 → LLM | 分步启发,不直接给答案 |
| **化合物讲解** | 输入名称/SMILES | PubChem → 知识图谱 → LLM | 关联教材章节 |
| **学情诊断** | 自然语言 | 学情画像 → 知识图谱 → LLM | 识别薄弱点 + 改进建议 |
| **学习规划** | 自然语言 | 学情画像 → 知识图谱 → LLM | 生成个性化学习路径 |
| **同类题训练** | 自然语言 | 知识图谱 → LLM | 基于官能团出题 |
| **错因分析** | 拍照 | OCSR → 知识图谱 → LLM | 定位错误官能团 |
| **自由对话** | 自然语言 | LLM | 学习陪伴 |

### Agent 架构

```
┌─────────────────────────────────────────────────────────┐
│  UI 层:Agent 对话主界面 / 学情画像雷达图 / 隐私与合规面板  │
├─────────────────────────────────────────────────────────┤
│  Agent 编排层                                             │
│  TaskPlanner → AgentOrchestrator → ToolRegistry          │
│  AgentContext(@slot.field 数据传递 / 会话历史)             │
├─────────────────────────────────────────────────────────┤
│  工具层                                                   │
│  OcsrTool │ PubChemTool │ KnowledgeBaseTool │ LlmTool    │
├─────────────────────────────────────────────────────────┤
│  数据层(Hive 本地存储)                                    │
│  LearningRecord → LearningProfile → 知识掌握度             │
└─────────────────────────────────────────────────────────┘
```

### 学习记录闭环

```
用户操作                Agent 编排器                    学情画像
─────────────────────────────────────────────────────────────
拍照辅导/homework  →  OCSR→PubChem→知识库→LLM  →  recordScan()
化合物讲解/compound →  PubChem→知识库→LLM        →  recordQuery()
同类题训练/practice →  知识库→LLM                →  recordPractice()
错因分析/error      →  OCSR→知识库→LLM          →  recordPractice(wrong)
                                                        ↓
                                                  画像刷新(refresh)
                                                        ↓
                                  下次 diagnosis/planning 任务读取画像
```

### 知识图谱

预置 31 个化学知识点,覆盖:
- **有机化学**:烷烃/烯烃/炔烃/芳香烃/卤代烃/醇/酚/醚/醛/酮/羧酸/酯/胺/酰胺/硝基/氨基酸/糖/杂环/蛋白质/高分子
- **无机化学**:酸/碱/盐/氧化物/金属/非金属/配合物
- **物理化学**:酸碱理论/氧化还原/化学平衡/电化学

每个知识点关联:教材章节(人教版)、官能团 SMILES 模式、难度等级、前置依赖。

### 教育伦理

- **作业辅导**:严格遵循"不直接给答案",分步启发引导思考
- **AI 生成内容**:每条结果附「安全提示」,标注 AI 生成风险
- **首次使用须知**:弹窗告知 Agent 能力边界与使用规范

### 数据合规

- ✅ 学习记录、画像、收藏全部本地 Hive 存储,不主动上传
- ✅ 仅 OCSR/LLM 调用时传输 SMILES/文本(可换本地模型)
- ✅ 不收集个人身份信息,不进行用户画像分析
- ✅ 用户可随时一键清除全部数据
- ✅ 符合《个人信息保护法》《未成年人保护法》对教育类应用的基本要求

### Agent 提示词

`assets/prompts/` 下 7 套教育专用模板:
- `agent_homework_tutor.txt` — 分步启发式作业辅导
- `agent_compound_explain.txt` — 化合物讲解
- `agent_diagnosis.txt` — 学情诊断报告
- `agent_planning.txt` — 个性化学习规划
- `agent_practice.txt` — 同类题训练
- `agent_error_analysis.txt` — 错因分析
- `agent_chat.txt` — 自由对话

## 目标用户

| 用户群体 | 场景 |
| -------- | ---- |
| 高校化学/化工/药学本科生 | 课程学习、作业预习、命名→结构还原 |
| 有机化学研究生 | 文献阅读、反应路径规划 |
| 高中化学竞赛学生 | 竞赛备考、有机结构式入门 |

## 赛事信息

| 项目 | 内容 |
| ---- | ---- |
| 竞赛 | 第三届（2026）中国高校计算机大赛 AIGC 创新赛 |
| 赛道 | 应用赛道 |
| 技术底座 | vivo 蓝心大模型（BlueLM） |
| 承办单位 | 南开大学 × vivo |
| 作品形态 | Flutter APP（Android 原生运行） |

---

## 部署指南

项目通过 GitHub Actions 自动化构建并发布到多平台,以下是各平台的部署方式。

### CI/CD 流水线

推送到 `main` 分支即触发 [.github/workflows/flutter-build.yml](.github/workflows/flutter-build.yml),自动完成:

1. **版本递增** — 自动 patch +1 并回写 `pubspec.yaml`
2. **多平台构建** — Android APK / Windows / Web 三端并行
3. **Web 部署** — 构建产物自动部署到 GitHub Pages
4. **Release 发布** — APK 与 Windows 包上传至 GitHub Releases

### Web 部署(GitHub Pages)

Web 构建产物自动部署到 GitHub Pages,无需手动操作。构建流程已处理以下微信内置浏览器兼容问题:

- **Service Worker 清理** — [web/index.html](web/index.html) 内联脚本会在首次访问时注销旧 SW 并 reload 一次(用 `sessionStorage` 防死循环)
- **缓存破坏** — 构建时给 `flutter_bootstrap.js` 追加 `?v=<commit-sha>` 版本参数,绕过 HTTP 强缓存
- **HTTP 缓存控制** — `index.html` 设置 `no-cache, no-store, must-revalidate` 响应头

> 首次更新后访问会自动 reload 一次以加载新版本,后续访问稳定。

### 云端 API 代理(Cloudflare Worker)

生产环境的 LLM API 通过 Cloudflare Worker 代理转发,避免暴露 API Key 并解决跨域问题:

- **生产地址**: `https://api.chemvision.qzz.io`(在设置页配置)
- **本地开发**: 可在设置页切换为 `http://localhost:8787`
- 所有云端请求必须使用 **HTTPS**,避免微信内置浏览器的 Mixed Content 错误

### Android 部署

```bash
# 本地构建 Release APK
flutter build apk --release

# 拆分 ABI(体积更小,推荐)
flutter build apk --split-per-abi --release

# 输出位置
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

或从 [GitHub Releases](../../releases) 下载已签名的构建产物。

---

## 调试指南

### 查看日志

```bash
# Flutter 日志
flutter logs

# ADB 过滤应用日志
adb logcat -s flutter
adb logcat --pid=$(adb shell pidof -s com.chemvision.chemvision)
```

### DevTools

```bash
flutter pub global run devtools
# 访问 http://127.0.0.1:9100
```

---

## 路线图

### 已完成 ✅

- **v1.0** — 自然语言 → 结构式生成、规则校验、SVG 渲染
- **v2.0** — 反应方程式补全、印刷体识别、JSME 编辑器、SMILES 命名解析
- **v3.0** — ChemEdu Agent 闭环:作业辅导/学情诊断/学习规划/同类题训练/错因分析/自由对话
- **v3.1** — 学情画像雷达图、学习记录闭环、知识图谱、隐私合规面板

### 进行中 🚧

- **端侧模型集成** — BlueLM 端侧推理,离线可用(已在设置页支持切换)
- **Web 端适配** — GitHub Pages 部署 + 微信兼容性优化

### 规划中 📋

- **知识图谱扩展** — 增加更多教材章节关联与前置依赖路径
- **多人协作** — 教师端学情看板,支持班级维度分析
- **离线优先架构** — OCSR / 命名解析的本地回退方案
- **国际化** — 英文界面与多语言 prompt 模板

---

## 贡献指南

欢迎通过 Issue 或 Pull Request 参与贡献:

1. **Issue** — 报告 Bug、提出功能建议、讨论设计方向
2. **Pull Request** — 修复 Bug、实现新功能、完善文档
3. **Prompt 优化** — 改进 `assets/prompts/` 下的教育专用模板

提交前请确保:

- `flutter analyze` 无 error 级别问题
- 新增功能配套相应的 prompt 模板与 UI 入口
- 涉及数据合规的改动需同步更新 [lib/ui/widgets/compliance/privacy_compliance_panel.dart](lib/ui/widgets/compliance/privacy_compliance_panel.dart)

---

## License

MIT
