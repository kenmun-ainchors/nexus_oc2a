"""
Multi-zone AC system floor plan — high-quality pitch reference (PDF) v2.
A2 landscape, distinct zone colours, thicker walls/ductwork/piping,
larger readable labels, proper title block + legend + north arrow +
scale bar, "DEMO / PITCH REFERENCE — NOT FOR CONSTRUCTION" prominent
in its own strip, not overlapping the plan area.

Output: Operations/Pitch/sample-drawings/multi_zone_ac_floorplan_A2.pdf
"""

import os
from datetime import date
from reportlab.lib.pagesizes import A2, landscape
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, black, white, lightgrey, grey

OUT = (
    "/Users/ainchorsoc2a/.openclaw/workspace/Operations/Pitch/"
    "sample-drawings/multi_zone_ac_floorplan_A2.pdf"
)
os.makedirs(os.path.dirname(OUT), exist_ok=True)

# ---------------- Page: A2 landscape ----------------
PAGE = landscape(A2)
PW, PH = PAGE
PH_MM = PH / mm          # 420
PW_MM = PW / mm          # 594

def mm_to_pt(v_mm):  # v in mm -> points
    return v_mm * mm

# ---------------- Layout (all in mm) ----------------
MARGIN_MM      = 12
HEADER_MM      = 22         # title + subtitle strip
RIBBON_MM      = 8          # warning ribbon below header
PLAN_MARGIN_X  = 14
LEGEND_MM      = 64
TITLE_MM       = 56
FOOTER_MM      = 0

# Plan-area top = page top - margins - header - ribbon
PLAN_TOP_MM    = PH_MM - MARGIN_MM - HEADER_MM - RIBBON_MM - 2
PLAN_BOT_MM    = MARGIN_MM + LEGEND_MM + TITLE_MM + 6
PLAN_LEFT_MM   = PLAN_MARGIN_X
PLAN_RIGHT_MM  = PW_MM - PLAN_MARGIN_X

PLAN_TOP_PT    = mm_to_pt(PLAN_TOP_MM)
PLAN_BOT_PT    = mm_to_pt(PLAN_BOT_MM)
PLAN_LEFT_PT   = mm_to_pt(PLAN_LEFT_MM)
PLAN_RIGHT_PT  = mm_to_pt(PLAN_RIGHT_MM)
PLAN_W_PT      = PLAN_RIGHT_PT - PLAN_LEFT_PT
PLAN_H_PT      = PLAN_TOP_PT - PLAN_BOT_PT

# Building plan units (1 plan-unit = 1 mm at scale 1:100). Building 36 x 18 m.
BUILD_W = 36000
BUILD_H = 18000
# We size the building to use ~88% of plan width for visual prominence.
SCALE = (PLAN_W_PT * 0.92) / BUILD_W        # pt per plan-mm
BUILD_W_PT = BUILD_W * SCALE
BUILD_H_PT = BUILD_H * SCALE
BUILD_X0 = PLAN_LEFT_PT + (PLAN_W_PT - BUILD_W_PT) / 2
BUILD_Y0 = PLAN_BOT_PT + (PLAN_H_PT - BUILD_H_PT) / 2 + mm_to_pt(8)
# We also need space for the plant yard (below building) inside the plan frame.
YARD_H_PT = mm_to_pt(58)
# Shift building up so yard fits inside plan area.
if BUILD_Y0 + BUILD_H_PT + YARD_H_PT > PLAN_TOP_PT - mm_to_pt(4):
    # shrink SCALE so everything fits
    avail_h_pt = PLAN_TOP_PT - PLAN_BOT_PT - mm_to_pt(12) - YARD_H_PT
    scale_h = avail_h_pt / BUILD_H
    scale_w = (PLAN_W_PT * 0.92) / BUILD_W
    SCALE = min(scale_h, scale_w)
    BUILD_W_PT = BUILD_W * SCALE
    BUILD_H_PT = BUILD_H * SCALE
    BUILD_X0 = PLAN_LEFT_PT + (PLAN_W_PT - BUILD_W_PT) / 2
    BUILD_Y0 = PLAN_BOT_PT + (PLAN_H_PT - BUILD_H_PT - YARD_H_PT) / 2

def X(x):  # plan-mm x -> page pt
    return BUILD_X0 + x * SCALE
def Y(y):  # plan-mm y -> page pt
    return BUILD_Y0 + y * SCALE
def S(l):
    return l * SCALE

# ---------------- Colours ----------------
WALL_STROKE  = HexColor("#1a1f29")
WALL_FILL    = HexColor("#e9ecef")
BG_PAGE      = HexColor("#fdfcf7")

OFFICE_FILL      = HexColor("#cfe0f5")  # cool blue
MEETING_FILL     = HexColor("#cfead0")  # mint green
LOBBY_FILL       = HexColor("#f6dcb0")  # warm peach
PANTRY_FILL      = HexColor("#f6c9c9")  # soft red/pink
SERVER_FILL      = HexColor("#dccfea")  # soft lavender
PLANT_FILL       = HexColor("#fbe9a3")  # amber
MECH_FILL        = HexColor("#e3dccb")  # taupe
CORRIDOR_FILL    = HexColor("#ececec")  # light grey
YARD_FILL        = HexColor("#dceae0")  # mint-grey

# Equipment
AHU_FILL    = HexColor("#fff1d6")
AHU_EDGE    = HexColor("#a06b00")
FCU_FILL    = HexColor("#ffffff")     # white for max contrast
FCU_EDGE    = HexColor("#0b3a78")
CRAC_FILL   = HexColor("#f7d4d4")
CRAC_EDGE   = HexColor("#7a1f1f")
CHILLER_FILL = HexColor("#dddddd")
CHILLER_EDGE = black
CT_FILL     = HexColor("#cfe7f5")
CT_EDGE     = HexColor("#005a87")
PUMP_FILL   = HexColor("#fff7c2")
PUMP_EDGE   = HexColor("#7a6300")

# Services
SUPPLY_LINE = HexColor("#0c5fd6")
RETURN_LINE = HexColor("#7a3ec0")
CHW_SUPPLY  = HexColor("#0b8a4a")
CHW_RETURN  = HexColor("#b14a3a")

# Text
TEXT_DARK   = black
TEXT_MUTED  = HexColor("#5b6470")
TEXT_WARN   = HexColor("#a30000")
ACCENT_NAVY = HexColor("#0b3a78")
LEGEND_BG   = HexColor("#f6f7f9")
NOTES_BG    = HexColor("#fffbe6")
RIBBON_BG   = HexColor("#a30000")

# ---------------- Drawing helpers ----------------
def rect_pt(c, x_pt, y_pt, w_pt, h_pt, stroke=None, fill=None, lw=0.7, radius=0):
    if fill is not None:
        c.setFillColor(fill)
    if stroke is not None:
        c.setStrokeColor(stroke)
    c.setLineWidth(lw)
    if radius > 0:
        c.roundRect(x_pt, y_pt, w_pt, h_pt, radius, stroke=1, fill=1 if fill is not None else 0)
    else:
        c.rect(x_pt, y_pt, w_pt, h_pt, stroke=1, fill=1 if fill is not None else 0)

