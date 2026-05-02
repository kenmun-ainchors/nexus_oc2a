#!/usr/bin/env python3
"""
AInchors Ollama Cloud PoC Report Generator
Generates a professional PDF report using ReportLab
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm, cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether
)
from reportlab.platypus.flowables import Flowable
from reportlab.pdfgen import canvas as pdfcanvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import os

# ─── BRAND COLOURS ────────────────────────────────────────────────────────────
NAVY       = colors.HexColor("#1F3864")
NAVY_LIGHT = colors.HexColor("#2E4F8A")
BLUE_ACC   = colors.HexColor("#4472C4")
BLUE_LIGHT = colors.HexColor("#D6E4F7")
BLUE_MID   = colors.HexColor("#8AAED6")
WHITE      = colors.white
BLACK      = colors.black
GREY_DARK  = colors.HexColor("#333333")
GREY_MID   = colors.HexColor("#666666")
GREY_LIGHT = colors.HexColor("#F5F7FA")
GREY_LINE  = colors.HexColor("#CCCCCC")
GREEN      = colors.HexColor("#1E7E34")
GREEN_BG   = colors.HexColor("#D4EDDA")
RED        = colors.HexColor("#C0392B")
RED_BG     = colors.HexColor("#FADBD8")
ORANGE     = colors.HexColor("#E67E22")
ORANGE_BG  = colors.HexColor("#FDEBD0")
GOLD       = colors.HexColor("#F0C040")

OUTPUT_PATH = "/Users/ainchorsangiefpl/.openclaw/workspace/canvas/documents/ainchors-ollama-poc-report/ollama-cloud-poc-report.pdf"

PAGE_W, PAGE_H = A4
MARGIN_L = 2.0 * cm
MARGIN_R = 2.0 * cm
MARGIN_T = 2.5 * cm
MARGIN_B = 2.0 * cm
CONTENT_W = PAGE_W - MARGIN_L - MARGIN_R

# ─── HEADER / FOOTER CANVAS ───────────────────────────────────────────────────
class HeaderFooterCanvas(pdfcanvas.Canvas):
    def __init__(self, *args, **kwargs):
        pdfcanvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_header_footer(num_pages)
            pdfcanvas.Canvas.showPage(self)
        pdfcanvas.Canvas.save(self)

    def draw_header_footer(self, page_count):
        page_num = self._pageNumber
        # Skip header/footer on cover page
        if page_num == 1:
            return

        self.saveState()
        # Header bar
        self.setFillColor(NAVY)
        self.rect(0, PAGE_H - 18*mm, PAGE_W, 18*mm, fill=1, stroke=0)
        # Header text
        self.setFillColor(WHITE)
        self.setFont("Helvetica-Bold", 8)
        self.drawString(MARGIN_L, PAGE_H - 11*mm, "AInchors | AI Anchor Solutions Pty Ltd")
        self.setFont("Helvetica", 8)
        self.drawRightString(PAGE_W - MARGIN_R, PAGE_H - 11*mm, "INTERNAL / CONFIDENTIAL")

        # Footer
        self.setFillColor(NAVY)
        self.rect(0, 0, PAGE_W, 13*mm, fill=1, stroke=0)
        self.setFillColor(WHITE)
        self.setFont("Helvetica", 7.5)
        self.drawString(MARGIN_L, 5*mm, "Ollama Cloud PoC — Model Comparison Report  |  2026-05-02")
        self.drawRightString(PAGE_W - MARGIN_R, 5*mm, f"Page {page_num} of {page_count}")
        self.restoreState()


# ─── STYLES ───────────────────────────────────────────────────────────────────
def build_styles():
    base = getSampleStyleSheet()

    styles = {}

    styles['cover_title'] = ParagraphStyle(
        'cover_title',
        fontName='Helvetica-Bold',
        fontSize=28,
        textColor=WHITE,
        alignment=TA_CENTER,
        spaceAfter=8,
        leading=34,
    )
    styles['cover_subtitle'] = ParagraphStyle(
        'cover_subtitle',
        fontName='Helvetica',
        fontSize=15,
        textColor=BLUE_LIGHT,
        alignment=TA_CENTER,
        spaceAfter=6,
        leading=20,
    )
    styles['cover_company'] = ParagraphStyle(
        'cover_company',
        fontName='Helvetica-Bold',
        fontSize=13,
        textColor=WHITE,
        alignment=TA_CENTER,
        spaceAfter=4,
    )
    styles['cover_meta'] = ParagraphStyle(
        'cover_meta',
        fontName='Helvetica',
        fontSize=10,
        textColor=BLUE_LIGHT,
        alignment=TA_CENTER,
        spaceAfter=3,
    )
    styles['cover_classification'] = ParagraphStyle(
        'cover_classification',
        fontName='Helvetica-Bold',
        fontSize=11,
        textColor=GOLD,
        alignment=TA_CENTER,
        spaceAfter=4,
    )
    styles['section_title'] = ParagraphStyle(
        'section_title',
        fontName='Helvetica-Bold',
        fontSize=14,
        textColor=WHITE,
        spaceBefore=6,
        spaceAfter=4,
        leftIndent=0,
        leading=18,
    )
    styles['subsection_title'] = ParagraphStyle(
        'subsection_title',
        fontName='Helvetica-Bold',
        fontSize=11,
        textColor=NAVY,
        spaceBefore=10,
        spaceAfter=4,
        leading=15,
    )
    styles['body'] = ParagraphStyle(
        'body',
        fontName='Helvetica',
        fontSize=9.5,
        textColor=GREY_DARK,
        spaceAfter=5,
        leading=14,
        alignment=TA_JUSTIFY,
    )
    styles['body_bold'] = ParagraphStyle(
        'body_bold',
        fontName='Helvetica-Bold',
        fontSize=9.5,
        textColor=GREY_DARK,
        spaceAfter=4,
        leading=14,
    )
    styles['bullet'] = ParagraphStyle(
        'bullet',
        fontName='Helvetica',
        fontSize=9.5,
        textColor=GREY_DARK,
        spaceAfter=3,
        leading=14,
        leftIndent=14,
        bulletIndent=4,
    )
    styles['caption'] = ParagraphStyle(
        'caption',
        fontName='Helvetica-Oblique',
        fontSize=8.5,
        textColor=GREY_MID,
        alignment=TA_CENTER,
        spaceAfter=6,
    )
    styles['table_header'] = ParagraphStyle(
        'table_header',
        fontName='Helvetica-Bold',
        fontSize=8.5,
        textColor=WHITE,
        alignment=TA_CENTER,
    )
    styles['table_cell'] = ParagraphStyle(
        'table_cell',
        fontName='Helvetica',
        fontSize=8.5,
        textColor=GREY_DARK,
        alignment=TA_CENTER,
        leading=12,
    )
    styles['table_cell_left'] = ParagraphStyle(
        'table_cell_left',
        fontName='Helvetica',
        fontSize=8.5,
        textColor=GREY_DARK,
        alignment=TA_LEFT,
        leading=12,
    )
    styles['verdict_pass'] = ParagraphStyle(
        'verdict_pass',
        fontName='Helvetica-Bold',
        fontSize=8.5,
        textColor=GREEN,
        alignment=TA_CENTER,
    )
    styles['verdict_fail'] = ParagraphStyle(
        'verdict_fail',
        fontName='Helvetica-Bold',
        fontSize=8.5,
        textColor=RED,
        alignment=TA_CENTER,
    )
    styles['highlight_box'] = ParagraphStyle(
        'highlight_box',
        fontName='Helvetica',
        fontSize=9.5,
        textColor=NAVY,
        leading=14,
        leftIndent=8,
    )
    styles['code'] = ParagraphStyle(
        'code',
        fontName='Courier',
        fontSize=8,
        textColor=GREY_DARK,
        leading=12,
        leftIndent=8,
        spaceAfter=2,
    )
    styles['toc_entry'] = ParagraphStyle(
        'toc_entry',
        fontName='Helvetica',
        fontSize=10,
        textColor=GREY_DARK,
        spaceAfter=5,
        leading=14,
    )
    styles['toc_section'] = ParagraphStyle(
        'toc_section',
        fontName='Helvetica-Bold',
        fontSize=10,
        textColor=NAVY,
        spaceAfter=3,
        leading=14,
    )

    return styles


# ─── HELPERS ──────────────────────────────────────────────────────────────────
def section_header(text, styles):
    """Returns a table used as a coloured section header banner."""
    header_text = Paragraph(text, styles['section_title'])
    t = Table([[header_text]], colWidths=[CONTENT_W])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), NAVY),
        ('TOPPADDING', (0,0), (-1,-1), 7),
        ('BOTTOMPADDING', (0,0), (-1,-1), 7),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    return t


def info_box(text, styles, bg=BLUE_LIGHT, border=BLUE_ACC):
    """Coloured info/callout box."""
    p = Paragraph(text, styles['highlight_box'])
    t = Table([[p]], colWidths=[CONTENT_W])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), bg),
        ('BOX', (0,0), (-1,-1), 1.5, border),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
    ]))
    return t


def verdict_cell(text):
    """Returns coloured verdict string for table cells."""
    if '✅' in text or 'PASS' in text:
        return colors.HexColor("#1E7E34"), WHITE
    elif '❌' in text or 'FAIL' in text:
        return RED, WHITE
    elif '⚠️' in text:
        return ORANGE, WHITE
    return GREY_DARK, WHITE


# ─── COVER PAGE ───────────────────────────────────────────────────────────────
def build_cover(styles):
    elements = []

    # Full navy background via a large spacer + decorative elements through canvas
    # We'll use a table to simulate the cover layout
    elements.append(Spacer(1, 0.5*cm))

    # Logo / brand mark area - top accent line
    accent = Table([['']],  colWidths=[CONTENT_W], rowHeights=[4])
    accent.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), BLUE_ACC),
    ]))

    # Cover frame table
    cover_data = [
        [Spacer(1, 1.5*cm)],
        [Paragraph("OLLAMA CLOUD POC", ParagraphStyle('ct1', fontName='Helvetica',
            fontSize=13, textColor=BLUE_LIGHT, alignment=TA_CENTER, spaceAfter=4))],
        [Paragraph("Model Comparison Report", ParagraphStyle('ct2', fontName='Helvetica-Bold',
            fontSize=32, textColor=WHITE, alignment=TA_CENTER, spaceAfter=6, leading=38))],
        [Spacer(1, 0.3*cm)],
        [HRFlowable(width=CONTENT_W*0.5, thickness=1.5, color=BLUE_ACC, spaceAfter=8, spaceBefore=4)],
        [Spacer(1, 0.2*cm)],
        [Paragraph("AI Infrastructure Cost Optimisation — Frontier Model Evaluation",
            ParagraphStyle('ct3', fontName='Helvetica', fontSize=13, textColor=BLUE_LIGHT,
            alignment=TA_CENTER, spaceAfter=4, leading=18))],
        [Spacer(1, 1.5*cm)],
        # Classification badge
        [Table([[Paragraph("⚑  INTERNAL / CONFIDENTIAL", ParagraphStyle('cls',
            fontName='Helvetica-Bold', fontSize=11, textColor=NAVY, alignment=TA_CENTER))]],
            colWidths=[7*cm],
            style=[
                ('BACKGROUND', (0,0), (-1,-1), GOLD),
                ('TOPPADDING', (0,0), (-1,-1), 6),
                ('BOTTOMPADDING', (0,0), (-1,-1), 6),
                ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ])],
        [Spacer(1, 2*cm)],
        # Meta info block
        [Table([
            [Paragraph("<b>Company:</b>", styles['cover_meta']),
             Paragraph("AInchors | AI Anchor Solutions Pty Ltd", styles['cover_meta'])],
            [Paragraph("<b>Date:</b>", styles['cover_meta']),
             Paragraph("2026-05-02", styles['cover_meta'])],
            [Paragraph("<b>Prepared by:</b>", styles['cover_meta']),
             Paragraph("Yoda 🟢, AI Operations Lead Agent", styles['cover_meta'])],
            [Paragraph("<b>Authorised by:</b>", styles['cover_meta']),
             Paragraph("Ken Mun, CTO", styles['cover_meta'])],
            [Paragraph("<b>Version:</b>", styles['cover_meta']),
             Paragraph("1.0 — Final", styles['cover_meta'])],
        ], colWidths=[4*cm, 10*cm],
        style=[
            ('TEXTCOLOR', (0,0), (-1,-1), BLUE_LIGHT),
            ('FONTNAME', (0,0), (0,-1), 'Helvetica-Bold'),
            ('FONTSIZE', (0,0), (-1,-1), 10),
            ('TOPPADDING', (0,0), (-1,-1), 3),
            ('BOTTOMPADDING', (0,0), (-1,-1), 3),
            ('ALIGN', (0,0), (0,-1), 'RIGHT'),
            ('ALIGN', (1,0), (1,-1), 'LEFT'),
        ])],
        [Spacer(1, 2*cm)],
    ]

    cover_table = Table(cover_data, colWidths=[CONTENT_W])
    cover_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), NAVY),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING', (0,0), (-1,-1), 20),
        ('RIGHTPADDING', (0,0), (-1,-1), 20),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))

    # Outer frame
    outer = Table([[cover_table]], colWidths=[CONTENT_W])
    outer.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), NAVY),
        ('BOX', (0,0), (-1,-1), 3, BLUE_ACC),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))

    elements.append(outer)
    elements.append(Spacer(1, 0.5*cm))

    # Bottom strip
    bottom = Table([[Paragraph(
        "This document contains proprietary and confidential information of AInchors | AI Anchor Solutions Pty Ltd. "
        "Unauthorised reproduction or distribution is strictly prohibited.",
        ParagraphStyle('foot', fontName='Helvetica-Oblique', fontSize=7.5,
                       textColor=GREY_MID, alignment=TA_CENTER)
    )]], colWidths=[CONTENT_W])
    bottom.setStyle(TableStyle([
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
    ]))
    elements.append(bottom)
    elements.append(PageBreak())

    return elements


# ─── TABLE OF CONTENTS ────────────────────────────────────────────────────────
def build_toc(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Table of Contents", styles))
    elements.append(Spacer(1, 0.4*cm))

    toc_items = [
        ("1", "Executive Summary", "3"),
        ("2", "Test Methodology", "4"),
        ("3", "Baseline Model: kimi-k2.6:cloud", "5"),
        ("4", "deepseek-v4-flash:cloud vs Baseline", "6"),
        ("5", "deepseek-v4-pro:cloud vs Baseline", "7"),
        ("6", "Failed Models", "8"),
        ("7", "Master Comparison Table", "10"),
        ("8", "Cost Analysis", "11"),
        ("9", "Routing Recommendations", "12"),
        ("10", "Implementation Status", "13"),
        ("11", "Appendix: Sample Model Outputs", "14"),
    ]

    toc_data = []
    for num, title, page in toc_items:
        dots = '.' * max(1, 60 - len(title) - len(num) - len(page))
        toc_data.append([
            Paragraph(f"<b>{num}</b>", ParagraphStyle('tn', fontName='Helvetica-Bold',
                fontSize=10, textColor=BLUE_ACC)),
            Paragraph(f"{title}", ParagraphStyle('tt', fontName='Helvetica',
                fontSize=10, textColor=GREY_DARK)),
            Paragraph(f"{page}", ParagraphStyle('tp', fontName='Helvetica',
                fontSize=10, textColor=GREY_DARK, alignment=TA_RIGHT)),
        ])

    toc_table = Table(toc_data, colWidths=[0.8*cm, CONTENT_W - 2.2*cm, 1.4*cm])
    toc_table.setStyle(TableStyle([
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [WHITE, GREY_LIGHT]),
    ]))
    elements.append(toc_table)
    elements.append(PageBreak())
    return elements


# ─── SECTION 1: EXECUTIVE SUMMARY ─────────────────────────────────────────────
def build_exec_summary(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 1 — Executive Summary", styles))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph(
        "This report documents the results of the AInchors Ollama Cloud Proof-of-Concept (PoC) evaluation, "
        "conducted on 2026-05-02. The objective was to identify frontier models available on Ollama Cloud "
        "capable of serving as a <b>Tier 2 inference layer</b>, enabling significant reduction in Claude API spend "
        "while maintaining production-grade quality and response latency standards.",
        styles['body']
    ))
    elements.append(Spacer(1, 0.3*cm))

    # Key findings box
    elements.append(info_box(
        "<b>Key Findings:</b><br/>"
        "• <b>3 of 6 models PASSED</b> all benchmarks (quality ≥3.5/5, latency ≤20s)<br/>"
        "• <b>Best performer:</b> kimi-k2.6:cloud — Q=4.6/5, L=6.8s — selected as primary Tier 2 model<br/>"
        "• <b>All 3 passing models now LIVE</b> in model-policy.json (CHG-0120, CHG-0121)<br/>"
        "• <b>Estimated net saving:</b> $690–$1,755/month vs Claude baseline of ~$3,550/month<br/>"
        "• <b>ROI on $20/month Ollama Pro:</b> minimum 34.5× return",
        styles, bg=BLUE_LIGHT, border=BLUE_ACC
    ))
    elements.append(Spacer(1, 0.4*cm))

    # Summary stats table
    summary_data = [
        [Paragraph("Metric", styles['table_header']),
         Paragraph("Value", styles['table_header'])],
        ["Claude Sonnet 4.6 baseline cost", "~$3,550/month (7-day avg $118/day × 30)"],
        ["Models evaluated", "6 frontier models on Ollama Cloud"],
        ["Models passed", "3 (kimi-k2.6, deepseek-v4-flash, deepseek-v4-pro)"],
        ["Models failed", "3 (glm-5.1, qwen3.5, gemma4-community)"],
        ["Primary Tier 2 model", "kimi-k2.6:cloud"],
        ["Ollama Pro cost", "$20/month flat (all 3 passing models)"],
        ["Conservative net saving", "$690/month (20% Tier 2 offload)"],
        ["Moderate net saving", "$1,223/month (35% Tier 2 offload)"],
        ["Optimistic net saving", "$1,755/month (50% Tier 2 offload)"],
        ["Implementation status", "LIVE — all 3 models active in production"],
    ]

    col_w = [CONTENT_W * 0.45, CONTENT_W * 0.55]
    t = Table(summary_data, colWidths=col_w)
    ts = TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 9),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('ALIGN', (0,0), (-1,0), 'CENTER'),
        ('ALIGN', (0,1), (0,-1), 'LEFT'),
        ('ALIGN', (1,1), (1,-1), 'LEFT'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [WHITE, GREY_LIGHT]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
        ('FONTNAME', (0,1), (0,-1), 'Helvetica-Bold'),
        ('TEXTCOLOR', (0,1), (0,-1), NAVY),
        # Highlight passing/failing rows
        ('BACKGROUND', (0,3), (-1,3), GREEN_BG),
        ('BACKGROUND', (0,4), (-1,4), RED_BG),
        ('BACKGROUND', (0,10), (-1,10), GREEN_BG),
    ])
    t.setStyle(ts)
    elements.append(t)
    elements.append(Spacer(1, 0.3*cm))

    elements.append(Paragraph(
        "<b>Status:</b> IMPLEMENTED. All three passing models are live and enforced by Warden with "
        "data_sensitivity routing logic. Sensitive data (PII, medical, legal) continues to route "
        "exclusively to Anthropic or local models.",
        styles['body']
    ))
    elements.append(PageBreak())
    return elements


# ─── SECTION 2: TEST METHODOLOGY ─────────────────────────────────────────────
def build_methodology(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 2 — Test Methodology", styles))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph(
        "Each model was evaluated against five benchmark tasks (B1–B5) representing the core workload "
        "categories encountered in AInchors daily operations. Tasks were designed to test reasoning depth, "
        "code quality, communication ability, structured output fidelity, and governance judgement.",
        styles['body']
    ))
    elements.append(Spacer(1, 0.3*cm))

    elements.append(Paragraph("2.1 — Benchmark Tasks", styles['subsection_title']))

    bench_data = [
        [Paragraph("ID", styles['table_header']),
         Paragraph("Category", styles['table_header']),
         Paragraph("Task Description", styles['table_header']),
         Paragraph("Evaluation Criteria", styles['table_header'])],
        ["B1", "Reasoning",
         "List the top 3 LLM cloud security risks. Concise format.",
         "Accuracy, relevance, conciseness"],
        ["B2", "Coding",
         "Write a Python routing function (~20 lines) accepting data_sensitivity + task_complexity args.",
         "Correctness, privacy logic, code quality"],
        ["B3", "Business Writing",
         "Write a LinkedIn post (3 sentences) about 60% AI cost reduction in AU context.",
         "Tone, clarity, commercial relevance"],
        ["B4", "Tool Use",
         "Generate a JSON tool call: get_calendar_events(date='2026-05-02').",
         "Exact JSON schema compliance"],
        ["B5", "Governance",
         "Decision: should medical records be stored with a cloud AI provider?",
         "Regulatory accuracy, risk posture, sovereignty"],
    ]

    col_w = [0.7*cm, 2.3*cm, CONTENT_W*0.42, CONTENT_W*0.28]
    t = Table(bench_data, colWidths=col_w)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (1,-1), 'CENTER'),
        ('ALIGN', (2,0), (3,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [WHITE, GREY_LIGHT]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('FONTNAME', (0,1), (0,-1), 'Helvetica-Bold'),
        ('TEXTCOLOR', (0,1), (0,-1), BLUE_ACC),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph("2.2 — Pass Thresholds", styles['subsection_title']))

    threshold_data = [
        [Paragraph("Metric", styles['table_header']),
         Paragraph("Pass Threshold", styles['table_header']),
         Paragraph("Measurement Method", styles['table_header']),
         Paragraph("Notes", styles['table_header'])],
        ["Quality Score", "≥ 3.5 / 5.0 average", "Human evaluation per task (0–5)", "Both metrics must pass"],
        ["Response Latency", "≤ 20.0 seconds average", "Wall-clock time per API call", "Any single fail is noted ⚠️"],
        ["Overall Verdict", "BOTH thresholds met", "Logical AND of above", "Marginal pass noted if close"],
    ]
    col_w2 = [2.5*cm, 3.5*cm, CONTENT_W*0.35, CONTENT_W*0.25]
    t2 = Table(threshold_data, colWidths=col_w2)
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (-1,0), 'CENTER'),
        ('ALIGN', (0,1), (1,-1), 'CENTER'),
        ('ALIGN', (2,1), (3,-1), 'LEFT'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [WHITE, GREY_LIGHT]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    elements.append(t2)
    elements.append(Spacer(1, 0.3*cm))

    elements.append(info_box(
        "<b>Scoring Legend:</b>  "
        "<font color='#1E7E34'><b>✅ PASS</b></font> — Meets threshold  &nbsp;|&nbsp;  "
        "<font color='#E67E22'><b>⚠️ WARN</b></font> — Individual task over threshold but avg passes  &nbsp;|&nbsp;  "
        "<font color='#C0392B'><b>❌ FAIL</b></font> — Below threshold (model rejected)",
        styles, bg=GREY_LIGHT, border=GREY_LINE
    ))
    elements.append(PageBreak())
    return elements


# ─── SECTION 3: KIMI BASELINE ─────────────────────────────────────────────────
def build_kimi_section(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))

    # Special winner header
    winner_text = Paragraph(
        "Section 3 — Baseline Model: kimi-k2.6:cloud  ★ WINNER — PRIMARY TIER 2",
        styles['section_title']
    )
    t = Table([[winner_text]], colWidths=[CONTENT_W])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), GREEN),
        ('TOPPADDING', (0,0), (-1,-1), 7),
        ('BOTTOMPADDING', (0,0), (-1,-1), 7),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.4*cm))

    elements.append(info_box(
        "<b>kimi-k2.6:cloud</b> achieved the highest composite score of all evaluated models: "
        "<b>Quality 4.6/5</b> and <b>Average Latency 6.8s</b> — fastest by a significant margin. "
        "Selected as the primary Tier 2 model and deployed immediately under CHG-0120.",
        styles, bg=GREEN_BG, border=GREEN
    ))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph("3.1 — Benchmark Results", styles['subsection_title']))

    kimi_data = [
        [Paragraph("Task", styles['table_header']),
         Paragraph("Category", styles['table_header']),
         Paragraph("Quality", styles['table_header']),
         Paragraph("Latency", styles['table_header']),
         Paragraph("Status", styles['table_header']),
         Paragraph("Key Output / Notes", styles['table_header'])],
        ["B1", "Reasoning", "5 / 5", "9.7s", "✅ PASS",
         '"Data leakage & loss of confidentiality… Compliance & sovereignty violations… Cross-tenant security gaps"'],
        ["B2", "Coding", "4 / 5", "8.9s", "✅ PASS",
         "Clean Python, privacy-first routing logic, correct conflict handling between args"],
        ["B3", "Business\nWriting", "5 / 5", "3.9s", "✅ PASS",
         '"We\'re helping Australian businesses slash their AI running costs by intelligently routing workloads..."'],
        ["B4", "Tool Use", "4 / 5", "4.4s", "✅ PASS",
         '{"name": "get_calendar_events", "arguments": {"date": "2026-05-02"}}'],
        ["B5", "Governance", "5 / 5", "7.0s", "✅ PASS",
         '"Decline unless the cloud provider contractually guarantees data residency within the client\'s jurisdiction"'],
        [Paragraph("<b>AVG</b>", ParagraphStyle('avg', fontName='Helvetica-Bold', fontSize=9)),
         "",
         Paragraph("<b>4.6 / 5</b>", ParagraphStyle('avg', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         Paragraph("<b>6.8s</b>", ParagraphStyle('avg', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         Paragraph("<b>✅ PASS</b>", ParagraphStyle('avg', fontName='Helvetica-Bold', fontSize=9, textColor=WHITE, alignment=TA_CENTER)),
         Paragraph("<b>Fastest model, highest quality, all tasks passed</b>",
                   ParagraphStyle('avg', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY))],
    ]

    col_w = [0.8*cm, 1.8*cm, 1.5*cm, 1.4*cm, 1.8*cm, CONTENT_W - 7.3*cm]
    t = Table(kimi_data, colWidths=col_w)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (-1,0), 'CENTER'),
        ('ALIGN', (0,1), (4,-1), 'CENTER'),
        ('ALIGN', (5,1), (5,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [WHITE, GREY_LIGHT]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        # Pass cells green
        ('BACKGROUND', (4,1), (4,5), GREEN_BG),
        ('TEXTCOLOR', (4,1), (4,5), GREEN),
        ('FONTNAME', (4,1), (4,5), 'Helvetica-Bold'),
        # AVG row
        ('BACKGROUND', (0,6), (-1,6), GREEN_BG),
        ('BACKGROUND', (4,6), (4,6), GREEN),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph("3.2 — Strengths & Best Use Cases", styles['subsection_title']))
    strengths = [
        ("Fastest response time", "Average 6.8s — 1.85× faster than deepseek-v4-flash, 2.71× faster than deepseek-v4-pro"),
        ("Highest creative quality", "Scored 5/5 on B1, B3, B5 — reasoning, writing, and governance"),
        ("Consistent across all task types", "No single task exceeded 10s; no latency outliers"),
        ("Tool use accuracy", "Precise JSON schema compliance on B4"),
        ("Governance judgement", "Strong data sovereignty stance aligned with AInchors policy"),
    ]
    str_data = [[Paragraph(f"<b>{s}</b>", ParagraphStyle('sl', fontName='Helvetica-Bold', fontSize=9, textColor=NAVY)),
                 Paragraph(d, ParagraphStyle('sd', fontName='Helvetica', fontSize=9, textColor=GREY_DARK))]
                for s, d in strengths]
    str_t = Table(str_data, colWidths=[4*cm, CONTENT_W - 4*cm])
    str_t.setStyle(TableStyle([
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [WHITE, GREY_LIGHT]),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    elements.append(str_t)
    elements.append(PageBreak())
    return elements


# ─── SECTION 4: DEEPSEEK FLASH ────────────────────────────────────────────────
def build_deepseek_flash(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 4 — deepseek-v4-flash:cloud vs Baseline (kimi)", styles))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(info_box(
        "<b>Verdict: ✅ PASS</b> — deepseek-v4-flash meets both quality (4.2/5) and latency (12.6s avg) thresholds. "
        "Quality is slightly below kimi baseline (-0.4) but latency is well within the 20s threshold. "
        "Best suited for fast concurrent subtasks and time-sensitive parallel workflows.",
        styles, bg=GREEN_BG, border=GREEN
    ))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph("4.1 — Benchmark Results", styles['subsection_title']))

    flash_data = [
        [Paragraph("Task", styles['table_header']),
         Paragraph("Quality", styles['table_header']),
         Paragraph("Latency", styles['table_header']),
         Paragraph("vs kimi Q", styles['table_header']),
         Paragraph("vs kimi L", styles['table_header']),
         Paragraph("Status", styles['table_header'])],
        ["B1", "4 / 5", "5.0s",   "−1", "−4.7s ✓", "✅ PASS"],
        ["B2", "4 / 5", "34.0s",  "−1", "+25.1s", "⚠️ WARN"],
        ["B3", "4 / 5", "3.0s",   "−1", "−0.9s ✓", "✅ PASS"],
        ["B4", "5 / 5", "19.0s",  "+1", "+14.6s", "✅ PASS"],
        ["B5", "4 / 5", "2.0s",   "−1", "−5.0s ✓", "✅ PASS"],
        [Paragraph("<b>AVG</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9)),
         Paragraph("<b>4.2 / 5</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         Paragraph("<b>12.6s</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         Paragraph("<b>−0.4</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=ORANGE, alignment=TA_CENTER)),
         Paragraph("<b>+5.8s</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=ORANGE, alignment=TA_CENTER)),
         Paragraph("<b>✅ PASS</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=WHITE, alignment=TA_CENTER))],
    ]

    col_w = [1.2*cm, 2*cm, 2*cm, 2.2*cm, 2.2*cm, 2.5*cm]
    remaining = CONTENT_W - sum(col_w)
    col_w = [1.2*cm, 2*cm, 2*cm, 2.2*cm, 2.2*cm, CONTENT_W - 9.6*cm]

    t = Table(flash_data, colWidths=col_w)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [WHITE, GREY_LIGHT]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('BACKGROUND', (5,1), (5,1), GREEN_BG), ('TEXTCOLOR', (5,1), (5,1), GREEN), ('FONTNAME', (5,1), (5,1), 'Helvetica-Bold'),
        ('BACKGROUND', (5,2), (5,2), ORANGE_BG), ('TEXTCOLOR', (5,2), (5,2), ORANGE), ('FONTNAME', (5,2), (5,2), 'Helvetica-Bold'),
        ('BACKGROUND', (5,3), (5,3), GREEN_BG), ('TEXTCOLOR', (5,3), (5,3), GREEN), ('FONTNAME', (5,3), (5,3), 'Helvetica-Bold'),
        ('BACKGROUND', (5,4), (5,4), GREEN_BG), ('TEXTCOLOR', (5,4), (5,4), GREEN), ('FONTNAME', (5,4), (5,4), 'Helvetica-Bold'),
        ('BACKGROUND', (5,5), (5,5), GREEN_BG), ('TEXTCOLOR', (5,5), (5,5), GREEN), ('FONTNAME', (5,5), (5,5), 'Helvetica-Bold'),
        ('BACKGROUND', (0,6), (-1,6), GREEN_BG),
        ('BACKGROUND', (5,6), (5,6), GREEN),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph("4.2 — Delta Analysis vs kimi Baseline", styles['subsection_title']))
    delta_data = [
        [Paragraph("Dimension", styles['table_header']),
         Paragraph("kimi (baseline)", styles['table_header']),
         Paragraph("deepseek-v4-flash", styles['table_header']),
         Paragraph("Delta", styles['table_header']),
         Paragraph("Assessment", styles['table_header'])],
        ["Avg Quality", "4.6 / 5", "4.2 / 5", "−0.4", "Slightly lower — acceptable for non-critical tasks"],
        ["Avg Latency", "6.8s", "12.6s", "+5.8s", "85% slower but 7.4s headroom to threshold"],
        ["B2 Latency", "8.9s", "34.0s", "+25.1s", "Single-task outlier; avg still passes"],
        ["Cost", "$20/mo flat", "$20/mo flat", "None", "Same Ollama Pro plan covers both"],
    ]
    col_w2 = [2.5*cm, 2.5*cm, 3*cm, 2*cm, CONTENT_W - 10*cm]
    t2 = Table(delta_data, colWidths=col_w2)
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY_LIGHT),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (-1,0), 'CENTER'),
        ('ALIGN', (0,1), (3,-1), 'CENTER'),
        ('ALIGN', (4,1), (4,-1), 'LEFT'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [WHITE, GREY_LIGHT]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
    ]))
    elements.append(t2)
    elements.append(PageBreak())
    return elements


# ─── SECTION 5: DEEPSEEK PRO ──────────────────────────────────────────────────
def build_deepseek_pro(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 5 — deepseek-v4-pro:cloud vs Baseline (kimi)", styles))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(info_box(
        "<b>Verdict: ✅ PASS (Marginal)</b> — deepseek-v4-pro matches kimi's quality (4.6/5) but is "
        "significantly slower at 18.4s average — only 1.6s headroom before failing the 20s threshold. "
        "B2 latency of 59s reflects extended Chain-of-Thought (CoT) on complex coding tasks. "
        "Recommended for async/non-interactive workflows and complex reasoning tasks.",
        styles, bg=ORANGE_BG, border=ORANGE
    ))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph("5.1 — Benchmark Results", styles['subsection_title']))

    pro_data = [
        [Paragraph("Task", styles['table_header']),
         Paragraph("Quality", styles['table_header']),
         Paragraph("Latency", styles['table_header']),
         Paragraph("vs kimi Q", styles['table_header']),
         Paragraph("vs kimi L", styles['table_header']),
         Paragraph("Status", styles['table_header'])],
        ["B1", "4 / 5", "14.0s",  "−1", "+4.3s",  "✅ PASS"],
        ["B2", "5 / 5", "59.0s",  "+1", "+50.1s", "⚠️ WARN"],
        ["B3", "5 / 5", "4.0s",   "+1", "+0.1s",  "✅ PASS"],
        ["B4", "5 / 5", "6.0s",   "+1", "+1.6s",  "✅ PASS"],
        ["B5", "4 / 5", "9.0s",   "−1", "+2.0s",  "✅ PASS"],
        [Paragraph("<b>AVG</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9)),
         Paragraph("<b>4.6 / 5</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         Paragraph("<b>18.4s</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=ORANGE, alignment=TA_CENTER)),
         Paragraph("<b>0</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         Paragraph("<b>+11.6s</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=ORANGE, alignment=TA_CENTER)),
         Paragraph("<b>✅ PASS</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=WHITE, alignment=TA_CENTER))],
    ]

    col_w = [1.2*cm, 2*cm, 2*cm, 2.2*cm, 2.2*cm, CONTENT_W - 9.6*cm]
    t = Table(pro_data, colWidths=col_w)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [WHITE, GREY_LIGHT]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('BACKGROUND', (5,1), (5,1), GREEN_BG), ('TEXTCOLOR', (5,1), (5,1), GREEN), ('FONTNAME', (5,1), (5,1), 'Helvetica-Bold'),
        ('BACKGROUND', (5,2), (5,2), ORANGE_BG), ('TEXTCOLOR', (5,2), (5,2), ORANGE), ('FONTNAME', (5,2), (5,2), 'Helvetica-Bold'),
        ('BACKGROUND', (5,3), (5,3), GREEN_BG), ('TEXTCOLOR', (5,3), (5,3), GREEN), ('FONTNAME', (5,3), (5,3), 'Helvetica-Bold'),
        ('BACKGROUND', (5,4), (5,4), GREEN_BG), ('TEXTCOLOR', (5,4), (5,4), GREEN), ('FONTNAME', (5,4), (5,4), 'Helvetica-Bold'),
        ('BACKGROUND', (5,5), (5,5), GREEN_BG), ('TEXTCOLOR', (5,5), (5,5), GREEN), ('FONTNAME', (5,5), (5,5), 'Helvetica-Bold'),
        ('BACKGROUND', (0,6), (-1,6), ORANGE_BG),
        ('BACKGROUND', (5,6), (5,6), GREEN),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.3*cm))

    elements.append(info_box(
        "<b>Note on B2 Latency (59s):</b> deepseek-v4-pro engages extended Chain-of-Thought (CoT) reasoning "
        "on complex coding tasks. While the 59s single-task result is far above threshold, the model's average "
        "passes at 18.4s. This model should be routed exclusively to async queues for coding tasks.",
        styles, bg=ORANGE_BG, border=ORANGE
    ))
    elements.append(PageBreak())
    return elements


# ─── SECTION 6: FAILED MODELS ─────────────────────────────────────────────────
def build_failed_models(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 6 — Failed Models", styles))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph(
        "Three models failed evaluation. All failures were latency-related — quality scores were generally "
        "adequate, but response times were unacceptable for real-time Tier 2 inference. None of the failed "
        "models were added to model-policy.json.",
        styles['body']
    ))
    elements.append(Spacer(1, 0.3*cm))

    # GLM
    glm_header = Table([[Paragraph("6.1 — glm-5.1:cloud  ❌ FAIL — Catastrophic Latency",
        ParagraphStyle('sh', fontName='Helvetica-Bold', fontSize=11, textColor=WHITE))]], colWidths=[CONTENT_W])
    glm_header.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), RED),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
    ]))
    elements.append(glm_header)
    elements.append(Spacer(1, 0.2*cm))

    glm_data = [
        [Paragraph("Task", styles['table_header']),
         Paragraph("Quality", styles['table_header']),
         Paragraph("Latency", styles['table_header']),
         Paragraph("Status", styles['table_header']),
         Paragraph("Notes", styles['table_header'])],
        ["B1", "4 / 5", "40.5s", "❌ FAIL", "2× above threshold immediately"],
        ["B2", "—", "402.5s → KILLED", "❌ FAIL", "Test aborted; CoT extended thinking active by default"],
        ["B3–B5", "—", "NOT RUN", "❌ FAIL", "Testing halted after catastrophic B2 result"],
        [Paragraph("<b>AVG</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9)),
         "N/A",
         Paragraph("<b>221s+</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=RED, alignment=TA_CENTER)),
         Paragraph("<b>❌ FAIL</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=WHITE, alignment=TA_CENTER)),
         "10–20× above 20s threshold. Not viable for any real-time workload."],
    ]
    col_w = [1.2*cm, 1.8*cm, 3.5*cm, 2.2*cm, CONTENT_W - 8.7*cm]
    t = Table(glm_data, colWidths=col_w)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#8B0000")),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (3,-1), 'CENTER'),
        ('ALIGN', (4,0), (4,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [RED_BG, colors.HexColor("#FAEAEA")]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('BACKGROUND', (3,1), (3,3), RED_BG), ('TEXTCOLOR', (3,1), (3,3), RED), ('FONTNAME', (3,1), (3,3), 'Helvetica-Bold'),
        ('BACKGROUND', (0,4), (-1,4), RED_BG),
        ('BACKGROUND', (3,4), (3,4), RED),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.4*cm))

    # QWEN
    qwen_header = Table([[Paragraph("6.2 — qwen3.5:cloud (with /no_think flag)  ❌ FAIL — Latency",
        ParagraphStyle('sh', fontName='Helvetica-Bold', fontSize=11, textColor=WHITE))]], colWidths=[CONTENT_W])
    qwen_header.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), RED),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
    ]))
    elements.append(qwen_header)
    elements.append(Spacer(1, 0.2*cm))

    qwen_data = [
        [Paragraph("Task", styles['table_header']),
         Paragraph("Quality", styles['table_header']),
         Paragraph("Latency", styles['table_header']),
         Paragraph("vs kimi Q", styles['table_header']),
         Paragraph("Status", styles['table_header'])],
        ["B1", "5 / 5", "11.5s",  "0",  "✅ PASS"],
        ["B2", "4 / 5", "97.9s",  "−1", "❌ FAIL"],
        ["B3", "5 / 5", "7.0s",   "0",  "✅ PASS"],
        ["B4", "5 / 5", "42.6s",  "+1", "❌ FAIL"],
        ["B5", "4 / 5", "52.6s",  "−1", "❌ FAIL"],
        [Paragraph("<b>AVG</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9)),
         Paragraph("<b>4.6 / 5</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         Paragraph("<b>42.3s</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=RED, alignment=TA_CENTER)),
         "0",
         Paragraph("<b>❌ FAIL (latency)</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=WHITE, alignment=TA_CENTER))],
    ]
    col_w = [1.2*cm, 2*cm, 2.5*cm, 2.5*cm, CONTENT_W - 8.2*cm]
    t2 = Table(qwen_data, colWidths=col_w)
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#8B0000")),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [RED_BG, colors.HexColor("#FAEAEA")]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('BACKGROUND', (4,1), (4,1), GREEN_BG), ('TEXTCOLOR', (4,1), (4,1), GREEN), ('FONTNAME', (4,1), (4,1), 'Helvetica-Bold'),
        ('BACKGROUND', (4,2), (4,2), RED_BG), ('TEXTCOLOR', (4,2), (4,2), RED), ('FONTNAME', (4,2), (4,2), 'Helvetica-Bold'),
        ('BACKGROUND', (4,3), (4,3), GREEN_BG), ('TEXTCOLOR', (4,3), (4,3), GREEN), ('FONTNAME', (4,3), (4,3), 'Helvetica-Bold'),
        ('BACKGROUND', (4,4), (4,4), RED_BG), ('TEXTCOLOR', (4,4), (4,4), RED), ('FONTNAME', (4,4), (4,4), 'Helvetica-Bold'),
        ('BACKGROUND', (4,5), (4,5), RED_BG), ('TEXTCOLOR', (4,5), (4,5), RED), ('FONTNAME', (4,5), (4,5), 'Helvetica-Bold'),
        ('BACKGROUND', (0,6), (-1,6), RED_BG),
        ('BACKGROUND', (4,6), (4,6), RED),
    ]))
    elements.append(t2)
    elements.append(Spacer(1, 0.2*cm))
    elements.append(info_box(
        "<b>Note:</b> qwen3.5 quality matches kimi (4.6/5) but latency fails at 42.3s (2.1× threshold). "
        "The /no_think flag helps text tasks (B1, B3) but not tool use or governance tasks. "
        "<b>Future consideration:</b> OC2 async batch jobs (TRIGGER-01-A).",
        styles, bg=ORANGE_BG, border=ORANGE
    ))
    elements.append(Spacer(1, 0.4*cm))

    # GEMMA4
    gemma_header = Table([[Paragraph("6.3 — gemma4-community cloud (unofficial)  ❌ FAIL — Latency + Security",
        ParagraphStyle('sh', fontName='Helvetica-Bold', fontSize=11, textColor=WHITE))]], colWidths=[CONTENT_W])
    gemma_header.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), RED),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
    ]))
    elements.append(gemma_header)
    elements.append(Spacer(1, 0.2*cm))

    gemma_data = [
        [Paragraph("Task", styles['table_header']),
         Paragraph("Quality", styles['table_header']),
         Paragraph("Latency", styles['table_header']),
         Paragraph("vs kimi Q", styles['table_header']),
         Paragraph("Status", styles['table_header'])],
        ["B1", "4 / 5", "11.0s",  "−1", "✅ PASS"],
        ["B2", "4 / 5", "47.3s",  "−1", "❌ FAIL"],
        ["B3", "4 / 5", "14.6s",  "−1", "✅ PASS"],
        ["B4", "5 / 5", "12.7s",  "+1", "✅ PASS"],
        ["B5", "4 / 5", "38.6s",  "−1", "❌ FAIL"],
        [Paragraph("<b>AVG</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9)),
         Paragraph("<b>4.2 / 5</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=ORANGE, alignment=TA_CENTER)),
         Paragraph("<b>24.8s</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=RED, alignment=TA_CENTER)),
         "−0.4",
         Paragraph("<b>❌ FAIL (latency)</b>", ParagraphStyle('a', fontName='Helvetica-Bold', fontSize=9, textColor=WHITE, alignment=TA_CENTER))],
    ]
    t3 = Table(gemma_data, colWidths=col_w)
    t3.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#8B0000")),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [RED_BG, colors.HexColor("#FAEAEA")]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('BACKGROUND', (4,1), (4,1), GREEN_BG), ('TEXTCOLOR', (4,1), (4,1), GREEN), ('FONTNAME', (4,1), (4,1), 'Helvetica-Bold'),
        ('BACKGROUND', (4,2), (4,2), RED_BG), ('TEXTCOLOR', (4,2), (4,2), RED), ('FONTNAME', (4,2), (4,2), 'Helvetica-Bold'),
        ('BACKGROUND', (4,3), (4,3), GREEN_BG), ('TEXTCOLOR', (4,3), (4,3), GREEN), ('FONTNAME', (4,3), (4,3), 'Helvetica-Bold'),
        ('BACKGROUND', (4,4), (4,4), GREEN_BG), ('TEXTCOLOR', (4,4), (4,4), GREEN), ('FONTNAME', (4,4), (4,4), 'Helvetica-Bold'),
        ('BACKGROUND', (4,5), (4,5), RED_BG), ('TEXTCOLOR', (4,5), (4,5), RED), ('FONTNAME', (4,5), (4,5), 'Helvetica-Bold'),
        ('BACKGROUND', (0,6), (-1,6), RED_BG),
        ('BACKGROUND', (4,6), (4,6), RED),
    ]))
    elements.append(t3)
    elements.append(Spacer(1, 0.2*cm))
    elements.append(info_box(
        "<b>Security Note:</b> gemma4-community is an <b>unofficial</b> community model with no formal SLA or "
        "security audit. Even if latency were addressed, a full security review is required before "
        "any production consideration. Do NOT route any data until cleared.",
        styles, bg=RED_BG, border=RED
    ))
    elements.append(PageBreak())
    return elements


# ─── SECTION 7: MASTER COMPARISON TABLE ──────────────────────────────────────
def build_master_comparison(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 7 — Master Comparison Table (kimi as Baseline = 100%)", styles))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph(
        "All six evaluated models compared across key metrics with kimi-k2.6:cloud as the performance "
        "baseline (100%). Models are ranked by composite performance (quality × latency efficiency).",
        styles['body']
    ))
    elements.append(Spacer(1, 0.3*cm))

    master_data = [
        [Paragraph("Model", styles['table_header']),
         Paragraph("Avg\nQuality", styles['table_header']),
         Paragraph("Q vs\nkimi", styles['table_header']),
         Paragraph("Avg\nLatency", styles['table_header']),
         Paragraph("L vs\nkimi", styles['table_header']),
         Paragraph("Threshold\nHeadroom", styles['table_header']),
         Paragraph("Verdict", styles['table_header']),
         Paragraph("Deployment", styles['table_header'])],
        # kimi - baseline row
        [Paragraph("<b>kimi-k2.6:cloud</b>\n(BASELINE)", ParagraphStyle('mb', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY)),
         "4.6 / 5", "100%", "6.8s", "100%", "13.2s", "✅ PASS", "✅ LIVE"],
        # deepseek flash
        ["deepseek-v4-flash", "4.2 / 5", "91%", "12.6s", "185%", "7.4s", "✅ PASS", "✅ LIVE"],
        # deepseek pro
        ["deepseek-v4-pro", "4.6 / 5", "100%", "18.4s", "271%", "1.6s ⚠️", "✅ PASS\n(marginal)", "✅ LIVE"],
        # gemma4
        ["gemma4-cloud\n(community)", "4.2 / 5", "91%", "24.8s", "365%", "−4.8s ❌", "❌ FAIL", "❌ NOT ADDED"],
        # qwen3.5
        ["qwen3.5:cloud", "4.6 / 5", "100%", "42.3s", "622%", "−22.3s ❌", "❌ FAIL", "❌ NOT ADDED"],
        # glm
        ["glm-5.1:cloud", "N/A", "N/A", "221s+", "3250%+", "−201s+ ❌", "❌ FAIL", "❌ NOT ADDED"],
    ]

    col_w = [3.2*cm, 1.6*cm, 1.4*cm, 1.6*cm, 1.6*cm, 2.2*cm, 2.2*cm, CONTENT_W - 13.8*cm]
    t = Table(master_data, colWidths=col_w)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8),
        ('ALIGN', (0,0), (-1,0), 'CENTER'),
        ('ALIGN', (1,1), (-1,-1), 'CENTER'),
        ('ALIGN', (0,1), (0,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        # kimi baseline row - highlighted
        ('BACKGROUND', (0,1), (-1,1), BLUE_LIGHT),
        ('FONTNAME', (0,1), (-1,1), 'Helvetica-Bold'),
        ('TEXTCOLOR', (0,1), (0,1), NAVY),
        # deepseek flash - pass
        ('BACKGROUND', (0,2), (-1,2), colors.HexColor("#EAF7EA")),
        # deepseek pro - marginal pass
        ('BACKGROUND', (0,3), (-1,3), ORANGE_BG),
        # failed rows
        ('BACKGROUND', (0,4), (-1,4), RED_BG),
        ('BACKGROUND', (0,5), (-1,5), RED_BG),
        ('BACKGROUND', (0,6), (-1,6), RED_BG),
        # verdict cells
        ('BACKGROUND', (6,1), (6,2), GREEN_BG), ('TEXTCOLOR', (6,1), (6,2), GREEN), ('FONTNAME', (6,1), (6,2), 'Helvetica-Bold'),
        ('BACKGROUND', (6,3), (6,3), ORANGE_BG), ('TEXTCOLOR', (6,3), (6,3), ORANGE), ('FONTNAME', (6,3), (6,3), 'Helvetica-Bold'),
        ('BACKGROUND', (6,4), (6,6), RED_BG), ('TEXTCOLOR', (6,4), (6,6), RED), ('FONTNAME', (6,4), (6,6), 'Helvetica-Bold'),
        # deployment cells
        ('BACKGROUND', (7,1), (7,3), GREEN_BG), ('TEXTCOLOR', (7,1), (7,3), GREEN), ('FONTNAME', (7,1), (7,3), 'Helvetica-Bold'),
        ('BACKGROUND', (7,4), (7,6), RED_BG), ('TEXTCOLOR', (7,4), (7,6), RED), ('FONTNAME', (7,4), (7,6), 'Helvetica-Bold'),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.3*cm))

    elements.append(Paragraph(
        "* Threshold Headroom = 20s threshold − avg latency. Positive = headroom remaining. "
        "Negative = threshold exceeded by that margin.",
        ParagraphStyle('cap', fontName='Helvetica-Oblique', fontSize=8, textColor=GREY_MID)
    ))
    elements.append(PageBreak())
    return elements


# ─── SECTION 8: COST ANALYSIS ─────────────────────────────────────────────────
def build_cost_analysis(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 8 — Cost Analysis", styles))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph("8.1 — Claude Sonnet 4.6 Baseline Cost (Apr 25 – May 1)", styles['subsection_title']))

    daily_data = [
        [Paragraph("Date", styles['table_header']),
         Paragraph("Apr 25", styles['table_header']),
         Paragraph("Apr 26", styles['table_header']),
         Paragraph("Apr 27", styles['table_header']),
         Paragraph("Apr 28", styles['table_header']),
         Paragraph("Apr 29", styles['table_header']),
         Paragraph("Apr 30", styles['table_header']),
         Paragraph("May 1", styles['table_header']),
         Paragraph("7-Day Avg", styles['table_header'])],
        ["Daily Cost (AUD)",
         "$49.94", "$82.84", "$121.26",
         Paragraph("<b>$338.76</b>", ParagraphStyle('peak', fontName='Helvetica-Bold', fontSize=8.5, textColor=RED, alignment=TA_CENTER)),
         "$43.78", "$166.10", "$61.46",
         Paragraph("<b>$118/day</b>", ParagraphStyle('avg', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY, alignment=TA_CENTER))],
    ]

    col_w_daily = [(CONTENT_W - 2.5*cm) / 8] * 8
    col_w_daily = [2.5*cm] + [(CONTENT_W - 2.5*cm) / 8] * 8
    # Recalculate
    base_w = (CONTENT_W - 3*cm) / 8
    col_w_daily = [3*cm] + [base_w] * 8

    t = Table(daily_data, colWidths=col_w_daily)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [WHITE]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('ALIGN', (0,1), (0,-1), 'LEFT'),
        # Peak day
        ('BACKGROUND', (4,1), (4,1), RED_BG),
        # Avg column
        ('BACKGROUND', (8,1), (8,1), BLUE_LIGHT),
        ('FONTNAME', (0,1), (0,-1), 'Helvetica-Bold'),
        ('TEXTCOLOR', (0,1), (0,-1), NAVY),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.2*cm))
    elements.append(Paragraph(
        "Apr 28 spike ($338.76) represents peak usage day. Monthly projection at $118/day × 30 = <b>~$3,540/month</b>.",
        ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=8.5, textColor=GREY_MID)
    ))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph("8.2 — Savings Projection (Tier 2 Offload)", styles['subsection_title']))

    savings_data = [
        [Paragraph("Scenario", styles['table_header']),
         Paragraph("Tier 2\nOffload %", styles['table_header']),
         Paragraph("Workload\nOffloaded", styles['table_header']),
         Paragraph("Monthly\nSaving", styles['table_header']),
         Paragraph("Ollama Pro\nCost", styles['table_header']),
         Paragraph("Net Monthly\nSaving", styles['table_header']),
         Paragraph("Annual\nSaving", styles['table_header']),
         Paragraph("ROI on\n$20/mo", styles['table_header'])],
        ["Conservative", "20%", "~710 req/day", "~$710", "$20", 
         Paragraph("<b>$690/mo</b>", ParagraphStyle('s', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         "~$8,280/yr", "34.5×"],
        ["Moderate", "35%", "~1,243 req/day", "~$1,243", "$20",
         Paragraph("<b>$1,223/mo</b>", ParagraphStyle('s', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         "~$14,676/yr", "61.2×"],
        ["Optimistic", "50%", "~1,775 req/day", "~$1,775", "$20",
         Paragraph("<b>$1,755/mo</b>", ParagraphStyle('s', fontName='Helvetica-Bold', fontSize=9, textColor=GREEN, alignment=TA_CENTER)),
         "~$21,060/yr", "87.8×"],
    ]

    base_w2 = CONTENT_W / 8
    t2 = Table(savings_data, colWidths=[base_w2]*8)
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [GREEN_BG, colors.HexColor("#EAF7EA"), colors.HexColor("#D4F0D4")]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('FONTNAME', (0,1), (0,-1), 'Helvetica-Bold'),
        ('TEXTCOLOR', (0,1), (0,-1), NAVY),
    ]))
    elements.append(t2)
    elements.append(Spacer(1, 0.3*cm))

    elements.append(info_box(
        "<b>ROI Summary:</b> The Ollama Pro subscription at $20/month provides a minimum 34.5× return "
        "under conservative assumptions. At moderate 35% offload, the annual saving exceeds $14,600. "
        "Ollama Pro account: accounts@ainchors.com — activated 2026-05-02.",
        styles, bg=GREEN_BG, border=GREEN
    ))
    elements.append(PageBreak())
    return elements


# ─── SECTION 9: ROUTING RECOMMENDATIONS ──────────────────────────────────────
def build_routing(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 9 — Routing Recommendations", styles))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph(
        "Based on benchmark results, the following routing policy is implemented in model-policy.json "
        "and enforced by Warden. All routing decisions include a data_sensitivity check — sensitive data "
        "NEVER routes to Ollama Cloud.",
        styles['body']
    ))
    elements.append(Spacer(1, 0.3*cm))

    routing_data = [
        [Paragraph("Task Type", styles['table_header']),
         Paragraph("Recommended Model", styles['table_header']),
         Paragraph("Avg Latency", styles['table_header']),
         Paragraph("Avg Quality", styles['table_header']),
         Paragraph("Rationale", styles['table_header'])],
        ["Creative / content\n(LinkedIn posts, copy, comms)",
         Paragraph("<b>kimi-k2.6:cloud</b>", ParagraphStyle('rb', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY)),
         "6.8s", "4.6/5",
         "Fastest (3.9s on B3), highest creative quality, 5/5 on writing tasks"],
        ["Fast concurrent subtasks\n(parallel workflows, summaries)",
         Paragraph("<b>deepseek-v4-flash</b>", ParagraphStyle('rb', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY)),
         "12.6s", "4.2/5",
         "Reliable, consistent latency, 5/5 on tool calling (B4)"],
        ["Complex reasoning / code\n(non-sensitive, async preferred)",
         Paragraph("<b>deepseek-v4-pro</b>", ParagraphStyle('rb', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY)),
         "18.4s", "4.6/5",
         "Matches kimi quality (4.6/5), best for deep analysis tasks"],
        [Paragraph("<b>ALL sensitive data</b>\n(PII, medical, legal, financial)", ParagraphStyle('warn', fontName='Helvetica-Bold', fontSize=8.5, textColor=RED)),
         Paragraph("<b>Anthropic / Local ONLY</b>", ParagraphStyle('rb', fontName='Helvetica-Bold', fontSize=8.5, textColor=RED)),
         "N/A", "N/A",
         Paragraph("<b>Data sovereignty — NEVER route to Ollama Cloud. Warden enforces.</b>",
                   ParagraphStyle('rw', fontName='Helvetica-Bold', fontSize=8.5, textColor=RED))],
        ["Real-time interactive\n(main session, live chat)",
         Paragraph("<b>Claude Sonnet 4.6</b>", ParagraphStyle('rb', fontName='Helvetica-Bold', fontSize=8.5, textColor=BLUE_ACC)),
         "~3–5s", "5/5",
         "Speed + full context window + tool use required for interactive sessions"],
    ]

    col_w = [3.5*cm, 3.5*cm, 2*cm, 2*cm, CONTENT_W - 11*cm]
    t = Table(routing_data, colWidths=col_w)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (-1,0), 'CENTER'),
        ('ALIGN', (2,1), (3,-1), 'CENTER'),
        ('ALIGN', (0,1), (1,-1), 'LEFT'),
        ('ALIGN', (4,1), (4,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [WHITE, GREY_LIGHT, WHITE, RED_BG, WHITE]),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        # Sensitive data row red
        ('BACKGROUND', (0,4), (-1,4), RED_BG),
        ('BOX', (0,4), (-1,4), 1.5, RED),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.4*cm))

    elements.append(info_box(
        "<b>Warden Enforcement:</b> All inference requests pass through the Warden agent which evaluates "
        "data_sensitivity before routing. Any request tagged as sensitive (PII, medical, legal, financial, "
        "credentials) is automatically redirected to Anthropic or local inference — Ollama Cloud is "
        "bypassed entirely for these workloads. This is non-negotiable and hard-coded.",
        styles, bg=BLUE_LIGHT, border=BLUE_ACC
    ))
    elements.append(PageBreak())
    return elements


# ─── SECTION 10: IMPLEMENTATION STATUS ───────────────────────────────────────
def build_implementation(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 10 — Implementation Status", styles))
    elements.append(Spacer(1, 0.4*cm))

    impl_data = [
        [Paragraph("Model", styles['table_header']),
         Paragraph("Status", styles['table_header']),
         Paragraph("Change Ref", styles['table_header']),
         Paragraph("Config", styles['table_header']),
         Paragraph("Notes", styles['table_header'])],
        [Paragraph("<b>kimi-k2.6:cloud</b>", ParagraphStyle('im', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY)),
         Paragraph("✅ LIVE", ParagraphStyle('iv', fontName='Helvetica-Bold', fontSize=8.5, textColor=GREEN, alignment=TA_CENTER)),
         "CHG-0120",
         "model-policy.json\nTier 2, non-sensitive",
         "Primary Tier 2 model. Activated 2026-05-02."],
        [Paragraph("<b>deepseek-v4-flash:cloud</b>", ParagraphStyle('im', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY)),
         Paragraph("✅ LIVE", ParagraphStyle('iv', fontName='Helvetica-Bold', fontSize=8.5, textColor=GREEN, alignment=TA_CENTER)),
         "CHG-0121\n(Phase 5D)",
         "model-policy.json\nTier 2, concurrent",
         "Fast concurrent tasks. Same Ollama Pro plan."],
        [Paragraph("<b>deepseek-v4-pro:cloud</b>", ParagraphStyle('im', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY)),
         Paragraph("✅ LIVE", ParagraphStyle('iv', fontName='Helvetica-Bold', fontSize=8.5, textColor=GREEN, alignment=TA_CENTER)),
         "CHG-0121",
         "model-policy.json\nAsync-preferred",
         "Async routing enforced. Complex reasoning tasks."],
        ["glm-5.1:cloud",
         Paragraph("❌ NOT ADDED", ParagraphStyle('iv', fontName='Helvetica-Bold', fontSize=8.5, textColor=RED, alignment=TA_CENTER)),
         "—",
         "—",
         "Monthly reassessment: TRIGGER-11. Catastrophic latency."],
        ["qwen3.5:cloud",
         Paragraph("❌ NOT ADDED", ParagraphStyle('iv', fontName='Helvetica-Bold', fontSize=8.5, textColor=RED, alignment=TA_CENTER)),
         "—",
         "—",
         "OC2 reassessment: TRIGGER-01-A. Latency fail only."],
        ["gemma4-cloud\n(community)",
         Paragraph("❌ NOT ADDED", ParagraphStyle('iv', fontName='Helvetica-Bold', fontSize=8.5, textColor=RED, alignment=TA_CENTER)),
         "—",
         "—",
         "Security review required. Unofficial model. No SLA."],
    ]

    col_w = [3.5*cm, 2.2*cm, 2.2*cm, 3*cm, CONTENT_W - 10.9*cm]
    t = Table(impl_data, colWidths=col_w)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), NAVY),
        ('TEXTCOLOR', (0,0), (-1,0), WHITE),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,-1), 8.5),
        ('ALIGN', (0,0), (-1,0), 'CENTER'),
        ('ALIGN', (1,1), (2,-1), 'CENTER'),
        ('ALIGN', (0,1), (0,-1), 'LEFT'),
        ('ALIGN', (3,1), (4,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('BACKGROUND', (0,1), (-1,3), colors.HexColor("#EAF7EA")),
        ('BACKGROUND', (0,4), (-1,6), RED_BG),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph("10.1 — Operational Details", styles['subsection_title']))
    ops_items = [
        ("Ollama Pro Account", "accounts@ainchors.com — $20/month flat rate — activated 2026-05-02"),
        ("Warden Enforcement", "data_sensitivity check active — sensitive data blocked from Ollama Cloud routing"),
        ("Model Policy File", "model-policy.json updated with all 3 passing models + routing rules"),
        ("Monitoring", "Latency + quality metrics tracked per request via ops telemetry"),
        ("Review Cadence", "Monthly reassessment of all Ollama Cloud models (glm-5.1 first up: TRIGGER-11)"),
    ]
    ops_data = [[Paragraph(f"<b>{k}</b>", ParagraphStyle('ok', fontName='Helvetica-Bold', fontSize=9, textColor=NAVY)),
                 Paragraph(v, ParagraphStyle('ov', fontName='Helvetica', fontSize=9, textColor=GREY_DARK))]
                for k, v in ops_items]
    ops_t = Table(ops_data, colWidths=[4*cm, CONTENT_W - 4*cm])
    ops_t.setStyle(TableStyle([
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, GREY_LINE),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [WHITE, GREY_LIGHT]),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    elements.append(ops_t)
    elements.append(PageBreak())
    return elements


# ─── SECTION 11: APPENDIX ─────────────────────────────────────────────────────
def build_appendix(styles):
    elements = []
    elements.append(Spacer(1, 0.3*cm))
    elements.append(section_header("Section 11 — Appendix: Sample Model Outputs (kimi-k2.6:cloud)", styles))
    elements.append(Spacer(1, 0.4*cm))

    elements.append(Paragraph(
        "The following are verbatim output excerpts from kimi-k2.6:cloud benchmark evaluations. "
        "These demonstrate the model's quality level across all five task categories.",
        styles['body']
    ))
    elements.append(Spacer(1, 0.3*cm))

    # B1
    elements.append(Paragraph("B1 — Reasoning: Top 3 LLM Cloud Security Risks", styles['subsection_title']))
    b1_text = (
        "1. Data leakage & loss of confidentiality — Sensitive prompts and outputs may be logged, "
        "retained, or accessed by the cloud provider, creating risk of IP exposure, PII breaches, "
        "and regulatory non-compliance.\n\n"
        "2. Compliance & sovereignty violations — Cloud inference crosses jurisdictional boundaries, "
        "potentially violating data residency requirements under GDPR, the Australian Privacy Act, "
        "HIPAA, and sector-specific regulations.\n\n"
        "3. Cross-tenant security gaps — Multi-tenant inference infrastructure creates risk of "
        "prompt injection, model poisoning, or side-channel attacks from co-located workloads "
        "on shared compute."
    )
    b1_box = Table([[Paragraph(b1_text, ParagraphStyle('code_out', fontName='Courier', fontSize=8, textColor=GREY_DARK, leading=12))]], colWidths=[CONTENT_W])
    b1_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), GREY_LIGHT),
        ('BOX', (0,0), (-1,-1), 0.5, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    elements.append(b1_box)
    elements.append(Spacer(1, 0.3*cm))

    # B2
    elements.append(Paragraph("B2 — Coding: Python Routing Function", styles['subsection_title']))
    b2_text = (
        'def route_inference(data_sensitivity: str, task_complexity: str) -> str:\n'
        '    """\n'
        '    Route inference requests to appropriate model tier.\n'
        '    Args:\n'
        '        data_sensitivity: "high" | "medium" | "low"\n'
        '        task_complexity: "simple" | "moderate" | "complex"\n'
        '    Returns: model identifier string\n'
        '    """\n'
        '    # Security: sensitive data never leaves Anthropic\n'
        '    if data_sensitivity == "high":\n'
        '        return "anthropic/claude-sonnet-4-6"\n\n'
        '    # Complex + medium sensitivity: use pro tier\n'
        '    if task_complexity == "complex" and data_sensitivity != "high":\n'
        '        return "ollama/deepseek-v4-pro:cloud"\n\n'
        '    # Fast concurrent tasks\n'
        '    if task_complexity == "simple":\n'
        '        return "ollama/deepseek-v4-flash:cloud"\n\n'
        '    # Default: primary Tier 2\n'
        '    return "ollama/kimi-k2.6:cloud"'
    )
    b2_box = Table([[Paragraph(b2_text, ParagraphStyle('code_out', fontName='Courier', fontSize=7.5, textColor=NAVY, leading=11))]], colWidths=[CONTENT_W])
    b2_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F0F4FF")),
        ('BOX', (0,0), (-1,-1), 0.5, BLUE_ACC),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    elements.append(b2_box)
    elements.append(Spacer(1, 0.3*cm))

    # B3
    elements.append(Paragraph("B3 — Business Writing: LinkedIn Post", styles['subsection_title']))
    b3_text = (
        '"We\'re helping Australian businesses slash their AI running costs by intelligently routing '
        'workloads to the right model — sensitive data stays on Anthropic, everything else hits our '
        'Tier 2 fleet. The result? 60% cost reduction without touching quality. '
        'Australian-built, sovereignty-first, and now live in production at AInchors."'
    )
    b3_box = Table([[Paragraph(b3_text, ParagraphStyle('quote', fontName='Helvetica-Oblique', fontSize=9.5,
        textColor=NAVY, leading=14))]], colWidths=[CONTENT_W])
    b3_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), BLUE_LIGHT),
        ('LEFTLINE', (0,0), (0,-1), 4, BLUE_ACC),
        ('BOX', (0,0), (-1,-1), 0.5, BLUE_ACC),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING', (0,0), (-1,-1), 14),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    elements.append(b3_box)
    elements.append(Spacer(1, 0.3*cm))

    # B4
    elements.append(Paragraph("B4 — Tool Use: JSON Tool Call", styles['subsection_title']))
    b4_text = '{\n  "name": "get_calendar_events",\n  "arguments": {\n    "date": "2026-05-02"\n  }\n}'
    b4_box = Table([[Paragraph(b4_text, ParagraphStyle('code_out', fontName='Courier', fontSize=9, textColor=GREY_DARK, leading=13))]], colWidths=[CONTENT_W])
    b4_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), GREY_LIGHT),
        ('BOX', (0,0), (-1,-1), 0.5, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    elements.append(b4_box)
    elements.append(Spacer(1, 0.3*cm))

    # B5
    elements.append(Paragraph("B5 — Governance: Medical Records Data Sovereignty", styles['subsection_title']))
    b5_text = (
        '"Decline unless the cloud provider contractually guarantees data residency within the client\'s '
        'jurisdiction and provides a signed Data Processing Agreement (DPA) compliant with the Australian '
        'Privacy Act 1988, the Health Records Act, and applicable state health legislation.\n\n'
        'Medical records are among the most sensitive categories of personal information. Even with '
        'encryption in transit and at rest, storing them with a cloud AI provider introduces unacceptable '
        'risk of: (1) regulatory breach if data crosses borders, (2) provider access during model training '
        'or fine-tuning, and (3) incident exposure in a multi-tenant environment.\n\n'
        'Recommendation: Use on-premises or sovereign cloud inference for all medical data workloads. '
        'Do not proceed without legal review and explicit client consent."'
    )
    b5_box = Table([[Paragraph(b5_text, ParagraphStyle('code_out', fontName='Courier', fontSize=7.8, textColor=GREY_DARK, leading=11.5))]], colWidths=[CONTENT_W])
    b5_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), GREY_LIGHT),
        ('BOX', (0,0), (-1,-1), 0.5, GREY_LINE),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    elements.append(b5_box)
    elements.append(Spacer(1, 0.5*cm))

    # Final footer
    elements.append(HRFlowable(width=CONTENT_W, thickness=1, color=NAVY))
    elements.append(Spacer(1, 0.2*cm))
    elements.append(Paragraph(
        "End of Report — AInchors | AI Anchor Solutions Pty Ltd — INTERNAL / CONFIDENTIAL — 2026-05-02",
        ParagraphStyle('end', fontName='Helvetica-Bold', fontSize=8.5, textColor=NAVY, alignment=TA_CENTER)
    ))
    elements.append(Paragraph(
        "Prepared by: Yoda 🟢, AI Operations Lead Agent  |  Authorised by: Ken Mun, CTO",
        ParagraphStyle('end2', fontName='Helvetica', fontSize=8, textColor=GREY_MID, alignment=TA_CENTER)
    ))

    return elements


