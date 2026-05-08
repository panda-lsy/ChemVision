class StructureViewController {
  StructureViewController({
    required this.updateAtomElement,
    this.exportSvg,
    this.exportPng,
  });

  final Future<void> Function(String atomId, String element) updateAtomElement;
  final Future<String?> Function()? exportSvg;
  final Future<String?> Function()? exportPng;
}
