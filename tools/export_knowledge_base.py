# 解析 lib/services/chemical_knowledge_base.dart 中的 KnowledgePoint 列表，导出为 JSON
import json
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
src_path = ROOT / "lib" / "services" / "chemical_knowledge_base.dart"
out_path = ROOT / "miniprogram" / "data" / "knowledge_base.json"
src = src_path.read_text(encoding="utf-8")

# 提取 allPoints 数组内容（在 "static const List<KnowledgePoint> allPoints = [" 到 "] ;" 或 "] ;" 结束）
start = src.find("allPoints = [")
if start < 0:
    print("ERROR: allPoints not found"); sys.exit(1)
# 从 '[' 开始，找到配对的 ']'
arr_start = src.index("[", start)
depth = 0
arr_end = None
i = arr_start
in_str = False
str_char = ''
while i < len(src):
    c = src[i]
    if in_str:
        if c == '\\':
            i += 2; continue
        if c == str_char:
            in_str = False
    else:
        if c == "'" or c == '"':
            in_str = True; str_char = c
        elif c == '[':
            depth += 1
        elif c == ']':
            depth -= 1
            if depth == 0:
                arr_end = i
                break
    i += 1
if arr_end is None:
    print("ERROR: unbalanced array"); sys.exit(1)

body = src[arr_start+1:arr_end]

# 拆分顶层 KnowledgePoint(...) 块
# 用括号配对找到每个 KnowledgePoint( 的结束
def split_blocks(text):
    blocks = []
    idx = 0
    while True:
        k = text.find("KnowledgePoint(", idx)
        if k < 0: break
        depth = 0
        i = k + len("KnowledgePoint(") - 1  # 位置在 '('
        start_i = k
        in_str = False; sc = ''
        while i < len(text):
            c = text[i]
            if in_str:
                if c == '\\': i += 2; continue
                if c == sc: in_str = False
            else:
                if c in ("'", '"'):
                    in_str = True; sc = c
                elif c == '(':
                    depth += 1
                elif c == ')':
                    depth -= 1
                    if depth == 0:
                        blocks.append(text[start_i:i+1])
                        idx = i + 1
                        break
            i += 1
        else:
            break
    return blocks

blocks = split_blocks(body)
print("Found", len(blocks), "KnowledgePoint blocks")