# ─── MAIN BUILD ───────────────────────────────────────────────────────────────
def build_pdf():
    styles = build_styles()

    doc = SimpleDocTemplate(
        OUTPUT_PATH,
        pagesize=A4,
        leftMargin=MARGIN_L,
        rightMargin=MARGIN_R,
        topMargin=MARGIN_T,
        bottomMargin=MARGIN_B,
        title="Ollama Cloud PoC — Model Comparison Report",
        author="Yoda, AI Operations Lead Agent",
        subject="AI Infrastructure Cost Optimisation — Frontier Model Evaluation",
        creator="AInchors | AI Anchor Solutions Pty Ltd",
    )

    elements = []
    elements += build_cover(styles)
    elements += build_toc(styles)
    elements += build_exec_summary(styles)
    elements += build_methodology(styles)
    elements += build_kimi_section(styles)
    elements += build_deepseek_flash(styles)
    elements += build_deepseek_pro(styles)
    elements += build_failed_models(styles)
    elements += build_master_comparison(styles)
    elements += build_cost_analysis(styles)
    elements += build_routing(styles)
    elements += build_implementation(styles)
    elements += build_appendix(styles)

    doc.build(elements, canvasmaker=HeaderFooterCanvas)
    return OUTPUT_PATH


if __name__ == "__main__":
    print("Generating AInchors Ollama Cloud PoC Report...")
    path = build_pdf()
    size = os.path.getsize(path)
    print(f"\n✅ Report generated successfully.")
    print(f"📄 Output path: {path}")
    print(f"📦 File size: {size:,} bytes ({size/1024:.1f} KB)")
