import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<void> saveTextToFile({
  required String fileName,
  required String text,
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: '保存个人知识库',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (path == null || path.isEmpty) {
    return;
  }
  await File(path).writeAsString(text);
}