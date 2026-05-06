import 'package:dio/dio.dart';

import '../config/app_config.dart';

class NameResolutionResult {
  final String canonicalSmiles;
  final String? source;
  final String? molecularFormula;
  final double? molecularWeight;
  final String? resolvedName;

  const NameResolutionResult({
    required this.canonicalSmiles,
    this.source,
    this.molecularFormula,
    this.molecularWeight,
    this.resolvedName,
  });
}

class NameResolverClient {
  NameResolverClient({Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? AppConfig.nameResolverBaseUrl;

  final Dio _dio;
  final String _baseUrl;

  Future<NameResolutionResult> resolve(String iupacName) async {
    final response = await _dio.post(
      _normalizeBaseUrl(_baseUrl) + '/resolve_smiles',
      data: {
        'iupac_name': iupacName,
      },
      options: Options(validateStatus: (_) => true),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode != 200) {
      throw Exception('HTTP $statusCode: ${response.data}');
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final status = data['status'];
      if (status != 'ok') {
        final error = data['error'] ?? '解析失败';
        throw Exception('$error');
      }

      final canonicalSmiles = data['canonical_smiles'];
      if (canonicalSmiles is! String || canonicalSmiles.trim().isEmpty) {
        throw Exception('解析结果缺少 SMILES');
      }

      return NameResolutionResult(
        canonicalSmiles: canonicalSmiles.trim(),
        source: _asString(data['source']),
        molecularFormula: _asString(data['molecular_formula']),
        molecularWeight: _asDouble(data['molecular_weight']),
        resolvedName: _asString(data['iupac_name']),
      );
    }

    throw Exception('解析失败');
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
