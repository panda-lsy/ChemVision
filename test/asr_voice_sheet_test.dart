import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chemvision/providers/asr_provider.dart';
import 'package:chemvision/ui/widgets/voice_input_overlay.dart';
import 'asr_controller_test.dart' show FakeSpeechBackend;

void main() {
  testWidgets('手动完成语音输入只关闭弹窗一次，并返回最终识别文字', (tester) async {
    final backend = FakeSpeechBackend();
    String? returned;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asrControllerProvider.overrideWith(
            (ref) => AsrController(backend: backend),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  returned = await showVoiceInputOverlay(context, ref);
                },
                child: const Text('打开语音'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开语音'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('完成'), findsOneWidget);
    backend.result('苯', false);
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pump();
    backend.result('苯甲酸', true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(returned, '苯甲酸');
    expect(find.text('打开语音'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