def label_pt(c, txt, x_pt, y_pt, size=8, color=TEXT_DARK, anchor="left",
             bold=False, font="Helvetica"):
    c.setFillColor(color)
    f = (font + "-Bold") if bold else font
    c.setFont(f, size)
    if anchor == "center":
        c.drawCentredString(x_pt, y_pt, txt)
    elif anchor == "right":
        c.drawRightString(x_pt, y_pt, txt)
    else:
        c.drawString(x_pt, y_pt, txt)

def room_rect(c, x, y, w, h, fill, code, name, subtitle=None, lw_pt=1.6):
    """Draw a room. Auto-sizes the main label based on the room's smaller
    dimension so labels never overflow."""
    rect_pt(c, X(x), Y(y), S(w), S(h), stroke=WALL_STROKE, fill=fill, lw=lw_pt)
    # Decide font sizes based on room area
    short_side_m = min(w, h) / 1000.0    # shorter side in metres
    if short_side_m >= 5.5:
        name_size = 14
        sub_size = 9.5
        code_size = 9
    elif short_side_m >= 4:
        name_size = 12
        sub_size = 8.5
        code_size = 8.5
    else:
        name_size = 10
        sub_size = 7.5
        code_size = 8
    # Centre the (name + optional subtitle) block
    cx = X(x + w / 2)
    cy = Y(y + h / 2)
    if subtitle:
        label_pt(c, name, cx, cy + 4.5, size=name_size, bold=True,
                 anchor="center", color=ACCENT_NAVY)
        label_pt(c, subtitle, cx, cy - 6.5, size=sub_size, bold=False,
                 anchor="center", color=TEXT_MUTED)
    else:
        label_pt(c, name, cx, cy, size=name_size, bold=True,
                 anchor="center", color=ACCENT_NAVY)
    # Code tag in upper-left of room
    label_pt(c, code, X(x) + 4, Y(y + h) - 9, size=code_size,
             color=TEXT_MUTED, bold=True, anchor="left")

# ---------------- Equipment symbols ----------------
def sym_ahu(c, cx_pt, cy_pt, code="AHU-1", cfm="15,000 CFM",
            w_pt=80, h_pt=48, name_size=12, cfm_size=9):
    c.setStrokeColor(AHU_EDGE)
    c.setFillColor(AHU_FILL)
    c.setLineWidth(1.4)
    c.roundRect(cx_pt - w_pt / 2, cy_pt - h_pt / 2, w_pt, h_pt, 3.5,
                stroke=1, fill=1)
    label_pt(c, code, cx_pt, cy_pt + 1.0, size=name_size, color=AHU_EDGE,
             bold=True, anchor="center")
    label_pt(c, cfm, cx_pt, cy_pt - h_pt / 2 - 4.5, size=cfm_size,
             color=AHU_EDGE, bold=True, anchor="center")

def sym_fcu(c, cx_pt, cy_pt, code="FCU", w_pt=44, h_pt=26, label_size=10):
    # Stronger outline + light-yellow fill so FCU stands out from blue office fill
    c.setStrokeColor(FCU_EDGE)
    c.setFillColor(HexColor("#fff5d0"))
    c.setLineWidth(1.4)
    c.roundRect(cx_pt - w_pt / 2, cy_pt - h_pt / 2, w_pt, h_pt, 3.0,
                stroke=1, fill=1)
    label_pt(c, code, cx_pt, cy_pt + 0.4, size=label_size, color=FCU_EDGE,
             bold=True, anchor="center")

def sym_chiller(c, cx_pt, cy_pt, r_pt=22, code="CH-1", name_size=11, sub_size=7.5):
    c.setStrokeColor(CHILLER_EDGE)
    c.setFillColor(CHILLER_FILL)
    c.setLineWidth(1.3)
    c.circle(cx_pt, cy_pt, r_pt, stroke=1, fill=1)
    # internal coil mark
    c.setStrokeColor(CHILLER_EDGE); c.setLineWidth(0.7)
    c.circle(cx_pt, cy_pt, r_pt * 0.55, stroke=1, fill=0)
    label_pt(c, code, cx_pt, cy_pt + 2, size=name_size, bold=True, anchor="center")
    label_pt(c, "WATER-COOLED", cx_pt, cy_pt - 5, size=sub_size,
             color=TEXT_MUTED, anchor="center")

def sym_ct(c, cx_pt, cy_pt, r_pt=22, code="CT-1", name_size=11, sub_size=7.5):
    c.setStrokeColor(CT_EDGE)
    c.setFillColor(CT_FILL)
    c.setLineWidth(1.3)
    c.circle(cx_pt, cy_pt, r_pt, stroke=1, fill=1)
    # internal fan
    c.setStrokeColor(CT_EDGE); c.setLineWidth(0.9)
    c.line(cx_pt - r_pt * 0.7, cy_pt, cx_pt + r_pt * 0.7, cy_pt)
    c.line(cx_pt, cy_pt - r_pt * 0.7, cx_pt, cy_pt + r_pt * 0.7)
    c.circle(cx_pt, cy_pt, r_pt * 0.18, stroke=1, fill=1)
    label_pt(c, code, cx_pt, cy_pt - 1, size=name_size, bold=True,
             color=CT_EDGE, anchor="center")
    label_pt(c, "INDUCED DRAFT", cx_pt, cy_pt - r_pt - 4, size=sub_size,
             color=TEXT_MUTED, anchor="center")

def sym_pump(c, cx_pt, cy_pt, r_pt=11, code="P-1", name_size=10):
    c.setStrokeColor(PUMP_EDGE)
    c.setFillColor(PUMP_FILL)
    c.setLineWidth(1.1)
    c.circle(cx_pt, cy_pt, r_pt, stroke=1, fill=1)
    c.setStrokeColor(PUMP_EDGE); c.setLineWidth(0.7)
    c.circle(cx_pt, cy_pt, r_pt * 0.4, stroke=0, fill=1)
    label_pt(c, code, cx_pt, cy_pt - r_pt - 3.5, size=name_size, bold=True,
             color=PUMP_EDGE, anchor="center")

def sym_diffuser(c, cx_pt, cy_pt, r_pt=5.5):
    c.setStrokeColor(SUPPLY_LINE)
    c.setFillColor(white)
    c.setLineWidth(0.9)
    c.rect(cx_pt - r_pt, cy_pt - r_pt, 2 * r_pt, 2 * r_pt, stroke=1, fill=1)
    c.setStrokeColor(SUPPLY_LINE); c.setLineWidth(0.9)
    c.line(cx_pt - r_pt * 0.7, cy_pt - r_pt * 0.7,
           cx_pt + r_pt * 0.7, cy_pt + r_pt * 0.7)
    c.line(cx_pt - r_pt * 0.7, cy_pt + r_pt * 0.7,
           cx_pt + r_pt * 0.7, cy_pt - r_pt * 0.7)

def sym_grille(c, cx_pt, cy_pt, r_pt=5.0):
    c.setStrokeColor(RETURN_LINE)
    c.setFillColor(white)
    c.setLineWidth(0.9)
    c.setDash(2.0, 1.5)
    c.rect(cx_pt - r_pt, cy_pt - r_pt, 2 * r_pt, 2 * r_pt, stroke=1, fill=1)
    c.setDash()
    c.setStrokeColor(RETURN_LINE); c.setLineWidth(0.7)
    for k in (-2, -1, 0, 1, 2):
        c.line(cx_pt - r_pt * 0.85, cy_pt + k * r_pt * 0.4,
               cx_pt + r_pt * 0.85, cy_pt + k * r_pt * 0.4)

