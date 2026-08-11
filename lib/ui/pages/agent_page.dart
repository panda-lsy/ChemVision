/// Agent 对话主页面 — 任务入口 + 工作流进度展示 + 结果展示
///
/// 对应赛题 Agent 应用闭环的可视化界面:
/// - 顶部:任务输入框(文本/拍照) + 快捷入口
/// - 中部:任务步骤进度卡片(实时更新)
/// - 底部:结果展示(分章节 + 建议操作 + 安全提示)
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/agent_session_record.dart';
import '../../models/agent_task.dart';
import '../../models/error_book_item.dart';
import '../../providers/agent_provider.dart';
import '../../providers/error_book_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/agent/agent_result_view.dart';
import '../widgets/agent/agent_step_card.dart';
import '../widgets/agent/agent_usage_notice_dialog.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import 'learning_profile_page.dart';

class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});

  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends ConsumerState<AgentPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 已选图片(作业辅导)
  String? _attachedDataUri;

  @override
  void initState() {
    super.initState();
    // 首次进入时展示使用须知
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAgentUsageNoticeIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.navy : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '选择图片来源',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.camera_alt,
                      color: isDark ? AppColors.aqua : AppColors.dayBlueAccent,
                    ),
                    title: const Text('拍照'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.photo_library,
                      color: isDark ? AppColors.aqua : AppColors.dayBlueAccent,
                    ),
                    title: const Text('从相册选择'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Image = await compute(_encodeBytes, bytes);
      final mimeType = _detectMimeType(bytes);
      final dataUri = 'data:$mimeType;base64,$base64Image';

      if (mounted) {
        setState(() => _attachedDataUri = dataUri);
        // 自动填充提示词
        if (_inputController.text.trim().isEmpty) {
          _inputController.text = '请帮我辅导这道化学题';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片选择失败: $e')),
        );
      }
    }
  }

  void _submit() {
    final text = _inputController.text.trim();
    if (text.isEmpty && _attachedDataUri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入问题或选择图片')),
      );
      return;
    }
    if (ref.read(agentControllerProvider).isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前任务还在执行,请稍候或取消')),
      );
      return;
    }

    ref.read(agentControllerProvider.notifier).runTask(
          userInput: text.isEmpty ? '请辅导这道化学题' : text,
          dataUri: _attachedDataUri,
        );

    // 提交后清空输入(保留以便追问)
    _inputController.clear();
    setState(() => _attachedDataUri = null);

    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _cancel() {
    ref.read(agentControllerProvider.notifier).cancelTask();
  }

  void _clearCurrent() {
    ref.read(agentControllerProvider.notifier).clearCurrent();
  }

  /// 快捷入口:学情诊断
  void _quickDiagnosis() {
    if (ref.read(agentControllerProvider).isRunning) return;
    _inputController.text = '请基于我的学习记录生成学情诊断报告';
    _submit();
  }

  /// 打开学情画像详情页(雷达图 + 统计)
  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LearningProfilePage(),
      ),
    );
  }

  /// 快捷入口:学习规划
  void _quickPlanning() {
    if (ref.read(agentControllerProvider).isRunning) return;
    _inputController.text = '请帮我制定接下来一个月的化学学习规划';
    _submit();
  }

  /// 处理"建议下一步"操作
  void _handleSuggestedAction(SuggestedAction action, AgentTask sourceTask) {
    switch (action.actionType) {
      case SuggestedActionType.practice:
        _startPractice(action, sourceTask);
        break;
      case SuggestedActionType.diagnose:
        _quickDiagnosis();
        break;
      case SuggestedActionType.saveFavorite:
        _saveToErrorBook(sourceTask, action);
        break;
      case SuggestedActionType.planLearning:
        _quickPlanning();
        break;
      case SuggestedActionType.review:
        _startReview(action, sourceTask);
        break;
      case SuggestedActionType.explainMore:
        // 聚焦输入框,让用户继续追问
        FocusScope.of(context).requestFocus();
        break;
    }
  }

  /// 生成同类练习题
  void _startPractice(SuggestedAction action, AgentTask sourceTask) {
    if (ref.read(agentControllerProvider).isRunning) return;
    final kpIds = (action.payload?['knowledgePointIds'] as List?)?.cast<String>() ?? [];
    final compoundName = sourceTask.context['inputName'] as String? ?? '';
    final prompt = kpIds.isNotEmpty
        ? '请基于知识点 ${kpIds.join(", ")} 生成 3 道同类练习题(含答案解析)'
        : compoundName.isNotEmpty
            ? '请围绕"$compoundName"生成 3 道练习题(含答案解析)'
            : '请生成 3 道高中化学练习题(含答案解析)';
    _inputController.text = prompt;
    _submit();
  }

  /// 开始薄弱点复习
  void _startReview(SuggestedAction action, AgentTask sourceTask) {
    if (ref.read(agentControllerProvider).isRunning) return;
    final kpIds = (action.payload?['knowledgePointIds'] as List?)?.cast<String>() ?? [];
    final prompt = kpIds.isNotEmpty
        ? '请帮我复习知识点 ${kpIds.join(", ")},给出核心概念和典型例题'
        : '请帮我复习本次辅导涉及的化学知识点';
    _inputController.text = prompt;
    _submit();
  }

  /// 收藏到错题本
  Future<void> _saveToErrorBook(AgentTask task, SuggestedAction action) async {
    final result = task.result;
    if (result == null) return;

    final kpIds = (action.payload?['knowledgePointIds'] as List?)?.cast<String>() ??
        result.relatedKnowledgePoints;

    // 从任务上下文提取化合物信息
    final smiles = task.context['inputSmiles'] as String? ?? '';
    final compoundName = task.context['inputName'] as String? ?? '';

    final item = ErrorBookItem(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      title: result.title,
      content: result.summary,
      createdAt: DateTime.now(),
      knowledgePointIds: kpIds,
      smiles: smiles,
      compoundName: compoundName,
      sourceSessionId: task.id,
    );

    await ref.read(errorBookControllerProvider.notifier).add(item);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已收藏到错题本'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _detectMimeType(List<int> bytes) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x52 && bytes[1] == 0x49) return 'image/webp';
    }
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final task = state.currentTask;

    return AppScaffold(
      scaffoldKey: _scaffoldKey,
      padding: EdgeInsets.zero,
      drawer: _buildConversationDrawer(isDark),
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: state.error != null
                ? _buildErrorView(state.error!, isDark)
                : (task == null
                    ? _buildEmptyView(isDark)
                    : _buildTaskView(task, state.isRunning, isDark)),
          ),
          _buildInputBar(isDark, state.isRunning),
        ],
      ),
    );
  }

  /// 历史对话侧边栏(Drawer)
  Widget _buildConversationDrawer(bool isDark) {
    final state = ref.watch(agentControllerProvider);
    final sessions = state.sessions;

    return Drawer(
      backgroundColor: isDark ? AppColors.navyDeep : AppColors.dayBackground,
      width: 320,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 侧边栏标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '历史对话',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.dayTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    color: isDark
                        ? AppColors.textMuted
                        : AppColors.dayTextMuted,
                  ),
                ],
              ),
            ),
            Divider(
              color: isDark
                  ? Colors.white12
                  : AppColors.dayBluePrimary.withValues(alpha: 0.08),
            ),
            // 会话列表
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 40,
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.dayTextMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '暂无历史对话',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.dayTextMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isActive =
                            state.activeSessionId == session.id;
                        final isRunning = state.isRunning && isActive;
                        return _DrawerSessionCard(
                          session: session,
                          isDark: isDark,
                          isActive: isActive,
                          isRunning: isRunning,
                          onTap: () {
                            ref
                                .read(agentControllerProvider.notifier)
                                .resumeSession(session);
                            Navigator.of(context).pop();
                          },
                          onDelete: () => ref
                              .read(agentControllerProvider.notifier)
                              .deleteSession(session.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final state = ref.watch(agentControllerProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.menu,
              color: isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: '历史对话',
          ),
          const SizedBox(width: 4),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.aqua, AppColors.lime]
                    : [AppColors.dayBluePrimary, AppColors.dayBlueAccent],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ChemEdu Agent',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.dayTextPrimary,
                  ),
                ),
                Text(
                  state.hasActiveSession ? '对话进行中' : '化学学习智能助手',
                  style: TextStyle(
                    fontSize: 12,
                    color: state.hasActiveSession
                        ? (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                        : (isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted),
                  ),
                ),
              ],
            ),
          ),
          if (state.currentTask != null)
            TextButton.icon(
              onPressed: _clearCurrent,
              icon: Icon(
                Icons.add,
                size: 16,
                color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
              ),
              label: Text(
                '新对话',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero 卡片
          GlassPanel(
            padding: const EdgeInsets.all(20),
            radius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.school,
                  size: 32,
                  color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                ),
                const SizedBox(height: 12),
                Text(
                  '面向化学的个性化学习 Agent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.dayTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '支持作业辅导、化合物讲解、学情诊断、学习规划、错因分析五大能力,基于化学知识图谱实现个性化教学。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.dayTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 快捷入口
          Text(
            '快捷入口',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _QuickActionGrid(
            isDark: isDark,
            actions: [
              _QuickAction(
                icon: Icons.camera_alt,
                label: '拍照辅导',
                description: '作业拍照 → 分步启发',
                onTap: _pickImage,
              ),
              _QuickAction(
                icon: Icons.radar,
                label: '学情画像',
                description: '雷达图查看掌握度分布',
                onTap: _openProfile,
              ),
              _QuickAction(
                icon: Icons.insights_outlined,
                label: 'AI 学情诊断',
                description: '生成诊断报告与改进建议',
                onTap: _quickDiagnosis,
              ),
              _QuickAction(
                icon: Icons.route_outlined,
                label: '学习规划',
                description: '生成个性化学习路径',
                onTap: _quickPlanning,
              ),
              _QuickAction(
                icon: Icons.menu_book,
                label: '化合物讲解',
                description: '输入名称或 SMILES 查询',
                onTap: () {
                  _inputController.text = '请讲解乙醇的结构和性质';
                  _submit();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 使用提示
          GlassPanel(
            padding: const EdgeInsets.all(14),
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 16,
                      color: isDark ? AppColors.amber : const Color(0xFFE07B00),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '使用提示',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.dayTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• 拍照辅导:拍下作业,Agent 会分步启发而非直接给答案\n'
                  '• 化合物讲解:输入名称(如"乙醇")或 SMILES\n'
                  '• 学情诊断:基于你的扫描/练习记录生成报告\n'
                  '• 自由提问:任何化学问题都可以直接输入',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.dayTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskView(AgentTask task, bool isRunning, bool isDark) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        // 任务类型徽章 + 进度
        _TaskHeader(task: task, isDark: isDark),
        const SizedBox(height: 12),

        // 步骤进度卡片
        Text(
          '执行进度 (${task.completedStepCount}/${task.steps.length})',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: task.steps.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AgentStepCard(
              step: task.steps[index],
              index: index,
              total: task.steps.length,
            ),
          ),
        ),

        // 错误状态
        if (task.status == AgentTaskStatus.failed && task.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFC62828)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.error!,
                    style: const TextStyle(
                      color: Color(0xFFC62828),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 结果展示
        if (task.result != null &&
            task.status == AgentTaskStatus.completed) ...[
          const SizedBox(height: 16),
          Text(
            '执行结果',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          AgentResultView(
            result: task.result!,
            onAction: (action) => _handleSuggestedAction(action, task),
          ),
        ],

        // 新对话按钮(任务完成后显示)
        if (task.status == AgentTaskStatus.completed ||
            task.status == AgentTaskStatus.failed ||
            task.status == AgentTaskStatus.cancelled) ...[
          const SizedBox(height: 16),
          _buildNewChatButton(isDark),
        ],
      ],
    );
  }

  /// "开始新对话"按钮 — 清空当前任务,回到空视图
  Widget _buildNewChatButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _clearCurrent,
        icon: Icon(
          Icons.add_circle_outline,
          size: 18,
          color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
        ),
        label: Text(
          '开始新对话',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                .withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.dayTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _clearCurrent,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark, bool isRunning) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyDeep : AppColors.daySurface,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : const Color(0x113D77DE),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 图片附件预览
            if (_attachedDataUri != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.glass : AppColors.dayGlass,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '已选择图片(将进入作业辅导)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          setState(() => _attachedDataUri = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    color: isDark
                        ? AppColors.aqua
                        : AppColors.dayBlueAccent,
                  ),
                  onPressed: isRunning ? null : _pickImage,
                  tooltip: '拍照辅导',
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !isRunning,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: ref.watch(agentControllerProvider
                              .select((s) => s.hasActiveSession))
                          ? '继续追问...'
                          : '输入问题,如"讲解乙醇的性质"',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.glass
                          : AppColors.dayBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.dayTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isRunning)
                  IconButton(
                    icon: Icon(
                      Icons.stop_circle_outlined,
                      color: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
                    ),
                    onPressed: _cancel,
                    tooltip: '取消任务',
                  )
                else
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.aqua, AppColors.lime]
                              : [AppColors.dayBluePrimary, AppColors.dayBlueAccent],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    onPressed: _submit,
                    tooltip: '发送',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 任务头部 — 类型徽章 + 总进度条
class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.task, required this.isDark});

  final AgentTask task;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeVisual = _TaskTypeVisual.fromType(task.type);
    final progressPercent = (task.progress * 100).round();

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeVisual.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeVisual.icon, size: 14, color: typeVisual.color),
                    const SizedBox(width: 4),
                    Text(
                      typeVisual.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: typeVisual.color,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _StatusBadge(status: task.status, isDark: isDark),
            ],
          ),
          const SizedBox(height: 10),
          if (task.userInput.isNotEmpty)
            Text(
              task.userInput,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.dayTextSecondary,
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 8),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.progress,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white12
                  : const Color(0x113D77DE),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.aqua : AppColors.dayBluePrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$progressPercent%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isDark});

  final AgentTaskStatus status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final visual = _statusVisual(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: visual.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        visual.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: visual.color,
        ),
      ),
    );
  }
}

