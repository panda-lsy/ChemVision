/// 对话消息 Markdown 渲染组件
///
/// - 支持 GitHub-flavored Markdown(标题/列表/代码块/粗体/链接等)
/// - 支持 mhchem 风格的化学公式预处理:`$\ce{C_{2}H_{6}O}$` → `C₂H₆O`
/// - 支持 LaTeX 上下标预处理:`$x^2$` → `x²`、`$v_1$` → `v₁`
///
/// 渲染策略:把 `$...$` / `$$...$$` 内的内容用 Unicode 上下标替换,
/// 再交给 flutter_markdown 渲染外层 Markdown。这样既能展示化学公式,
/// 又能保留 Markdown 排版能力,且不引入重型 LaTeX 库。
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as markdown;

import '../../../theme/app_colors.dart';

/// 上下标 Unicode 字符表
const _subscriptDigits = '₀₁₂₃₄₅₆₇₈₉';
const _superscriptDigits = '⁰¹²³⁴⁵⁶⁷⁸⁹';
const _subscriptLetters = {
  'a': 'ₐ', 'e': 'ₑ', 'h': 'ₕ', 'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ', 'l': 'ₗ',
  'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ', 'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ',
  'u': 'ᵤ', 'v': 'ᵥ', 'x': 'ₓ',
  '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
};
const _superscriptLetters = {
  'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ', 'f': 'ᶠ', 'g': 'ᵍ',
  'h': 'ʰ', 'i': 'ⁱ', 'j': 'ʲ', 'k': 'ᵏ', 'l': 'ˡ', 'm': 'ᵐ', 'n': 'ⁿ',
  'o': 'ᵒ', 'p': 'ᵖ', 'r': 'ʳ', 's': 'ˢ', 't': 'ᵗ', 'u': 'ᵘ', 'v': 'ᵛ',
  'w': 'ʷ', 'x': 'ˣ', 'y': 'ʸ', 'z': 'ᶻ',
  '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
};

/// 把 `_{...}` / `^{...}` / `_x` / `^x` 转为 Unicode 上下标
String _convertSubSup(String raw) {
  final buf = StringBuffer();
  var i = 0;
  while (i < raw.length) {
    final ch = raw[i];
    if ((ch == '_' || ch == '^') && i + 1 < raw.length) {
      final map = ch == '_' ? _subscriptLetters : _superscriptLetters;
      final digits = ch == '_' ? _subscriptDigits : _superscriptDigits;
      // 形式1: _{...} 或 ^{...}
      if (raw[i + 1] == '{') {
        final end = raw.indexOf('}', i + 2);
        if (end == -1) {
          buf.write(ch);
          i++;
          continue;
        }
        final inner = raw.substring(i + 2, end);
        buf.write(_convertInner(inner, map, digits));
        i = end + 1;
        continue;
      }
      // 形式2: _x 或 ^x (单字符)
      final next = raw[i + 1];
      final conv = _convertSingle(next, map, digits);
      if (conv != null) {
        buf.write(conv);
        i += 2;
        continue;
      }
      buf.write(ch);
      i++;
      continue;
    }
    buf.write(ch);
    i++;
  }
  return buf.toString();
}

String _convertInner(String inner, Map<String, String> map, String digits) {
  final buf = StringBuffer();
  for (final c in inner.split('')) {
    final conv = _convertSingle(c, map, digits);
    buf.write(conv ?? c);
  }
  return buf.toString();
}

String? _convertSingle(String c, Map<String, String> map, String digits) {
  if (c.length != 1) return null;
  final code = c.codeUnitAt(0);
  if (code >= 0x30 && code <= 0x39) {
    // 数字 0-9
    return digits[code - 0x30];
  }
  final lower = c.toLowerCase();
  return map[lower];
}

/// 处理 `\ce{...}` 化学公式:去掉 `\ce` 前缀和 `{}`,保留内部文本并转换上下标
String _convertCe(String ceBody) {
  // 去掉化学公式中的多余空格和 → 等符号的处理
  final cleaned = ceBody.replaceAll(' ', '');
  return _convertSubSup(cleaned);
}