def sym_thermostat(c, cx_pt, cy_pt, r_pt=3.4):
    c.setStrokeColor(black); c.setFillColor(white); c.setLineWidth(0.7)
    c.circle(cx_pt, cy_pt, r_pt, stroke=1, fill=1)
    c.setFillColor(HexColor("#b14a3a"))
    c.circle(cx_pt, cy_pt, r_pt * 0.35, stroke=0, fill=1)

# ---------------- Build the canvas ----------------
c = canvas.Canvas(OUT, pagesize=PAGE)
c.setTitle("Multi-Zone AC System — Sample Floor Plan (Pitch Reference)")
c.setAuthor("AInchors")
c.setSubject("HVAC demo floor plan: 4 office zones + corridor return + central plant")
c.setKeywords("HVAC, AHU, FCU, chilled water, ductwork, floor plan, pitch, demo")
c.setPageCompression(1)

# Paper background
rect_pt(c, 0, 0, PW, PH, stroke=None, fill=BG_PAGE)

# Outer page border
c.setStrokeColor(HexColor("#222222")); c.setLineWidth(0.7)
c.rect(MARGIN_MM * mm / 2, MARGIN_MM * mm / 2,
       PW - MARGIN_MM * mm, PH - MARGIN_MM * mm, stroke=1, fill=0)

# ---------------- Header strip ----------------
hdr_y_title = PH - mm_to_pt(6) - 11
hdr_y_sub   = PH - mm_to_pt(6) - 23
label_pt(c, "MULTI-ZONE AIR CONDITIONING — SAMPLE FLOOR PLAN",
         MARGIN_MM * mm, hdr_y_title, size=24, bold=True, anchor="left",
         color=ACCENT_NAVY)
label_pt(c,
         "4 office zones + corridor return  •  1× AHU (15,000 CFM) "
         "+ 9× FCUs  •  Chilled-water primary plant "
         "(2× 150 TR + induced-draft cooling tower)",
         MARGIN_MM * mm, hdr_y_sub, size=11, color=TEXT_MUTED, anchor="left")

# ---------------- Warning ribbon (own strip, does not overlap plan) ----------------
ribbon_top = PH - mm_to_pt(MARGIN_MM + HEADER_MM)
ribbon_bot = PH - mm_to_pt(MARGIN_MM + HEADER_MM + RIBBON_MM)
c.setFillColor(RIBBON_BG); c.setStrokeColor(RIBBON_BG)
c.rect(0, ribbon_bot, PW, ribbon_top - ribbon_bot, stroke=0, fill=1)
# White stripe text
c.setFillColor(white)
label_pt(c, "DEMO / PITCH REFERENCE — NOT FOR CONSTRUCTION",
         PW / 2, ribbon_bot + (ribbon_top - ribbon_bot) / 2 - 3.5,
         size=11, bold=True, anchor="center")

# ---------------- Plan-area frame ----------------
c.setStrokeColor(black); c.setLineWidth(0.9)
c.rect(PLAN_LEFT_PT, PLAN_BOT_PT, PLAN_W_PT, PLAN_H_PT, stroke=1, fill=0)
# Inner frame (light) for double-line architectural border
c.setStrokeColor(HexColor("#888888")); c.setLineWidth(0.3)
c.rect(PLAN_LEFT_PT + 1.5, PLAN_BOT_PT + 1.5,
       PLAN_W_PT - 3, PLAN_H_PT - 3, stroke=1, fill=0)

# North arrow (top-left, inside plan)
def north_arrow(c, x_pt, y_pt, size_pt=16):
    c.saveState()
    c.translate(x_pt, y_pt)
    c.setFillColor(black); c.setStrokeColor(black); c.setLineWidth(0.7)
    p = c.beginPath()
    p.moveTo(0, size_pt)
    p.lineTo(-size_pt * 0.55, -size_pt * 0.75)
    p.lineTo(0, -size_pt * 0.25)
    p.lineTo(size_pt * 0.55, -size_pt * 0.75)
    p.close()
    c.drawPath(p, stroke=1, fill=1)
    c.setFillColor(white)
    c.circle(0, -size_pt * 0.25, size_pt * 0.18, stroke=0, fill=1)
    c.setFillColor(black)
    label_pt(c, "N", 0, size_pt + 5, size=12, bold=True, anchor="center")
    c.restoreState()

# Scale bar
def scale_bar(c, x_pt, y_pt, segments=5, seg_m=2, label_size=8):
    seg_len_pt = seg_m * 12 * mm / 1000.0  # 1 m = 12 mm visual scale
    total = segments * seg_len_pt
    for i in range(segments):
        c.setFillColor(black if i % 2 == 0 else white)
        c.setStrokeColor(black); c.setLineWidth(0.4)
        c.rect(x_pt + i * seg_len_pt, y_pt, seg_len_pt, 4.0, stroke=1, fill=1)
    c.setStrokeColor(black); c.setLineWidth(0.6)
    c.rect(x_pt, y_pt, total, 4.0, stroke=1, fill=0)
    for i in range(segments + 1):
        label_pt(c, f"{i*seg_m}", x_pt + i * seg_len_pt, y_pt - 4.5,
                 size=label_size, anchor="center")
    label_pt(c, f"SCALE  0   {seg_m}   {2*seg_m}   {3*seg_m}   "
                 f"{4*seg_m}   {5*seg_m}  m",
             x_pt + total / 2, y_pt + 7, size=label_size + 0.5, bold=True,
             anchor="center")

# Place north + scale at top-left of plan area
north_arrow(c, PLAN_LEFT_PT + 18, PLAN_TOP_PT - 18)
scale_bar(c, PLAN_LEFT_PT + 60, PLAN_TOP_PT - 18)

# Plan-area title (top-right of plan)
plan_title_x = PLAN_RIGHT_PT - 6
plan_title_y = PLAN_TOP_PT - 8
label_pt(c, "FLOOR  PLAN", plan_title_x, plan_title_y, size=11, bold=True,
         color=ACCENT_NAVY, anchor="right")
label_pt(c, "Visual scale 1 m = 12 mm   •   Engineering scale 1 : 100",
         plan_title_x, plan_title_y - 11, size=8, color=TEXT_MUTED,
         anchor="right")

# ===================================================================
# Plan geometry
# ===================================================================
# Outer building shell
c.setFillColor(WALL_FILL)
c.setStrokeColor(WALL_STROKE)
c.setLineWidth(3.6)
c.rect(X(0), Y(0), S(BUILD_W), S(BUILD_H), stroke=1, fill=1)

