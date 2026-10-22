# 贡献指南

欢迎可复现的缺陷报告、化学知识纠错、测试和文档贡献。提交内容须为本人有权贡献的代码/素材；项目自有代码沿用 [MIT](LICENSE)，第三方文件保留各自许可，不能把厂商 SDK 或教材扫描当作自有资产上传。

1. 在 Issue 说明输入、预期与实际行为、系统/Flutter 版本，提供最小复现；移除 API Key、邮箱和学生信息。漏洞按 [SECURITY.md](SECURITY.md) 处理。
2. 新分支完成一个清晰改动；不要混入他人未提交的工作、版本批量格式化或无关重构。
3. 化学规则、模型路由和持久化修改需有能发现错误行为的测试；模型/OCSR 测试桩须显式标注，不能据此声称准确率。
4. 执行：

   ```sh
   flutter pub get
   flutter analyze --no-fatal-infos
   flutter test --reporter expanded
   python tools/competition_audit.py
   flutter build web --release
   ```

5. PR 写明问题、修改后行为、验证结果、模型/服务配置是否改变、第三方来源及已知限制。新增依赖同时更新锁文件与 [NOTICE](NOTICE)。

维护机制为待执行约定：维护者复核代码与领域正确性后合并；安全、权限、数据删除与许可变更必须单独说明。不在提交中携带密钥、真实学生数据、私人合同或未授权素材。不保证当前已有多维护者团队或响应 SLA。

测试工程用 Flutter 3.41.8 / Dart 3.11.5；既有多平台流水线使用 3.41.9。提交前应在候选版本选定的一致 SDK 上复现。`flutter analyze --no-fatal-infos` 保留历史 info 输出，error/warning 仍阻断。