points = []
for b in blocks:
    # 提取键值对，值可能是字符串/数字/列表
    # 移除外层 KnowledgePoint(...)
    inner = b[len("KnowledgePoint("):-1]
    # 解析 named args: key: value
    def decode_dart_string(value):
        escapes = {
            "n": "\n",
            "r": "\r",
            "t": "\t",
            "b": "\b",
            "f": "\f",
            "\\": "\\",
            "'": "'",
            '"': '"',
            "$": "$",
        }
        decoded = []
        i = 0
        while i < len(value):
            if value[i] == "\\" and i + 1 < len(value):
                escape = value[i + 1]
                if escape == "u":
                    if i + 2 < len(value) and value[i + 2] == "{":
                        end = value.find("}", i + 3)
                        if end < 0:
                            raise ValueError("Dart 字符串包含未闭合的 Unicode 转义")
                        code_point = int(value[i + 3:end], 16)
                        i = end + 1
                    else:
                        code_point = int(value[i + 2:i + 6], 16)
                        i += 6
                    decoded.append(chr(code_point))
                elif escape == "x":
                    decoded.append(chr(int(value[i + 2:i + 4], 16)))
                    i += 4
                elif escape in escapes:
                    decoded.append(escapes[escape])
                    i += 2
                else:
                    raise ValueError(f"不支持的 Dart 字符串转义: \\{escape}")
            else:
                decoded.append(value[i])
                i += 1
        return "".join(decoded)

    def parse_value(s):
        s = s.strip()
        if s.startswith(("'", '"')):
            parts = []
            i = 0
            while i < len(s):
                while i < len(s) and s[i].isspace():
                    i += 1
                if i >= len(s):
                    break
                quote = s[i]
                if quote not in ("'", '"'):
                    raise ValueError(f"字符串字面量后存在未解析内容: {s[i:i + 80]}")
                start = i + 1
                i = start
                while i < len(s):
                    if s[i] == "\\":
                        i += 2
                        continue
                    if s[i] == quote:
                        break
                    i += 1
                if i >= len(s):
                    raise ValueError(f"字符串缺少结束引号: {s[:80]}")
                parts.append(decode_dart_string(s[start:i]))
                i += 1
            return "".join(parts)
        if s.startswith('['):
            # list of strings
            depth = 0
            in_string = False
            quote = ''
            end = None
            i = 0
            while i < len(s):
                c = s[i]
                if in_string:
                    if c == '\\':
                        i += 2
                        continue
                    if c == quote:
                        in_string = False
                elif c in ("'", '"'):
                    in_string = True
                    quote = c
                elif c == '[':
                    depth += 1
                elif c == ']':
                    depth -= 1
                    if depth == 0:
                        end = i
                        break
                i += 1
            if end is None:
                raise ValueError(f"列表缺少结束括号: {s[:80]}")
            list_str = s[1:end]
            item_pattern = re.compile(r"'((?:\\.|[^'\\])*)'|\"((?:\\.|[^\"\\])*)\"")
            return [
                decode_dart_string(
                    match.group(1) if match.group(1) is not None else match.group(2)
                )
                for match in item_pattern.finditer(list_str)
            ]
        # number
        try:
            return int(s)
        except ValueError:
            return s

    d = {}
    # 用正则匹配 "key: value" 但 value 可能含逗号/括号，需精细处理
    # 我们按逗号分割顶层参数（不在字符串内）
    args = []
    i = 0
    in_str=False; sc=''; depth=0
    cur_start = 0
    while i < len(inner):
        c = inner[i]
        if in_str:
            if c == '\\': i += 2; continue
            if c == sc: in_str=False
        else:
            if c in ("'",'"'):
                in_str=True; sc=c
            elif c == '[': depth += 1
            elif c == ']': depth -= 1
            elif c == ',' and depth == 0:
                args.append(inner[cur_start:i]); cur_start = i+1
        i += 1
    args.append(inner[cur_start:])

    for a in args:
        a = a.strip()
        if not a: continue
        if ':' in a:
            k, v = a.split(':', 1)
            k = k.strip()
            d[k] = parse_value(v)
    # 默认值
    d.setdefault('keywords', [])
    d.setdefault('relatedPointIds', [])
    d.setdefault('functionalGroups', [])
    d.setdefault('difficulty', 1)
    points.append(d)

# 校验字段完整
required_fields = (
    'id', 'name', 'category', 'stage', 'chapter', 'description', 'keywords',
    'relatedPointIds', 'functionalGroups', 'difficulty',
)
if not points:
    print("ERROR: 未解析到任何 KnowledgePoint")
    sys.exit(1)

has_missing_fields = False
seen_ids = set()
string_fields = ('id', 'name', 'category', 'stage', 'chapter', 'description')
list_fields = ('keywords', 'relatedPointIds', 'functionalGroups')
for p in points:
    missing = [key for key in required_fields if key not in p]
    if missing:
        print("WARN missing fields in", p.get('id'), missing)
        has_missing_fields = True
        continue
    invalid = [key for key in string_fields if not isinstance(p[key], str) or not p[key].strip()]
    invalid.extend(
        key for key in list_fields
        if not isinstance(p[key], list) or not all(isinstance(item, str) for item in p[key])
    )
    if type(p['difficulty']) is not int or not 1 <= p['difficulty'] <= 5:
        invalid.append('difficulty')
    if isinstance(p['id'], str):
        if p['id'] in seen_ids:
            invalid.append('duplicate id')
        seen_ids.add(p['id'])
    if invalid:
        print("WARN invalid fields in", p.get('id'), sorted(set(invalid)))
        has_missing_fields = True
if has_missing_fields:
    print("ERROR: 校验失败，未覆盖已有导出文件")
    sys.exit(1)

out_path.parent.mkdir(parents=True, exist_ok=True)
temp_path = None
try:
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=out_path.parent,
        prefix=f".{out_path.name}.",
        suffix=".tmp",
        delete=False,
    ) as temporary:
        temp_path = Path(temporary.name)
        json.dump(points, temporary, ensure_ascii=False, indent=2)
        temporary.write("\n")
    temp_path.replace(out_path)
finally:
    if temp_path is not None:
        temp_path.unlink(missing_ok=True)
print("WROTE", out_path, "with", len(points), "points")
print("Sample:", json.dumps(points[0], ensure_ascii=False))
