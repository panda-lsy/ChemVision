class StructureViewController {
  StructureViewController({
    required this.updateAtomElement,
    this.exportSvg,
  });

  final Future<void> Function(String atomId, String element) updateAtomElement;
  final Future<String?> Function()? exportSvg;
}
