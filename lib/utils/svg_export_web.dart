import 'dart:convert';
import 'dart:html' as html;

/// Web 端 SVG 导出（Blob + AnchorElement 触发浏览器下载）
Future<void> downloadSvg(String svgString, String filename) async {
  final bytes = utf8.encode(svgString);
  final blob = html.Blob([bytes], 'image/svg+xml');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Web 端 data URL 下载（用于 PNG 等 base64 数据）
Future<void> downloadDataUrl(String dataUrl, String filename) async {
  html.AnchorElement(href: dataUrl)
    ..setAttribute('download', filename)
    ..click();
}
