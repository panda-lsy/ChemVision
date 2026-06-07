import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 移动端/桌面端 SVG 导出
Future<void> downloadSvg(String svgString, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(svgString);
  await Share.shareXFiles([XFile(file.path)], text: 'ChemVISION 结构式 SVG');
}

/// 移动端/桌面端 data URL 下载（用于 PNG 等 base64 数据）
Future<void> downloadDataUrl(String dataUrl, String filename) async {
  // 从 data:image/png;base64,... 中提取 base64 数据
  final base64Data = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
  final bytes = base64Decode(base64Data);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], text: 'ChemVISION 反应方程式');
}