# Rooms (in plan-mm; y=0 is bottom of building)
ROOMS = [
    # (x, y, w, h, code, name, subtitle, fill)
    (1000,  11000, 7500,  6500, "Z-A", "OFFICE  ZONE  A",        "8 workstations",          OFFICE_FILL),
    (9000,  11000, 7500,  6500, "Z-B", "OFFICE  ZONE  B",        "8 workstations",          OFFICE_FILL),
    (17000, 11000, 7500,  6500, "Z-C", "OFFICE  ZONE  C",        "8 workstations",          OFFICE_FILL),
    (25000, 11000, 10000, 6500, "Z-D", "OPEN  OFFICE  /  COLLAB",
     "12 workstations + 2 huddle", OFFICE_FILL),
    (1000,  5000,  8000,  5300, "M-1", "MEETING  ROOM  1",       "10 pax boardroom",        MEETING_FILL),
    (9500,  5000,  8000,  5300, "M-2", "MEETING  ROOM  2",       "6 pax huddle",            MEETING_FILL),
    (18000, 5000,  8000,  5300, "M-3", "MEETING  ROOM  3",       "8 pax training",          MEETING_FILL),
    (26500, 5000,  8500,  5300, "SER", "SERVER  /  ELECTRICAL",  "24/7 critical cooling",   SERVER_FILL),
    (1000,  500,   7000,  4000, "MECH","MECHANICAL  /  PUMP",    "CHW pumps • expansion",   MECH_FILL),
    (8500,  500,   5000,  4000, "PNT", "PANTRY  /  BREAKOUT",    "FCU-5 • EF-1",            PANTRY_FILL),
    (14000, 500,   6000,  4000, "REC", "RECEPTION  /  LOBBY",    "FCU-6 • vestibule heat",  LOBBY_FILL),
    (26500, 500,   8500,  4000, "PLT", "AHU  PLANT  ROOM",       "AHU-1 • 15,000 CFM",      PLANT_FILL),
]
for (x, y, w, h, code, name, subtitle, fill) in ROOMS:
    room_rect(c, x, y, w, h, fill, code, name, subtitle, lw_pt=1.8)

# Corridor / return-air plenum
CORRIDOR_Y0 = 10300
CORRIDOR_Y1 = 11000
rect_pt(c, X(1000), Y(CORRIDOR_Y0), S(34000), S(CORRIDOR_Y1 - CORRIDOR_Y0),
        stroke=WALL_STROKE, fill=CORRIDOR_FILL, lw=1.6)
# Door openings (notches)
DOOR_OPENING = 1200
for cx in (4750, 12750, 20750, 30000):
    wall_line = lambda x1, y1, x2, y2: c.line(X(x1), Y(y1), X(x2), Y(y2))
    c.setStrokeColor(BG_PAGE); c.setLineWidth(2.2)
    c.line(X(cx - DOOR_OPENING / 2), Y(CORRIDOR_Y0),
           X(cx + DOOR_OPENING / 2), Y(CORRIDOR_Y0))
for cx in (5000, 13500, 22000, 30750):
    c.setStrokeColor(BG_PAGE); c.setLineWidth(2.2)
    c.line(X(cx - 800), Y(CORRIDOR_Y1),
           X(cx + 800), Y(CORRIDOR_Y1))

# Corridor labels
label_pt(c, "MAIN  CORRIDOR  /  RETURN  AIR  PLENUM",
         X(18000), Y((CORRIDOR_Y0 + CORRIDOR_Y1) / 2 + 4),
         size=11, bold=True, anchor="center", color=TEXT_MUTED)
label_pt(c, "EXHAUST  &  RETURN  →  AHU",
         X(18000), Y((CORRIDOR_Y0 + CORRIDOR_Y1) / 2 - 7),
         size=8.5, anchor="center", color=TEXT_MUTED)

# Zone identification tabs (small navy chevrons at the top of each office
# zone, just above the corridor wall, outside the corridor fill)
zone_tags = [
    (4750,  "ZONE  A"),
    (12750, "ZONE  B"),
    (20750, "ZONE  C"),
    (30000, "ZONE  D"),
]
for (zx, ztxt) in zone_tags:
    # Inside the office zone, just above the corridor wall (which is at y=11000)
    # Center on the zone's bottom edge just above the corridor
    label_pt(c, "▼ " + ztxt, X(zx), Y(11100) + 5,
             size=9, bold=True, color=ACCENT_NAVY, anchor="center")

# ===================================================================
# Equipment: AHU, FCUs, CRAC, diffusers, grilles, thermostats
# ===================================================================
# AHU inside plant room (center)
sym_ahu(c, X(30750), Y(2700), code="AHU-1", cfm="15,000 CFM",
        w_pt=80, h_pt=46, name_size=11, cfm_size=9)
# Outside air louver (right wall of plant room)
c.setStrokeColor(black); c.setFillColor(white); c.setLineWidth(0.8)
c.rect(X(35000) - 1, Y(2200), 6, S(2500), stroke=1, fill=1)
c.setStrokeColor(black); c.setLineWidth(0.5)
for k in range(6):
    c.line(X(35000) - 1, Y(2200 + 200 + k * 360),
           X(35000) + 5, Y(2200 + 200 + k * 360))
label_pt(c, "OA LOUVER", X(35000) - 5, Y(3450), size=8, bold=True,
         anchor="right")

# FCU positions (plan-mm)
fcu_units = [
    (4750,  16700, "FCU-1", "2,400 CFM"),
    (12750, 16700, "FCU-2", "2,400 CFM"),
    (20750, 16700, "FCU-3", "2,400 CFM"),
    (30000, 16700, "FCU-4", "3,600 CFM"),
    (5000,  8000,  "FCU-7", "1,500 CFM"),
    (13500, 8000,  "FCU-8", "1,500 CFM"),
    (22000, 8000,  "FCU-9", "1,500 CFM"),
    (11000, 2400,  "FCU-5", "1,200 CFM"),
    (17000, 2400,  "FCU-6", "2,000 CFM"),
]
for (cx, cy, code, cfm) in fcu_units:
    sym_fcu(c, X(cx), Y(cy), code=code, w_pt=44, h_pt=24, label_size=10)
    label_pt(c, cfm, X(cx), Y(cy) - 22, size=8, color=FCU_EDGE,
             bold=True, anchor="center")

# CRAC unit in server room (positioned at bottom of room so label stays visible)
c.setStrokeColor(CRAC_EDGE); c.setFillColor(CRAC_FILL); c.setLineWidth(1.2)
c.roundRect(X(29000), Y(5500), S(3500), S(1800), 4,
            stroke=1, fill=1)
label_pt(c, "CRAC-1", X(30750), Y(6700), size=12, bold=True,
         color=CRAC_EDGE, anchor="center")
label_pt(c, "Precision cooling  •  N+1", X(30750), Y(6200), size=9,
         color=CRAC_EDGE, anchor="center")

# Diffusers per zone
zone_diffs_map = {
    "Z-A": [2700, 4500, 6300, 8200],
    "Z-B": [10500, 12300, 14100, 16000],
    "Z-C": [18500, 20300, 22100, 24000],
    "Z-D": [27000, 28800, 30600, 32400, 34200],
    "M-1": [2500, 5000, 7500],
    "M-2": [11000, 13500, 16000],
    "M-3": [19500, 22000, 24500],
}
DIFF_Y_OFFICE = 13800
DIFF_Y_MEET = 7800

