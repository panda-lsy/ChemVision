import 'dart:html' as html;

void downloadDataUrl(String dataUrl, String fileName) {
  final anchor = html.AnchorElement()
    ..href = dataUrl
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
