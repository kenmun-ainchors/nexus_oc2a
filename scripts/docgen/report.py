#!/usr/bin/env python3
"""
report.py — AInchors Discovery Report (PDF)
Usage: python3 report.py --title "Title" --output /path/out.pdf [--data /path/data.json]
"""
import argparse
import json
import sys
from datetime import date
from fpdf import FPDF


BRAND_DARK = (13, 17, 23)
BRAND_BLUE = (68, 114, 196)
BRAND_LIGHT_GREY = (245, 245, 245)
SEVERITY_COLORS = {
    'critical': (192, 0, 0),
    'high':     (255, 80, 0),
    'medium':   (255, 192, 0),
    'low':      (0, 176, 80),
    'info':     (68, 114, 196),
}


class ReportPDF(FPDF):
    def __init__(self, report_title, doc_date):
        super().__init__()
        self.report_title = report_title
        self.doc_date = doc_date
        self.set_auto_page_break(auto=True, margin=20)

    def header(self):
        # Header bar
        self.set_fill_color(*BRAND_DARK)
        self.rect(0, 0, 210, 18, 'F')
        self.set_font('Helvetica', 'B', 14)
        self.set_text_color(255, 255, 255)
        self.set_y(4)
        self.set_x(10)
        self.cell(80, 10, 'AInchors', align='L')
        self.set_font('Helvetica', '', 10)
        self.set_x(90)
        self.cell(80, 10, self.report_title, align='C')
        self.set_x(170)
        self.cell(30, 10, self.doc_date, align='R')
        self.set_text_color(0, 0, 0)
        self.ln(20)

    def footer(self):
        self.set_y(-15)
        self.set_font('Helvetica', 'I', 8)
        self.set_text_color(128, 128, 128)
        self.cell(0, 10, f'AInchors | ainchors.com | Page {self.page_no()}', align='C')
        self.set_text_color(0, 0, 0)

    def section_title(self, text):
        self.set_font('Helvetica', 'B', 13)
        self.set_text_color(*BRAND_DARK)
        self.set_fill_color(*BRAND_LIGHT_GREY)
        self.cell(0, 9, text, ln=True, fill=True)
        self.set_text_color(0, 0, 0)
        self.ln(2)

    def body_text(self, text):
        self.set_font('Helvetica', '', 11)
        self.multi_cell(0, 6, text)
        self.ln(3)

    def bullet(self, text):
        self.set_font('Helvetica', '', 11)
        self.set_x(self.get_x() + 5)
        self.multi_cell(0, 6, f'\u2022  {text}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--title', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--data', default=None)
    args = parser.parse_args()

    data = {}
    if args.data:
        with open(args.data) as f:
            data = json.load(f)

    client_name = data.get('clientName', 'Valued Client')
    title = data.get('title', args.title)
    doc_date = data.get('date', date.today().strftime('%d %B %Y'))
    summary = data.get('summary',
        'This discovery report presents the findings from our initial engagement with your organisation. '
        'The assessment covered key operational processes, technology stack, data maturity, and AI readiness. '
        'The findings below represent priority areas for improvement and transformation.'
    )
    findings = data.get('findings', [
        {'finding': 'Manual data entry across 3 core systems', 'severity': 'high', 'recommendation': 'Implement API integration layer'},
        {'finding': 'No unified data warehouse', 'severity': 'critical', 'recommendation': 'Deploy cloud data platform (BigQuery/Snowflake)'},
        {'finding': 'Limited AI/ML capability in-house', 'severity': 'medium', 'recommendation': 'Structured upskilling program + external CoE'},
        {'finding': 'Inconsistent process documentation', 'severity': 'low', 'recommendation': 'Process mapping workshop and wiki setup'},
    ])
    next_steps = data.get('nextSteps', [
        'Present findings to executive leadership team',
        'Prioritise top 3 initiatives with business owners',
        'Develop detailed business case for Phase 1',
        'Confirm budget allocation for FY26',
        'Schedule follow-up in 2 weeks',
    ])

    pdf = ReportPDF(title, doc_date)
    pdf.add_page()

    # Client + title block
    pdf.set_font('Helvetica', 'B', 20)
    pdf.set_text_color(*BRAND_DARK)
    pdf.cell(0, 12, title, ln=True, align='C')
    pdf.set_font('Helvetica', '', 12)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 7, f'Prepared for: {client_name}  |  {doc_date}', ln=True, align='C')
    pdf.set_text_color(0, 0, 0)
    pdf.ln(8)

    # Executive Summary
    pdf.section_title('Executive Summary')
    pdf.body_text(summary)

    # Findings table
    pdf.section_title('Findings')
    pdf.set_font('Helvetica', 'B', 10)
    pdf.set_fill_color(*BRAND_BLUE)
    pdf.set_text_color(255, 255, 255)
    col_w = [80, 28, 82]
    pdf.cell(col_w[0], 8, 'Finding', border=1, fill=True)
    pdf.cell(col_w[1], 8, 'Severity', border=1, fill=True)
    pdf.cell(col_w[2], 8, 'Recommendation', border=1, fill=True, ln=True)
    pdf.set_text_color(0, 0, 0)

    for f in findings:
        pdf.set_font('Helvetica', '', 10)
        severity = f.get('severity', 'info').lower()
        sev_color = SEVERITY_COLORS.get(severity, (80, 80, 80))

        # Finding cell
        x = pdf.get_x()
        y = pdf.get_y()
        pdf.multi_cell(col_w[0], 6, f.get('finding', ''), border=1)
        h = pdf.get_y() - y

        pdf.set_xy(x + col_w[0], y)
        pdf.set_text_color(*sev_color)
        pdf.set_font('Helvetica', 'B', 10)
        pdf.cell(col_w[1], h, severity.upper(), border=1)
        pdf.set_text_color(0, 0, 0)
        pdf.set_font('Helvetica', '', 10)
        pdf.set_xy(x + col_w[0] + col_w[1], y)
        pdf.multi_cell(col_w[2], 6, f.get('recommendation', ''), border=1)
        if pdf.get_y() < y + h:
            pdf.set_y(y + h)

    pdf.ln(5)

    # Next Steps
    pdf.set_x(pdf.l_margin)
    pdf.section_title('Next Steps')
    for i, step in enumerate(next_steps, 1):
        pdf.set_font('Helvetica', '', 11)
        pdf.set_x(pdf.l_margin)
        pdf.multi_cell(0, 7, f'{i}. {step}')

    pdf.output(args.output)
    print(f'Report saved: {args.output}')


if __name__ == '__main__':
    main()