# Supply trunks
def fcu_supply(c, fcu_x, fcu_y, trunk_top_y, diff_y, diff_xs):
    c.setStrokeColor(SUPPLY_LINE); c.setLineWidth(2.6)
    c.line(X(fcu_x), Y(fcu_y + 600), X(fcu_x), Y(trunk_top_y))
    c.line(X(min(diff_xs) - 300), Y(trunk_top_y),
           X(max(diff_xs) + 300), Y(trunk_top_y))
    for dx in diff_xs:
        c.line(X(dx), Y(trunk_top_y), X(dx), Y(diff_y))
    # supply arrow at trunk top (up)
    c.setFillColor(SUPPLY_LINE)
    p = c.beginPath()
    p.moveTo(X(fcu_x), Y(trunk_top_y + 280))
    p.lineTo(X(fcu_x) - 4, Y(trunk_top_y))
    p.lineTo(X(fcu_x) + 4, Y(trunk_top_y))
    p.close()
    c.drawPath(p, stroke=0, fill=1)

fcu_supply(c, 4750,  16700, 17400, DIFF_Y_OFFICE, zone_diffs_map["Z-A"])
fcu_supply(c, 12750, 16700, 17400, DIFF_Y_OFFICE, zone_diffs_map["Z-B"])
fcu_supply(c, 20750, 16700, 17400, DIFF_Y_OFFICE, zone_diffs_map["Z-C"])
fcu_supply(c, 30000, 16700, 17400, DIFF_Y_OFFICE, zone_diffs_map["Z-D"])
fcu_supply(c, 5000,  8000,  10900, DIFF_Y_MEET,  zone_diffs_map["M-1"])
fcu_supply(c, 13500, 8000,  10900, DIFF_Y_MEET,  zone_diffs_map["M-2"])
fcu_supply(c, 22000, 8000,  10900, DIFF_Y_MEET,  zone_diffs_map["M-3"])

# Return drops (dashed purple) from grilles to corridor
def return_drop(c, gx, gy, trunk_y):
    c.setStrokeColor(RETURN_LINE); c.setLineWidth(2.2)
    c.setDash(3.5, 2.5)
    c.line(X(gx), Y(gy + 600), X(gx), Y(trunk_y))
    c.setDash()

for gx in [3500, 7500]:
    return_drop(c, gx, 14100, 10650)
    sym_grille(c, X(gx), Y(14100), r_pt=5.0)
for gx in [11200, 15200]:
    return_drop(c, gx, 14100, 10650)
    sym_grille(c, X(gx), Y(14100), r_pt=5.0)
for gx in [19200, 23200]:
    return_drop(c, gx, 14100, 10650)
    sym_grille(c, X(gx), Y(14100), r_pt=5.0)
for gx in [28000, 31000, 33500]:
    return_drop(c, gx, 14100, 10650)
    sym_grille(c, X(gx), Y(14100), r_pt=5.0)
for gx in [3500, 7000]:
    return_drop(c, gx, 8000, 11000)
    sym_grille(c, X(gx), Y(8000), r_pt=4.5)
for gx in [12000, 15500]:
    return_drop(c, gx, 8000, 11000)
    sym_grille(c, X(gx), Y(8000), r_pt=4.5)
for gx in [20500, 24000]:
    return_drop(c, gx, 8000, 11000)
    sym_grille(c, X(gx), Y(8000), r_pt=4.5)

# Diffusers on top
for zone, ys in [("Z-A", DIFF_Y_OFFICE), ("Z-B", DIFF_Y_OFFICE),
                 ("Z-C", DIFF_Y_OFFICE), ("Z-D", DIFF_Y_OFFICE),
                 ("M-1", DIFF_Y_MEET), ("M-2", DIFF_Y_MEET),
                 ("M-3", DIFF_Y_MEET)]:
    for dx in zone_diffs_map[zone]:
        sym_diffuser(c, X(dx), Y(ys), r_pt=5.5)

# Corridor return trunk (dashed purple), full width
c.setStrokeColor(RETURN_LINE); c.setLineWidth(2.6)
c.setDash(4, 2.5)
c.line(X(1000), Y(10650), X(35000), Y(10650))
c.setDash()
# drop into AHU plant room
c.setStrokeColor(RETURN_LINE); c.setLineWidth(2.6)
c.setDash(4, 2.5)
c.line(X(30750), Y(10650), X(30750), Y(4500))
c.setDash()
c.setStrokeColor(RETURN_LINE); c.setLineWidth(2.0)
c.line(X(30750), Y(4500), X(30750), Y(4000))
label_pt(c, "RA  →", X(30750) + 6, Y(7300), size=9, bold=True,
         color=RETURN_LINE, anchor="left")

# Pantry + reception diffusers/grilles
sym_diffuser(c, X(11000), Y(1800), r_pt=4.5)
sym_grille(c,    X(13000), Y(1800), r_pt=4.0)
sym_diffuser(c, X(16500), Y(1800), r_pt=4.5)
sym_diffuser(c, X(18000), Y(1800), r_pt=4.5)
sym_grille(c,    X(19000), Y(1800), r_pt=4.0)

# Thermostats
thermo_positions = [
    (4500,  14000), (12500, 14000), (20500, 14000), (30000, 14000),
    (5000,  8200),  (13500, 8200),  (22000, 8200),
    (30500, 8500), (17000, 2500), (11000, 2500),
]
for (tx, ty) in thermo_positions:
    sym_thermostat(c, X(tx), Y(ty), r_pt=3.0)

# ===================================================================
# Central plant yard (below building)
# ===================================================================
YARD_Y0 = -5500
YARD_Y1 = 200
YARD_X0 = 1000
YARD_X1 = 35000
rect_pt(c, X(YARD_X0), Y(YARD_Y0), S(YARD_X1 - YARD_X0), S(YARD_Y1 - YARD_Y0),
        stroke=WALL_STROKE, fill=YARD_FILL, lw=1.6)
label_pt(c, "CENTRAL  PLANT  YARD  (chilled-water primary loop)",
         X(18000), Y(YARD_Y1 - 350), size=11, bold=True, color=ACCENT_NAVY,
         anchor="center")
label_pt(c, "2× water-cooled chillers (N+1)  •  1× induced-draft cooling tower  •  3× primary CHW pumps (2W + 1S)",
         X(18000), Y(YARD_Y1 - 900), size=8.5, color=TEXT_MUTED, anchor="center")

# Chillers, tower, pumps
sym_chiller(c, X(8000),  Y(-1700), r_pt=22, code="CH-1", name_size=11, sub_size=7.5)
sym_chiller(c, X(11500), Y(-1700), r_pt=22, code="CH-2", name_size=11, sub_size=7.5)
label_pt(c, "150 TR", X(8000),  Y(-3300), size=9, bold=True, anchor="center")
label_pt(c, "150 TR", X(11500), Y(-3300), size=9, bold=True, anchor="center")

sym_ct(c, X(16000), Y(-1700), r_pt=22, code="CT-1", name_size=11, sub_size=7.5)

for px, code in [(21000, "P-1"), (22500, "P-2"), (24000, "P-3")]:
    sym_pump(c, X(px), Y(-1700), r_pt=12, code=code, name_size=10)
label_pt(c, "Primary CHW Pumps", X(22500), Y(-3300), size=9, bold=True,
         color=TEXT_MUTED, anchor="center")

# CHW supply/return headers in yard (east-west)
hdr_sup_y = -700
hdr_ret_y = -1200
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(3.6)
c.line(X(5000), Y(hdr_sup_y), X(33000), Y(hdr_sup_y))
c.setStrokeColor(CHW_RETURN); c.setLineWidth(3.6)
c.line(X(5000), Y(hdr_ret_y), X(33000), Y(hdr_ret_y))

