class JsmeEditorController {
  JsmeEditorController({
    required this.setSmiles,
    required this.getSmiles,
  });

  final Future<void> Function(String smiles) setSmiles;
  final Future<String?> Function() getSmiles;
}
