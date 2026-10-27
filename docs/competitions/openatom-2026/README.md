# ChemVision · 开放原子 2026 参赛工作包

核验日期：2026-10-22（北京时间）。目标冻结日：10-29。状态：**本地候选改造与材料草稿，尚未满足最终提交条件**。

这是基于真实工作区的审计与交付记录，不是报名成功证明或教学效果认证。不得将测试桩结果当作线上 AI/OCSR 效果。

| 材料 | 用途 |
| --- | --- |
| [赛事核验](00-official-rules.md) | 资格、截止、材料、官方信息冲突 |
| [仓库审计](01-audit.md) | 初始状态、能力分级、评审映射、P0/P1/P2 |
| [报名简介](02-project-summary.md) | 可粘贴的短介绍，主体信息待补 |
| [技术报告](03-technical-report.md) | 技术路线、真实创新与局限 |
| [架构与接口](04-architecture.md) | 模块、数据流、AI 调用和部署边界 |
| [差异比较](05-comparison.md) | 与组件和通用助手的可验证区别 |
| [应用与证据](06-evidence.md) | 真实命令、结果、截图边界及待执行案例 |
| [演示脚本](07-demo-script.md) | 约三分钟建议，不冒充官方限时 |
| [答辩大纲](08-presentation-outline.md) | 按四维度组织 |
| [治理与维护](09-governance-roadmap.md) | 许可证、维护机制、后续计划 |
| [提交清单](10-submission-checklist.md) | 内部验收、报名与邮件人工操作 |
| [变更记录](11-change-log.md) | 本轮修改、验证、遗留风险 |
| [BlueLM 二次筛查](12-bluelm-rescreen-2026-10-27.md) | 2026-10-27 的源码、公开仓库、安装包及许可筛查 |

所有证据位于 [evidence/](evidence/)。基线提交 `626e4a6`，分支 `competition/openatom-2026`。工作区原有未提交修改另见 `evidence/initial-worktree.txt`；它们不代表本轮创建，也不能假定已被 Git 跟踪。

另有 [15 页作品说明 PDF 审阅稿](chemvision-openatom-2026-review.pdf)，已渲染检查；主体、授权和真实演示待补，尚非正式提交文件。可用 `tools/build_openatom_review_pdf.py` 从文档重新生成。

禁止直接把整个工作区压缩上传：根目录合同、承诺书、`doc/`、`outputs/`、密钥配置及未授权素材不属于默认提交物。仓库公开、推送、报名和发邮件均需用户另行授权。