# Drops to each chiller from headers
for cx in (8000, 11500):
    c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(1.7)
    c.line(X(cx), Y(hdr_sup_y), X(cx), Y(-1200))
    c.setStrokeColor(CHW_RETURN); c.setLineWidth(1.7)
    c.line(X(cx), Y(hdr_ret_y), X(cx), Y(-2200))
# Condenser-water drop to cooling tower
c.setStrokeColor(CT_EDGE); c.setLineWidth(1.7)
c.setDash(3, 2)
c.line(X(16000), Y(hdr_sup_y), X(16000), Y(-1200))
c.setDash()
# Drops to pumps
for px in (21000, 22500, 24000):
    c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(1.7)
    c.line(X(px), Y(hdr_sup_y), X(px), Y(-1100))

# Riser up left side to mech room
MECH_TOP_X = 3000
MECH_SUP_Y = 4500 + 600
MECH_RET_Y = 4500 + 200
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(3.6)
c.line(X(5000), Y(hdr_sup_y), X(MECH_TOP_X), Y(hdr_sup_y))
c.line(X(MECH_TOP_X), Y(hdr_sup_y), X(MECH_TOP_X), Y(MECH_SUP_Y))
c.setStrokeColor(CHW_RETURN); c.setLineWidth(3.6)
c.line(X(5000), Y(hdr_ret_y), X(4200), Y(hdr_ret_y))
c.line(X(4200), Y(hdr_ret_y), X(4200), Y(MECH_RET_Y))

# Mech room internal headers
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(2.6)
c.line(X(MECH_TOP_X), Y(MECH_SUP_Y), X(8000), Y(MECH_SUP_Y))
c.setStrokeColor(CHW_RETURN); c.setLineWidth(2.6)
c.line(X(4200), Y(MECH_RET_Y), X(8000), Y(MECH_RET_Y))

# Cross-building CHW supply main
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(3.8)
c.line(X(8000), Y(MECH_SUP_Y), X(8000), Y(11800))
c.line(X(8000), Y(11800), X(30750), Y(11800))
c.line(X(30750), Y(11800), X(30750), Y(5500))
c.line(X(30750), Y(5500), X(30750), Y(4000))
# CHW return main parallel
c.setStrokeColor(CHW_RETURN); c.setLineWidth(3.8)
c.line(X(8000), Y(MECH_RET_Y), X(8000), Y(12000))
c.line(X(8000), Y(12000), X(30750), Y(12000))
c.line(X(30750), Y(12000), X(30750), Y(5000))
c.line(X(30750), Y(5000), X(30750), Y(3300))

# Flow chevrons on long horizontals
for xx in (12000, 16000, 20000, 24000, 28000):
    c.setFillColor(CHW_SUPPLY)
    p = c.beginPath()
    p.moveTo(X(xx) - 4, Y(11800) - 4)
    p.lineTo(X(xx) + 4, Y(11800))
    p.lineTo(X(xx) - 4, Y(11800) + 4)
    p.close()
    c.drawPath(p, stroke=0, fill=1)
    c.setFillColor(CHW_RETURN)
    p = c.beginPath()
    p.moveTo(X(xx) + 4, Y(12000) - 4)
    p.lineTo(X(xx) - 4, Y(12000))
    p.lineTo(X(xx) + 4, Y(12000) + 4)
    p.close()
    c.drawPath(p, stroke=0, fill=1)

# CHW tap (typical)
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(1.4)
c.setDash(2.5, 2.0)
c.line(X(4750), Y(11800), X(4750), Y(17000))
c.setDash()
c.setStrokeColor(CHW_RETURN); c.setLineWidth(1.4)
c.setDash(2.5, 2.0)
c.line(X(4500), Y(12000), X(4500), Y(17000))
c.setDash()
label_pt(c, "CHW  TAP  —  TYP.",
         X(5300), Y(14000), size=7, bold=True, color=CHW_SUPPLY,
         anchor="left")

# Pipe labels - callout tags near the start of the long CHW runs (at x=10000, just
# after the riser). Background pill so they read against the building fill.
def pipe_label(c, x, y, text_, color):
    w = 95
    h = 11
    x_pt = X(x); y_pt = Y(y)
    c.setFillColor(white)
    c.setStrokeColor(color); c.setLineWidth(0.8)
    c.roundRect(x_pt - w/2, y_pt - h/2, w, h, 2, stroke=1, fill=1)
    label_pt(c, text_, x_pt, y_pt - 1.5, size=7.5, bold=True,
             color=color, anchor="center")

pipe_label(c, 10500, 11800, "CHW  SUPPLY  44°F", CHW_SUPPLY)
pipe_label(c, 10500, 12000, "CHW  RETURN  54°F", CHW_RETURN)

# ===================================================================
# Dimensions
# ===================================================================
def dim_h_pt(c, x1_pt, x2_pt, y_pt, text_, tick=4.0):
    c.setStrokeColor(HexColor("#444444")); c.setLineWidth(0.4)
    c.line(x1_pt, y_pt - tick, x1_pt, y_pt + tick)
    c.line(x2_pt, y_pt - tick, x2_pt, y_pt + tick)
    c.line(x1_pt, y_pt, x2_pt, y_pt)
    label_pt(c, text_, (x1_pt + x2_pt) / 2, y_pt + 1.5, size=7.5,
             color=HexColor("#444444"), bold=True, anchor="center")

def dim_v_pt(c, y1_pt, y2_pt, x_pt, text_, tick=4.0):
    c.setStrokeColor(HexColor("#444444")); c.setLineWidth(0.4)
    c.line(x_pt - tick, y1_pt, x_pt + tick, y1_pt)
    c.line(x_pt - tick, y2_pt, x_pt + tick, y2_pt)
    c.line(x_pt, y1_pt, x_pt, y2_pt)
    c.saveState()
    c.translate(x_pt - 2.5, (y1_pt + y2_pt) / 2)
    c.rotate(90)
    label_pt(c, text_, 0, 0, size=7.5, color=HexColor("#444444"),
             bold=True, anchor="center")
    c.restoreState()

dim_h_pt(c, X(0), X(BUILD_W), Y(BUILD_H) + 14, "36 000  (36.0 m)")
dim_v_pt(c, Y(0), Y(BUILD_H), X(0) - 14, "18 000  (18.0 m)")
dim_h_pt(c, X(1000),  X(8500),  Y(17500) + 8, "7 500")
dim_h_pt(c, X(9000),  X(16500), Y(17500) + 8, "7 500")
dim_h_pt(c, X(17000), X(24500), Y(17500) + 8, "7 500")
dim_h_pt(c, X(25000), X(35000), Y(17500) + 8, "10 000")

# ===================================================================
# Equipment schedule box (top-right of plan)
# ===================================================================
sum_w = 175; sum_h = 78
sum_x = PLAN_RIGHT_PT - sum_w - 6
sum_y = PLAN_TOP_PT - sum_h - 8
c.setFillColor(LEGEND_BG); c.setStrokeColor(black); c.setLineWidth(0.7)
c.rect(sum_x, sum_y, sum_w, sum_h, stroke=1, fill=1)
# Title bar
c.setFillColor(ACCENT_NAVY)
c.rect(sum_x, sum_y + sum_h - 12, sum_w, 12, stroke=0, fill=1)
label_pt(c, "EQUIPMENT  SCHEDULE", sum_x + sum_w / 2, sum_y + sum_h - 9.5,
         size=9, bold=True, anchor="center", color=white)
