"""Render the competition Markdown drafts into a locally reviewable PDF.

Requires reportlab and a local CJK TrueType font (not copied into source).
Example: python tools/build_openatom_review_pdf.py --font C:/Windows/Fonts/simhei.ttf
"""
from __future__ import annotations

import argparse
import re
from html import escape
from pathlib import Path

from reportlab import rl_config
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
    KeepTogether, Image,
)

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs/competitions/openatom-2026'
FILES = [
    '02-project-summary.md', '03-technical-report.md', '04-architecture.md',
    '05-comparison.md', '06-evidence.md', '09-governance-roadmap.md',
    '10-submission-checklist.md', '13-current-removal-status.md',
    '14-speech-replacement.md',
]
TEAL = colors.HexColor('#147D78')
INK = colors.HexColor('#17334A')
PALE = colors.HexColor('#EDF6F5')


def inline(text: str) -> str:
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', lambda m: f'{m[1]} ({m[2]})', text)
    text = text.replace('`', '').replace('**', '')
    return escape(text).replace('\n', '<br/>')


def create(font: Path, output: Path) -> None:
    rl_config.warnOnMissingFontGlyphs = 1
    pdfmetrics.registerFont(TTFont('CJK', str(font)))
    # Same family for bold markup because the supplied font is a single face.
    pdfmetrics.registerFontFamily('CJK', normal='CJK', bold='CJK', italic='CJK', boldItalic='CJK')
    body = ParagraphStyle('Body', fontName='CJK', fontSize=9.2, leading=15,
                          textColor=INK, wordWrap='CJK', spaceAfter=7, alignment=TA_LEFT)
    small = ParagraphStyle('Small', parent=body, fontSize=7.3, leading=11, spaceAfter=3)
    h1 = ParagraphStyle('H1', parent=body, fontSize=19, leading=27, textColor=TEAL, spaceAfter=16)
    h2 = ParagraphStyle('H2', parent=body, fontSize=12, leading=19, textColor=TEAL, spaceBefore=12, spaceAfter=8)
    cover = ParagraphStyle('Cover', parent=h1, fontSize=32, leading=43)
    flow = [Spacer(1, 72), Paragraph('ChemVision', cover),
            Paragraph('化学结构可视化与 AI 辅助学习', h1),
            Spacer(1, 24), Paragraph('第四届开放原子大赛 · 2026<br/>开源行业解决方案创新赛 / 赛道一', body),
            Spacer(1, 28), Paragraph('作品说明 · 内部审阅稿', h1),
            Paragraph('核验日期：2026-10-22<br/>目标冻结日期：2026-10-29<br/>官方截止：2026-10-31 24:00（北京时间）', body),
            Spacer(1, 22), Paragraph('状态声明', h2),
            Paragraph('本文件由仓库 Markdown 草稿生成。参赛主体、全部权利人和第三方素材授权、中文 AI 与完整浏览器演示仍待核验；未报名、未发送材料。当前分支已移除原生端侧 SDK，语音改用系统或浏览器服务；构建结果和真机验证边界以状态记录为准。不能将本稿作为最终已合规或已提交的证明。', body),
            Paragraph('历史基线证据：26 项离线/组件测试通过，3 个真实英文公共化学查询样本通过；移除后的验证结果见当前状态记录。模型和 OCSR 效果未验证。', body),
            PageBreak(), Paragraph('阅读与证据索引', h1)]
    for name in FILES:
        title = (DOCS / name).read_text('utf-8').splitlines()[0].lstrip('# ')
        flow.append(Paragraph(f'{inline(title)}<br/><font size="7">{name}</font>', body))
    flow.extend([Spacer(1, 14), Paragraph('权威信息与提交边界', h2),
                 Paragraph('赛事官网：https://www.oschina.net/oa2026/<br/>详细规则核验、页面/配置冲突与只读来源见 00-official-rules.md。代码、测试和证据以同目录文件为准。私人合同和未授权材料不包含在本稿中。', body),
                 Paragraph('耗时为每个样本一次观测；测试桩与组件模拟数据不等于线上 AI、完整产品录屏或学生使用效果。所有未勾选清单项仍待完成。', body)])

    def para(text: str, style=body):
        return Paragraph(inline(text), style)

    for name in FILES:
        flow.append(PageBreak())
        lines = (DOCS / name).read_text('utf-8').splitlines()
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            if not line:
                i += 1
                continue
            if line.startswith('```'):
                kind = line[3:].strip()
                code = []
                i += 1
                while i < len(lines) and not lines[i].strip().startswith('```'):
                    code.append(lines[i])
                    i += 1
                if kind == 'mermaid':
                    flow.append(para('架构概要：Flutter/Riverpod → 结构服务 / 编辑器 / 教学编排 → 数据库、模型或 OCSR；学习行为写入本地 Hive，画像汇总供诊断/规划使用。完整 Mermaid 数据流见源码文档。'))
                else:
                    flow.append(Table([[para('\n'.join(code), small)]], colWidths=[475],
                                      style=TableStyle([('BACKGROUND',(0,0),(-1,-1),PALE),('BOX',(0,0),(-1,-1),0.4,TEAL),('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9)])))
                    flow.append(Spacer(1, 8))
            elif line.startswith('|'):
                rows = []
                while i < len(lines) and lines[i].strip().startswith('|'):
                    cells = [c.strip() for c in lines[i].strip().strip('|').split('|')]
                    if not all(re.match(r'^:?-+:?$', c) for c in cells):
                        rows.append([para(c, small) for c in cells])
                    i += 1
                cols = max(map(len, rows))
                widths = [475/cols]*cols
                flow.append(Table(rows, colWidths=widths, repeatRows=1, hAlign='LEFT',
                                  style=TableStyle([
                                      ('BACKGROUND',(0,0),(-1,0),PALE),
                                      ('GRID',(0,0),(-1,-1),0.3,colors.HexColor('#B6CDCC')),
                                      ('VALIGN',(0,0),(-1,-1),'TOP'),
                                      ('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),
                                      ('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6),
                                  ])))
                flow.append(Spacer(1, 9))
                continue
            elif line.startswith('# '):
                flow.append(para(line[2:], h1))
            elif line.startswith('## '):
                flow.append(para(line[3:], h2))
            else:
                # Plain paragraphs preserve checklist state without unsupported box glyphs.
                line = line.replace('- [x]', '[已完成]').replace('- [ ]', '[待完成]')
                flow.append(para(line))
            i += 1
        if name == '06-evidence.md':
            screenshot = DOCS / 'evidence/agent-result-fixture.png'
            if screenshot.exists():
                flow.append(PageBreak())
                flow.append(Paragraph('附图：真实组件渲染，使用模拟数据', h1))
                flow.append(Paragraph('仅证明结果组件可渲染。未调用真实模型，不是端到端产品演示或用户反馈。', body))
                flow.append(Image(str(screenshot), width=475, height=285))

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(TEAL)
        canvas.line(42, 39, 553, 39)
        canvas.setFont('CJK', 7)
        canvas.setFillColor(INK)
        canvas.drawString(42, 26, 'ChemVision / 开放原子 2026 / 内部审阅稿 - 未提交')
        canvas.drawRightString(553, 26, str(doc.page))
        canvas.restoreState()

    output.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(str(output), pagesize=A4, leftMargin=60, rightMargin=60,
                            topMargin=48, bottomMargin=54, title='ChemVision 开放原子2026作品说明（审阅稿）', author='ChemVision')
    doc.build(flow, onFirstPage=footer, onLaterPages=footer)
    print(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=DOCS/'chemvision-openatom-2026-review.pdf')
    args = parser.parse_args()
    create(args.font, args.output)
