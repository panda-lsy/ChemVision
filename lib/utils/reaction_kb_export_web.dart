// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';

import 'dart:html' as html;

Future<void> saveTextToFile({
  required String fileName,
  required String text,
}) async {
  final bytes = utf8.encode(text);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}