sched = [
    "1× AHU  •  15,000 CFM",
    "9× FCU  •  18,800 CFM total",
    "2× Chiller  •  300 TR",
    "1× Cooling tower",
    "3× CHW pumps  (2W + 1S)",
    "1× CRAC  •  N+1 server",
]
for i, line in enumerate(sched):
    label_pt(c, line, sum_x + 4, sum_y + sum_h - 22 - i * 8,
             size=8, anchor="left")
# Total line at bottom
c.setFillColor(white)
c.rect(sum_x + 2, sum_y + 2, sum_w - 4, 12, stroke=0, fill=1)
c.setStrokeColor(ACCENT_NAVY); c.setLineWidth(0.5)
c.rect(sum_x + 2, sum_y + 2, sum_w - 4, 12, stroke=1, fill=0)
label_pt(c, "TOTAL  COOLING  28 TR",
         sum_x + sum_w / 2, sum_y + 4, size=9, bold=True, anchor="center",
         color=ACCENT_NAVY)

# ===================================================================
# Legend (full-width, two main rows)
# ===================================================================
LEG_X = MARGIN_MM * mm
LEG_Y = MARGIN_MM * mm + mm_to_pt(TITLE_MM) + mm_to_pt(4)
LEG_W = PW - 2 * MARGIN_MM * mm
LEG_H = mm_to_pt(LEGEND_MM)

c.setFillColor(LEGEND_BG); c.setStrokeColor(black); c.setLineWidth(0.7)
c.rect(LEG_X, LEG_Y, LEG_W, LEG_H, stroke=1, fill=1)
# Title bar of legend
c.setFillColor(ACCENT_NAVY)
c.rect(LEG_X, LEG_Y + LEG_H - 11, LEG_W, 11, stroke=0, fill=1)
label_pt(c, "LEGEND", LEG_X + 6, LEG_Y + LEG_H - 8.5, size=10, bold=True,
         anchor="left", color=white)

# Layout: 5 columns inside legend
col_w = LEG_W / 5
col_y_top = LEG_Y + LEG_H - 18
col_y_bot = LEG_Y + 6
inner_x0 = LEG_X + 6

# Column 1: Zone fills (2x4 grid)
COL1_X = inner_x0
zone_items = [
    (OFFICE_FILL,   "Office zone"),
    (MEETING_FILL,  "Meeting / training"),
    (SERVER_FILL,   "Server / electrical"),
    (PLANT_FILL,    "AHU plant room"),
    (MECH_FILL,     "Mechanical / pump"),
    (PANTRY_FILL,   "Pantry / breakout"),
    (LOBBY_FILL,    "Reception / lobby"),
    (CORRIDOR_FILL, "Corridor / return plenum"),
    (YARD_FILL,     "Central plant yard"),
]
y_cur = col_y_top - 4
for fill, txt in zone_items:
    c.setFillColor(fill); c.setStrokeColor(black); c.setLineWidth(0.4)
    c.rect(COL1_X, y_cur - 7, 11, 9, stroke=1, fill=1)
    label_pt(c, txt, COL1_X + 14, y_cur - 5, size=8, anchor="left")
    y_cur -= 10

# Column 2: Equipment (rows)
COL2_X = LEG_X + col_w * 1 + 6
y_cur = col_y_top - 4

def col2_item(sym_fn, label_):
    global y_cur
    sym_fn(COL2_X + 6, y_cur - 5)
    label_pt(c, label_, COL2_X + 18, y_cur - 4.5, size=8, anchor="left")
    y_cur -= 12

col2_item(lambda x, y: sym_ahu(c, x, y, code="AHU", cfm=" ", w_pt=22, h_pt=14, name_size=6.5),
          "Air-Handling Unit (AHU)")
col2_item(lambda x, y: sym_fcu(c, x, y, code="FCU", w_pt=14, h_pt=8, label_size=5.5),
          "Fan-Coil Unit (FCU)")
col2_item(lambda x, y: sym_chiller(c, x, y, r_pt=7, code="CH", name_size=5.5, sub_size=4.5),
          "Water-cooled chiller")
col2_item(lambda x, y: sym_ct(c, x, y, r_pt=7, code="CT", name_size=5.5, sub_size=4.5),
          "Cooling tower (induced draft)")
# CRAC - custom
c.setStrokeColor(CRAC_EDGE); c.setFillColor(CRAC_FILL); c.setLineWidth(0.6)
c.rect(COL2_X, y_cur - 11, 13, 9, stroke=1, fill=1)
label_pt(c, "CRAC", COL2_X + 6.5, y_cur - 5, size=5.5, bold=True,
         color=CRAC_EDGE, anchor="center")
label_pt(c, "Precision cooling (server room)", COL2_X + 18, y_cur - 4.5,
         size=8, anchor="left")
y_cur -= 12
col2_item(lambda x, y: sym_pump(c, x, y, r_pt=5.5, code="P", name_size=5.5),
          "Primary chilled-water pump")
col2_item(lambda x, y: sym_diffuser(c, x, y, r_pt=3.5),
          "Supply diffuser (4-way)")
col2_item(lambda x, y: sym_grille(c, x, y, r_pt=3.0),
          "Return-air grille")
col2_item(lambda x, y: sym_thermostat(c, x, y, r_pt=2.5),
          "Zone thermostat (BACnet)")

# Column 3: Services (lines)
COL3_X = LEG_X + col_w * 2 + 6
y_cur = col_y_top - 4

def col3_line(color, label_, dash=None, lw=2.0):
    global y_cur
    c.setStrokeColor(color); c.setLineWidth(lw)
    if dash: c.setDash(*dash)
    c.line(COL3_X, y_cur - 5, COL3_X + 30, y_cur - 5)
    c.setDash()
    label_pt(c, label_, COL3_X + 34, y_cur - 4.5, size=8, anchor="left")
    y_cur -= 11

col3_line(SUPPLY_LINE, "Supply duct (cool air)", lw=2.4)
col3_line(RETURN_LINE, "Return duct (warm air)", dash=(4, 2.5), lw=2.4)
col3_line(CHW_SUPPLY,  "CHW supply  44°F  /  7°C", lw=3.0)
col3_line(CHW_RETURN,  "CHW return  54°F  /  12°C", lw=3.0)
col3_line(black,        "Building / partition wall", lw=3.0)
col3_line(CT_EDGE,      "Condenser water (CW)", dash=(3, 2), lw=2.0)
# Flow direction arrow legend
c.setFillColor(SUPPLY_LINE)
p = c.beginPath()
p.moveTo(COL3_X + 12, y_cur - 1)
p.lineTo(COL3_X + 8, y_cur - 5)
p.lineTo(COL3_X + 16, y_cur - 5)
p.close()
c.drawPath(p, stroke=0, fill=1)
label_pt(c, "Flow direction arrow", COL3_X + 22, y_cur - 4.5, size=8,
         anchor="left")
