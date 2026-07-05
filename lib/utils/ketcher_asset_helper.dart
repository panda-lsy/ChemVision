import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class KetcherAssetHelper {
  static String? _cachedPath;

  /// Extract ketcher assets to temp dir and return index.html path
  static Future<String> prepare() async {
    if (_cachedPath != null) return _cachedPath!;
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/ketcher');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _extractManifest(dir);
    }
    _cachedPath = '${dir.path}/index.html';
    return _cachedPath!;
  }

  static Future<void> _extractManifest(Directory dir) async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      for (final line in manifest.split('\n')) {
        final parts = line.split(':');
        if (parts.length < 2) continue;
        final key = parts[0].trim().replaceAll('"', '');
        if (!key.startsWith('assets/web/ketcher/')) continue;
        final rel = key.substring('assets/web/ketcher/'.length);
        final file = File('${dir.path}/$rel');
        await file.parent.create(recursive: true);
        final data = await rootBundle.load(key);
        await file.writeAsBytes(data.buffer.asUint8List());
      }
    } catch (_) {
      // Fallback: try copying from build output
      final src = Directory('data/flutter_assets/assets/web/ketcher');
      if (await src.exists()) {
        await _copyDir(src, dir);
      }
    }
  }

  static Future<void> _copyDir(Directory src, Directory dst) async {
    await for (final e in src.list(recursive: true)) {
      if (e is File) {
        final rel = e.path.substring(src.path.length + 1);
        final target = File('${dst.path}/$rel');
        await target.parent.create(recursive: true);
        await e.copy(target.path);
      }
    }
  }
}
