import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider<Object>? localAvatarImageProvider(String path) {
  final uri = Uri.tryParse(path);
  final filePath = uri?.scheme == 'file' ? uri!.toFilePath() : path;
  return FileImage(File(filePath));
}
