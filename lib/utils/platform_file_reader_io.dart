import 'dart:io';
import 'dart:typed_data';

/// 读取文件字节（桌面/移动端）
Future<Uint8List> readFileBytes(String path) async {
  final file = File(path);
  if (await file.exists()) {
    return file.readAsBytes();
  }
  throw FileSystemException('文件不存在', path);
}
