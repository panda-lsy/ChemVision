import 'dart:async';

/// Ketcher 编辑器控制器
///
/// 封装与 Ketcher iframe 的通信接口。
class KetcherEditorController {
  KetcherEditorController({
    required this.setMolecule,
    required this.getSmiles,
    required this.getRxn,
    required this.exportSvg,
    required this.exportPng,
  });

  /// 设置分子（SMILES / MOL / RXN 格式）
  final Future<void> Function(String data) setMolecule;

  /// 获取当前分子的 SMILES
  final Future<String?> Function() getSmiles;

  /// 获取当前反应的 RXN 格式数据
  final Future<String?> Function() getRxn;

  /// 导出 SVG 字符串
  final Future<String?> Function({String? data}) exportSvg;

  /// 导出 PNG data URL
  final Future<String?> Function({String? data}) exportPng;
}
