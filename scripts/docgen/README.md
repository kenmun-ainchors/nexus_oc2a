# AInchors Document Generation Pipeline

Generate professional client-facing documents in DOCX, PDF, XLSX, and PPTX formats.

## Quick Start

```bash
zsh scripts/docgen/generate-doc.sh \
  --type proposal \
  --title "AI Transformation Proposal" \
  --output canvas/documents/client-abc/proposal.docx \
  --data /path/to/data.json
```

## Usage

```
generate-doc.sh --type [proposal|report|data|slides] --title "Title" --output /path/to/output [--data /path/to/data.json]
```

| Arg | Required | Description |
|-----|----------|-------------|
| `--type` | ✓ | Document type: `proposal`, `report`, `data`, `slides` |
| `--title` | ✓ | Document title |
| `--output` | ✓ | Output file path (extension must match type) |
| `--data` | optional | Path to JSON data file for client-specific content |

---

## Document Types

### `proposal` → DOCX (Consulting Proposal)

AInchors-branded Word document with cover, executive summary, scope, methodology, investment table, terms.

**Data JSON schema:**
```json
{
  "clientName": "Acme Corp",
  "date": "01 May 2026",
  "preparedBy": "Ahsoka — AI Transformation Consultant",
  "scopeItems": [
    "Discovery & stakeholder interviews",
    "Current-state process mapping"
  ],
  "investmentRows": [
    { "item": "Discovery Workshop", "qty": 1, "rate": 5000, "total": 5000 },
    { "item": "Process Analysis",   "qty": 3, "rate": 2500, "total": 7500 }
  ]
}
```

**Example:**
```bash
zsh scripts/docgen/generate-doc.sh \
  --type proposal \
  --title "AI Strategy Proposal" \
  --output canvas/documents/acme/proposal.docx \
  --data scripts/docgen/templates/proposal-data.json
```

---

### `report` → PDF (Discovery Report)

Professional PDF with branded header bar, findings table (colour-coded severity), and next steps.

**Data JSON schema:**
```json
{
  "clientName": "Acme Corp",
  "title": "AI Readiness Discovery Report",
  "date": "01 May 2026",
  "summary": "Executive summary text here...",
  "findings": [
    {
      "finding": "Manual data entry across 3 systems",
      "severity": "high",
      "recommendation": "Implement API integration layer"
    }
  ],
  "nextSteps": [
    "Present findings to executive team",
    "Prioritise top 3 initiatives"
  ]
}
```

**Severity values:** `critical` | `high` | `medium` | `low` | `info`

**Example:**
```bash
zsh scripts/docgen/generate-doc.sh \
  --type report \
  --title "Discovery Report — Acme Corp" \
  --output canvas/documents/acme/discovery-report.pdf \
  --data scripts/docgen/templates/report-data.json
```

---

### `data` → XLSX (Data Export)

Excel workbook with branded Summary sheet (metrics table) and Data sheet (raw rows).

**Data JSON schema:**
```json
{
  "title": "Engagement Data Summary",
  "metrics": {
    "Total Projects": 12,
    "Active Clients": 7,
    "Report Date": "08 May 2026"
  },
  "headers": ["Client", "Project", "Status", "Value (AUD)", "Completion %"],
  "rows": [
    ["Acme Corp", "AI Strategy", "In Progress", "$45,000", "65%"],
    ["Beta Industries", "Process Automation", "Completed", "$38,000", "100%"]
  ]
}
```

**Example:**
```bash
zsh scripts/docgen/generate-doc.sh \
  --type data \
  --title "Q2 Engagement Summary" \
  --output canvas/documents/acme/data-export.xlsx \
  --data scripts/docgen/templates/data-export-data.json
```

---

### `slides` → PPTX (Presentation)

PowerPoint with dark-header AInchors branding. Slide 1 = title slide; subsequent slides = content with bullets.

**Data JSON schema:**
```json
{
  "title": "AInchors Consulting Presentation",
  "subtitle": "AI Transformation Consulting",
  "date": "08 May 2026",
  "slides": [
    {
      "title": "Engagement Overview",
      "bullets": [
        "AI readiness assessment across 5 business units",
        "Identified 12 high-impact automation opportunities"
      ]
    },
    {
      "title": "Key Findings",
      "bullets": [
        "Manual processes account for 40% of overhead",
        "Data is siloed across 6 disconnected systems"
      ]
    }
  ]
}
```

**Example:**
```bash
zsh scripts/docgen/generate-doc.sh \
  --type slides \
  --title "Acme Corp — AI Strategy" \
  --output canvas/documents/acme/presentation.pptx \
  --data scripts/docgen/templates/slides-data.json
```

---

## Output Conventions

- All client outputs: `canvas/documents/<client-slug>/`
- Test outputs: `canvas/documents/docgen-test/`
- Always pass `--data` for client-specific content

## Dependencies

Installed via pip (user):
- `python-docx` — DOCX generation
- `fpdf2` — PDF generation
- `openpyxl` — XLSX generation
- `python-pptx` — PPTX generation
- `pandas`, `reportlab` — data support

Re-install: `/usr/bin/python3 -m pip install python-docx openpyxl pandas fpdf2 reportlab python-pptx --quiet --user`
