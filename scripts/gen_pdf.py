#!/usr/bin/env python3
from fpdf import FPDF

class PDF(FPDF):
    def header(self):
        self.set_font('helvetica', 'B', 12)
        self.cell(0, 10, 'AInCHORS Report - Confidental', 0, 1, 'R')
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font('helvetica', 'I', 8)
        self.cell(0, 10, f'Page {self.page_no()}', 0, 0, 'C')

def create_pdf_template(path, title, subtitle, author):
    pdf = PDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()
    
    # Cover Page
    pdf.set_font('helvetica', 'B', 24)
    pdf.cell(0, 60, title, 0, 1, 'C')
    
    pdf.set_font('helvetica', '', 14)
    pdf.cell(0, 10, subtitle, 0, 1, 'C')
    
    pdf.ln(40)
    pdf.set_font('helvetica', '', 12)
    pdf.cell(0, 10, f"Author: {author}", 0, 1, 'C')
    pdf.cell(0, 10, "Date: 2026-05-21", 0, 1, 'C')
    pdf.cell(0, 10, "[AInCHORS PLACEHOLDER LOGO]", 0, 1, 'C')
    
    # Content Page
    pdf.add_page()
    pdf.set_font('helvetica', 'B', 16)
    pdf.cell(0, 10, 'Executive Summary', 0, 1, 'L')
    pdf.ln(5)
    pdf.set_font('helvetica', '', 12)
    pdf.multi_cell(0, 10, 'This is a placeholder for the executive summary. This PDF report follows the branded AInCHORS template layout for professional delivery.', 0, 'L')
    
    pdf.output(path)

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 4:
        print("Usage: python3 generate_pdf.py <path> <title> <subtitle> <author>")
        sys.exit(1)
    create_pdf_template(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