y_cur -= 11
# North arrow legend
c.saveState()
c.translate(COL3_X + 8, y_cur - 5)
c.setFillColor(black); c.setStrokeColor(black); c.setLineWidth(0.5)
p = c.beginPath()
p.moveTo(0, 5)
p.lineTo(-3, -3.5)
p.lineTo(0, -1)
p.lineTo(3, -3.5)
p.close()
c.drawPath(p, stroke=1, fill=1)
c.restoreState()
label_pt(c, "North arrow", COL3_X + 22, y_cur - 4.5, size=8, anchor="left")

# Column 4: Notes
COL4_X = LEG_X + col_w * 3 + 6
NOTES_W = col_w - 12
c.setFillColor(NOTES_BG); c.setStrokeColor(HexColor("#7a6300"))
c.setLineWidth(0.5)
c.rect(COL4_X, LEG_Y + 4, NOTES_W, LEG_H - 8, stroke=1, fill=1)
label_pt(c, "DESIGN  NOTES", COL4_X + 4, LEG_Y + LEG_H - 14, size=9,
         bold=True, color=HexColor("#7a6300"), anchor="left")
notes = [
    "• Total cooling load (est.): 28 TR",
    "• 1× AHU  15,000 CFM  (4-zone VAV)",
    "• 9× FCUs  zone + meeting + amenity",
    "• 2× 150 TR chillers  (N+1)",
    "• 1× induced-draft cooling tower",
    "• 3× primary CHW pumps  (2W + 1S)",
    "• CHW ΔT 10°F  (44°F / 54°F)",
    "• OA: 20 CFM/person  ASHRAE 62.1",
    "• Filtration: MERV-13 (AHU) + MERV-8 (FCU)",
    "• Controls: BACnet/Modbus DDC, VAV zone dampers",
    "• Acoustics: NC-35 offices, NC-40 open zones",
    "• Server room: dedicated CRAC N+1, 24/7",
]
ny = LEG_Y + LEG_H - 26
for n in notes:
    c.setFillColor(TEXT_DARK); c.setFont("Helvetica", 7.5)
    c.drawString(COL4_X + 4, ny, n)
    ny -= 8

# Column 5: Abbreviations / project
COL5_X = LEG_X + col_w * 4 + 6
label_pt(c, "ABBREVIATIONS", COL5_X, col_y_top, size=9, bold=True,
         color=ACCENT_NAVY, anchor="left")
abbr = [
    "AHU    Air-Handling Unit",
    "FCU    Fan-Coil Unit",
    "VAV    Variable Air Volume",
    "CRAC   Computer Room A/C",
    "CHW    Chilled Water",
    "CW     Condenser Water",
    "OA     Outside Air",
    "RA     Return Air",
    "SA     Supply Air",
    "TR     Ton of Refrigeration",
    "CFM    Cubic Feet / Minute",
    "DDC    Direct Digital Control",
    "MERV   Minimum Efficiency Reporting Value",
    "NC     Noise Criterion",
    "N+1    One redundant unit",
]
ay = col_y_top - 12
for a in abbr:
    label_pt(c, a, COL5_X, ay, size=7.5, anchor="left")
    ay -= 8.5

# ===================================================================
# Title block (bottom-right of page)
# ===================================================================
TB_W_MM = 240
TB_H_MM = 52
TB_X_PT = PW - MARGIN_MM * mm - mm_to_pt(TB_W_MM)
TB_Y_PT = MARGIN_MM * mm
TB_W_PT = mm_to_pt(TB_W_MM)
TB_H_PT = mm_to_pt(TB_H_MM)

c.setFillColor(white); c.setStrokeColor(black); c.setLineWidth(0.9)
c.rect(TB_X_PT, TB_Y_PT, TB_W_PT, TB_H_PT, stroke=1, fill=1)
c.setLineWidth(0.4)
c.line(TB_X_PT + mm_to_pt(80), TB_Y_PT, TB_X_PT + mm_to_pt(80), TB_Y_PT + TB_H_PT)
c.line(TB_X_PT + mm_to_pt(160), TB_Y_PT, TB_X_PT + mm_to_pt(160), TB_Y_PT + TB_H_PT)
c.line(TB_X_PT, TB_Y_PT + mm_to_pt(30), TB_X_PT + TB_W_PT,
       TB_Y_PT + mm_to_pt(30))

# Logo
c.setFillColor(ACCENT_NAVY)
c.rect(TB_X_PT + 4, TB_Y_PT + TB_H_PT - mm_to_pt(28),
       mm_to_pt(72), mm_to_pt(24), stroke=0, fill=1)
c.setFillColor(white); c.setFont("Helvetica-Bold", 16)
c.drawString(TB_X_PT + 6, TB_Y_PT + TB_H_PT - mm_to_pt(20), "AInchors")
c.setFont("Helvetica", 7)
c.drawString(TB_X_PT + 6, TB_Y_PT + TB_H_PT - mm_to_pt(24),
             "HVAC & Smart-Building Engineering")

# Cell 1
c1x = TB_X_PT + mm_to_pt(80) + 4
label_pt(c, "PROJECT", c1x, TB_Y_PT + TB_H_PT - 7, size=7,
         color=TEXT_MUTED, bold=True, anchor="left")
label_pt(c, "Multi-Zone AC System", c1x, TB_Y_PT + TB_H_PT - 18,
         size=11, bold=True, anchor="left")
label_pt(c, "Sample Office Floor — HVAC Layout", c1x,
         TB_Y_PT + TB_H_PT - 26, size=8, anchor="left")
label_pt(c, "DRAWING  HVAC-101  •  Floor Plan", c1x, TB_Y_PT + 4,
         size=8, bold=True, anchor="left", color=ACCENT_NAVY)

# Cell 2
c2x = TB_X_PT + mm_to_pt(160) + 4
label_pt(c, "DATE", c2x, TB_Y_PT + TB_H_PT - 7, size=7,
         color=TEXT_MUTED, bold=True, anchor="left")
label_pt(c, date.today().isoformat(), c2x, TB_Y_PT + TB_H_PT - 18,
         size=11, bold=True, anchor="left")
label_pt(c, "REV.  A", c2x, TB_Y_PT + TB_H_PT - 26, size=8, anchor="left")
label_pt(c, "SHEET  01 of 01", c2x, TB_Y_PT + 4, size=8, bold=True,
         anchor="left", color=ACCENT_NAVY)

# Bottom strip
c.setFillColor(HexColor("#fff5f5"))
c.rect(TB_X_PT, TB_Y_PT, TB_W_PT, mm_to_pt(30), stroke=1, fill=1)
label_pt(c, "SCALE  1 : 100  (A2)   •   Drawing units: millimetres",
         TB_X_PT + 6, TB_Y_PT + 18, size=8, bold=True, anchor="left",
         color=ACCENT_NAVY)
label_pt(c, "DRAWN  Yoda  •  CHECKED  K. Mun  •  APPROVED  A. Foong",
         TB_X_PT + 6, TB_Y_PT + 6, size=7, color=TEXT_MUTED, anchor="left")
label_pt(c, "DEMO / PITCH REFERENCE — NOT FOR CONSTRUCTION",
         TB_X_PT + TB_W_PT - 4, TB_Y_PT + 12, size=8, bold=True,
         color=TEXT_WARN, anchor="right")

# ===================================================================
c.showPage()
c.save()
print("WROTE", OUT, os.path.getsize(OUT), "bytes")
