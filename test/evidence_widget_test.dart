// Actual Flutter component rendering with explicitly labelled synthetic data.
// Optional screenshot: --dart-define=CAPTURE_EVIDENCE=true
// --dart-define=EVIDENCE_FONT=C:/Windows/Fonts/msyh.ttc
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chemvision/models/agent_task.dart';
import 'package:chemvision/theme/app_theme.dart';
import 'package:chemvision/ui/widgets/agent/agent_result_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const capture = bool.fromEnvironment('CAPTURE_EVIDENCE');
  const fontPath = String.fromEnvironment('EVIDENCE_FONT');
  const iconFontPath = String.fromEnvironment('EVIDENCE_ICON_FONT');
  setUpAll(() async {
    if (capture && fontPath.isNotEmpty) {
      final bytes = await File(fontPath).readAsBytes();
      await (FontLoader(
        'EvidenceFont',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    if (capture && iconFontPath.isNotEmpty) {
      final bytes = await File(iconFontPath).readAsBytes();
      await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  testWidgets('真实结果组件展示结构、知识点与安全提示（模拟数据）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    final theme = AppTheme.light();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: capture && fontPath.isNotEmpty
              ? theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'EvidenceFont'),
                )
              : theme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('组件运行截图 · 模拟数据 · 非线上 AI 效果评测'),
                    const SizedBox(height: 20),
                    AgentResultView(
                      result: AgentTaskResult(
                        title: '化合物讲解',
                        summary: '测试用例示例',
                        sections: [
                          AgentResultSection(
                            title: '化合物信息',
                            content: '乙醇 / ethanol\nSMILES: CCO\n分子式: C2H6O',
                            type: ResultSectionType.formula,
                          ),
                          AgentResultSection(
                            title: '知识点',
                            content: '醇与羟基：请结合教材核对。',
                            type: ResultSectionType.text,
                          ),
                          AgentResultSection(
                            title: '教学提示（测试文本）',
                            content: '观察结构中的羟基，尝试说明其与性质的关系。本内容来自测试夹具，没有调用模型。',
                            type: ResultSectionType.text,
                          ),
                        ],
                        safetyNotice: 'AI 生成内容可能存在错误，不能替代教材与教师指导。',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('化合物讲解'), findsOneWidget);
    expect(find.textContaining('AI 生成内容可能存在错误'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (capture) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final rendered = await boundary.toImage(pixelRatio: 1);
        final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/competitions/openatom-2026/evidence/agent-result-fixture.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        rendered.dispose();
      });
    }
  });
}
