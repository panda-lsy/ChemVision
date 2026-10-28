# 应用案例、测试与证据

记录日期：2026-10-22。以下是当日版本的本地执行证据，不能自动证明后续源码变更后的结果；当前移除工作见 [状态记录](13-current-removal-status.md)。没有虚构真实学生、学校部署、用户规模、教育收益或加速百分比。

2026-10-28 的独立候选快照新增 30 项通过、3 项跳过的回归结果，Web/Android 构建和拆包检查也已完成；分析/测试与最终 Android 构建所用树的区别、产物哈希和验证边界见 [移除与验证记录](13-current-removal-status.md)。这不代表真实设备或真实模型服务已经验证。

## 已执行

| 检查 | 命令 | 实际结果与证据 |
| --- | --- | --- |
| 基线静态分析 | `flutter analyze` | 41 info、无 error/warning；默认退出 1，[日志](evidence/analyze-before.txt) |
| 初始 Web release | `flutter build web --release --no-pub` | 成功，编译日志 75.5 秒；仅为一次本机编译时间，[日志](evidence/build-web-before.txt) |
| 缺陷复现 | 新增回归测试、修复前执行 | 24 用例中 6 失败，覆盖错误缓存、无效结构、任务路由、画像丢失和虚假成绩，[日志](evidence/tests-before.txt) |
| 历史修复后基础回归 | `flutter test --no-pub --reporter expanded` | 当时 26 通过，3 个真实网络用例默认跳过；包括编排、失败路径、新结构会话与真实结果组件渲染，[日志](evidence/tests-after.txt) |
| 保留历史提示的分析 | `flutter analyze --no-pub --no-fatal-infos` | 此阶段 41 info，error/warning 仍阻断，[日志](evidence/analyze-after.txt)。后续快照结果另记 |
| 有界源码安全/资源/许可证盘点 | `python tools/competition_audit.py --history --output ...` | 当前跟踪源码与限定 Git 历史扫描无凭据命中，HTML 资源无缺失；本机 161 个 Dart/Flutter 包许可证文件盘点，[JSON](evidence/audit-after.json) |
| 真实公共化学服务 | `flutter test test/live_public_chemistry_test.dart --no-pub --dart-define=LIVE_CHEMISTRY=true --reporter expanded` | 3/3 通过；实际调用 `NameToStructureService`/PubChem，未调用 LLM/OCSR；[日志](evidence/live-public-chemistry.txt)、[样本结果](evidence/live-public-chemistry.json) |

公共服务单次观测：

| 英文输入 | 实测 SMILES | 分子式 | 首次请求耗时 | 重复请求 |
| --- | --- | --- | --- | --- |
| ethanol | `CCO` | C2H6O | 1631 ms | 内存设置缓存命中，毫秒精度显示 0 |
| benzoic acid | `C1=CC=C(C=C1)C(=O)O` | C7H6O2 | 2115 ms | 同上 |
| acetone | `CC(=O)C` | C3H6O | 1657 ms | 同上 |

这是每样本一次的网络观察，无重复统计/置信区间，不是识别准确率或“优化提升”。暖查询 0 ms 只表示计时分辨率下很短，不是零计算成本。测试 SharedPreferences 使用内存实现，不证明真实设备磁盘性能。真实服务用例显式恢复 Flutter test 默认屏蔽的 HTTP；最初测试框架 400 拦截已纠正，不作为上游服务故障证据。

## 截图与复现边界

可执行：

```sh
flutter test test/evidence_widget_test.dart --no-pub --dart-define=CAPTURE_EVIDENCE=true --dart-define=EVIDENCE_FONT=C:/Windows/Fonts/msyh.ttc --reporter expanded
```

在 Windows 使用本机字体渲染后输出 `evidence/agent-result-fixture.png`。截图是**真实 Flutter 结果组件运行、模拟化合物/讲解数据**，图内已注明；不能替代线上 LLM 演示、完整产品截图或用户实测。字体文件不复制进仓库。

为显示 Material 图标，本机执行还带 `--dart-define=EVIDENCE_ICON_FONT=D:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf`；其他机器请改为其 Flutter SDK 路径。截图生成测试日志见 `evidence/widget-screenshot.txt`。

完整浏览器 UI 自动化多次超时，尚未取得真实浏览器端结构编辑/收藏/AI 全流程录屏。不能将构建成功、截图组件或工具桩替换成该项已完成的证据。

## 独立源码快照

为排除他人未提交工作，使用 `git archive HEAD`（626e4a6）并叠加明确列出的本轮文件创建本地 `build/openatom-candidate-20261022/`。覆盖列表与 SHA256 见 [manifest](evidence/candidate-source-manifest.json)。未包含原有 pubspec 改动、器材作图新页与私人合同。该目录仍包含基线跟踪的厂商 SDK，**仅供本地验证，不是授权公开包**。

快照分析、测试、Web 构建最终结果见 `11-change-log.md` 和 `evidence/candidate-*.txt`；存在文件才可引用成功结果。此方式验证的是“HEAD＋明确补丁”，正式提交仍需选定提交、干净检出与远端 CI。

## 待执行的真实案例协议

| 案例 | 输入/动作 | 验收与留证 |
| --- | --- | --- |
| C01 中文解析 | 自写输入“苯甲酸”，配置可用专用模型 | 记录规范化结果、来源、分子式与 SMILES；人工复核，保存模型版本和脱敏日志 |
| C02 编辑与收藏 | 修改结构后保存、加入收藏、重新打开 | 新 SMILES 与重开结构一致；截图保留编辑前后内容，拒绝仅改显示名称冒充结构变化 |
| C03 教学闭环 | 点击“AI 讲解此结构”，确认发送 | 工具步骤与选定 SMILES 一致；有知识点、来源与安全提示；讲解经人工核对 |
| C04 学情建议 | 使用真实查询记录，新会话发送“学情诊断” | 记录数及知识点与本地数据一致，无虚构练习正确率；说明启发式性质 |
| C05 可控失败 | 无效 `C==O`、模型服务不可用、OCSR 无响应 | 失败明确呈现、无伪造结构和成绩，用户可恢复 |
| C06 可选图片 | 自己绘制并有权公开的结构图 | 记录原图、预测 SMILES、人工标准、耗时、模型/端点；不得用教材截图默认替代授权 |

建议扩为 10 个化合物、5 个错误输入，在相同配置下冷暖各记录至少 3 次，报告全部样本与失败。当前只完成上方 3 个英文公共服务样本，其余不得填假结果。

反馈记录表：时间、参与者匿名代号、同意范围、使用任务、原话/观察、复现信息、是否允许公开。暂无已取得许可的真实反馈，不能把模板或开发者自测称为用户访谈。
