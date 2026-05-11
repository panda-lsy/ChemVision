class StructureViewController {
  StructureViewController({
    required this.updateAtomElement,
    required this.deleteAtom,
    required this.setBondType,
    required this.addGroup,
    required this.undo,
    required this.redo,
    this.exportSvg,
    this.exportPng,
  });

  final Future<void> Function(String atomId, String element) updateAtomElement;
  final Future<void> Function(String atomId) deleteAtom;
  final Future<void> Function(String atomId, int bondType) setBondType;
  final Future<void> Function(String atomId, String groupKey) addGroup;
  final Future<void> Function() undo;
  final Future<void> Function() redo;
  final Future<String?> Function()? exportSvg;
  final Future<String?> Function()? exportPng;
}
