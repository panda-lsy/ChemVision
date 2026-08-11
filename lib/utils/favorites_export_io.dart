import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 收藏数据导出（桌面/移动端）
///
/// 写入临时文件后调用系统分享。
Future<void> exportFavorites(String json, BuildContext context) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/chemvision_favorites_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'ChemEdu 收藏数据',
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }
}

/// 收藏数据导入（桌面/移动端）
///
/// 使用 FilePicker 读取 JSON 文件内容。
Future<String?> pickFavoritesFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (result == null || result.files.isEmpty) return null;

  final filePath = result.files.first.path;
  if (filePath == null) return null;

  final file = File(filePath);
  return file.readAsString();
}
