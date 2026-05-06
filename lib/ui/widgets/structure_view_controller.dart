class StructureViewController {
  StructureViewController({required this.updateAtomElement});

  final Future<void> Function(String atomId, String element) updateAtomElement;
}