/// 预处理 Markdown 文本中的数学/化学公式
///
/// 支持:
/// - `$\ce{...}$` 化学公式
/// - `$...$` 行内数学(上下标转换)
/// - `$$...$$` 块级数学
String preprocessMarkdown(String input) {
  if (!input.contains('\$') && !input.contains(r'\ce')) {
    return input;
  }
  var result = input;

  // 1. 处理 `$$...$$` 块级公式
  final blockPattern = RegExp(r'\$\$([^\$]+?)\$\$');
  result = result.replaceAllMapped(blockPattern, (m) {
    var inner = m.group(1)!;
    if (inner.startsWith(r'\ce')) {
      inner = _convertCe(inner.substring(3).replaceAll(RegExp(r'^\{|\}$'), ''));
    } else {
      inner = _convertSubSup(inner);
    }
    return inner;
  });

  // 2. 处理 `$...$` 行内公式(非贪婪,且不匹配已经处理过的 $$)
  final inlinePattern = RegExp(r'\$([^\$\n]+?)\$');
  result = result.replaceAllMapped(inlinePattern, (m) {
    var inner = m.group(1)!;
    if (inner.startsWith(r'\ce')) {
      // $\ce{...} → 提取 {...} 内容
      final ceMatch = RegExp(r'\\ce\{([^}]*)\}').firstMatch(inner);
      if (ceMatch != null) {
        return _convertCe(ceMatch.group(1)!);
      }
      return inner;
    }
    return _convertSubSup(inner);
  });

  return result;
}

/// 对话内容 Markdown 渲染器
class MarkdownChatContent extends StatelessWidget {
  const MarkdownChatContent({
    super.key,
    required this.content,
    required this.isDark,
    this.textAlign = WrapAlignment.start,
  });

  final String content;
  final bool isDark;
  final WrapAlignment textAlign;

  @override
  Widget build(BuildContext context) {
    final processed = preprocessMarkdown(content);

    final baseColor =
        isDark ? AppColors.textPrimary : AppColors.dayTextPrimary;
    final codeBg =
        isDark ? const Color(0xFF1E2A3A) : const Color(0xFFF5F5F5);
    final linkColor =
        isDark ? AppColors.aqua : AppColors.dayBluePrimary;
    final accent =
        isDark ? AppColors.aqua : AppColors.dayBluePrimary;

    return MarkdownBody(
      data: processed,
      selectable: true,
      fitContent: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 14, height: 1.5, color: baseColor),
        h1: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: baseColor,
        ),
        h2: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: baseColor,
        ),
        h3: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: baseColor,
        ),
        h4: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: baseColor,
        ),
        h5: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: baseColor,
        ),
        h6: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: baseColor,
        ),
        listBullet: TextStyle(color: baseColor, fontSize: 14),
        strong: TextStyle(fontWeight: FontWeight.w700, color: baseColor),
        em: TextStyle(fontStyle: FontStyle.italic, color: baseColor),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: codeBg,
          color: isDark ? const Color(0xFF80DEEA) : const Color(0xFFC62828),
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: accent.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
        ),
        blockquote: TextStyle(
          color: baseColor.withValues(alpha: 0.85),
          fontStyle: FontStyle.italic,
          fontSize: 13,
          height: 1.5,
        ),
        a: TextStyle(color: linkColor, decoration: TextDecoration.underline),
        tableHead: TextStyle(
          fontWeight: FontWeight.w700,
          color: baseColor,
          fontSize: 13,
        ),
        tableBody: TextStyle(color: baseColor, fontSize: 13),
        tableBorder: TableBorder.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
          width: 1,
        ),
        tableColumnWidth: const FlexColumnWidth(),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
      ),
      extensionSet: markdown.ExtensionSet.gitHubFlavored,
    );
  }
}