({String label, Color color}) _statusVisual(AgentTaskStatus status) {
  switch (status) {
    case AgentTaskStatus.pending:
      return (label: '等待', color: const Color(0xFF9E9E9E));
    case AgentTaskStatus.planning:
      return (label: '规划中', color: const Color(0xFF7986CB));
    case AgentTaskStatus.executing:
      return (label: '执行中', color: const Color(0xFF29B6F6));
    case AgentTaskStatus.awaitingUser:
      return (label: '等待用户', color: const Color(0xFFFFA726));
    case AgentTaskStatus.completed:
      return (label: '已完成', color: const Color(0xFF66BB6A));
    case AgentTaskStatus.failed:
      return (label: '失败', color: const Color(0xFFEF5350));
    case AgentTaskStatus.cancelled:
      return (label: '已取消', color: const Color(0xFF9E9E9E));
  }
}

class _TaskTypeVisual {
  const _TaskTypeVisual({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  factory _TaskTypeVisual.fromType(AgentTaskType type) {
    switch (type) {
      case AgentTaskType.homeworkTutor:
        return const _TaskTypeVisual(
          icon: Icons.school,
          label: '作业辅导',
          color: Color(0xFF7986CB),
        );
      case AgentTaskType.compoundExplain:
        return const _TaskTypeVisual(
          icon: Icons.science,
          label: '化合物讲解',
          color: Color(0xFF26A69A),
        );
      case AgentTaskType.diagnosis:
        return const _TaskTypeVisual(
          icon: Icons.insights,
          label: '学情诊断',
          color: Color(0xFFFFA726),
        );
      case AgentTaskType.planning:
        return const _TaskTypeVisual(
          icon: Icons.route,
          label: '学习规划',
          color: Color(0xFF26C6DA),
        );
      case AgentTaskType.practice:
        return const _TaskTypeVisual(
          icon: Icons.quiz,
          label: '同类题训练',
          color: Color(0xFFEC407A),
        );
      case AgentTaskType.errorAnalysis:
        return const _TaskTypeVisual(
          icon: Icons.error_outline,
          label: '错因分析',
          color: Color(0xFFEF5350),
        );
      case AgentTaskType.chat:
        return const _TaskTypeVisual(
          icon: Icons.chat,
          label: '自由对话',
          color: Color(0xFF66BB6A),
        );
    }
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.isDark,
    required this.actions,
  });

  final bool isDark;
  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: actions.map((a) => _QuickActionCard(action: a, isDark: isDark)).toList(),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.isDark});

  final _QuickAction action;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      radius: 14,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                action.icon,
                size: 18,
                color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.dayTextPrimary,
                    ),
                  ),
                  Text(
                    action.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.dayTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 侧边栏会话卡片 — 支持高亮活跃会话和"..."加载动画
class _DrawerSessionCard extends StatelessWidget {
  const _DrawerSessionCard({
    required this.session,
    required this.isDark,
    required this.isActive,
    required this.isRunning,
    required this.onTap,
    required this.onDelete,
  });

  final AgentSessionRecord session;
  final bool isDark;
  final bool isActive;
  final bool isRunning;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(session.type, isDark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive
            ? (isDark
                ? AppColors.aqua.withValues(alpha: 0.08)
                : AppColors.dayBluePrimary.withValues(alpha: 0.06))
            : (isDark
                ? AppColors.glass
                : AppColors.dayGlass),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        session.typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (session.status == AgentTaskStatus.failed)
                      Text(
                        '· 失败',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFFE57373)
                              : const Color(0xFFC62828),
                        ),
                      )
                    else if (session.status == AgentTaskStatus.cancelled)
                      Text(
                        '· 已取消',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted,
                        ),
                      ),
                    const Spacer(),
                    if (isRunning)
                      const _TypingDots()
                    else
                      Text(
                        _formatCardTime(session.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted,
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 14,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                      ),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      tooltip: '删除',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  session.userInput,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.dayTextPrimary,
                  ),
                ),
                if (!isRunning && session.preview.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    session.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.dayTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCardTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}

/// "..." 动态加载动画(三个点循环闪烁)
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.aqua : AppColors.dayBluePrimary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value * 3 - i) % 1.0;
            final opacity = t < 0.5 ? t * 2 : (1 - t) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3 + opacity * 0.7),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

String _encodeBytes(Uint8List bytes) => base64Encode(bytes);

Color _typeColor(AgentTaskType type, bool isDark) {
  switch (type) {
    case AgentTaskType.homeworkTutor:
      return isDark ? const Color(0xFF80DEEA) : const Color(0xFF0288D1);
    case AgentTaskType.compoundExplain:
      return isDark ? AppColors.lime : const Color(0xFF2E7D32);
    case AgentTaskType.diagnosis:
      return isDark ? AppColors.amber : const Color(0xFFE65100);
    case AgentTaskType.planning:
      return isDark ? AppColors.aqua : AppColors.dayBlueAccent;
    case AgentTaskType.practice:
      return isDark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A);
    case AgentTaskType.errorAnalysis:
      return isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828);
    case AgentTaskType.chat:
      return isDark ? AppColors.textSecondary : AppColors.dayTextSecondary;
  }
}
