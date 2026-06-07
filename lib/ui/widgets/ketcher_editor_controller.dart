import 'dart:async';

class KetcherEditorController {
  KetcherEditorController({
    required this.setMolecule,
    required this.getSmiles,
    required this.getRxn,
    required this.exportSvg,
    required this.exportPng,
    required this.triggerSave,
  });

  final Future<void> Function(String data) setMolecule;
  final Future<String?> Function() getSmiles;
  final Future<String?> Function() getRxn;
  final Future<String?> Function({String? data}) exportSvg;
  final Future<String?> Function({String? data}) exportPng;

  /// 触发 Ketcher 内置的保存/导出对话框
  final void Function() triggerSave;
}
