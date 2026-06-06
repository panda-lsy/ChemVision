import 'dart:typed_data';

/// 读取文件字节（Web 端 stub）
///
/// Web 端 ASR 不使用文件系统读取音频，此实现保证编译通过。
Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError('Web 平台不支持文件系统读取');
}
