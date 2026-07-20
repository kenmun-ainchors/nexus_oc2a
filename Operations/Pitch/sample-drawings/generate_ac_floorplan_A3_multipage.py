"""
Multi-zone AC system floor plan — pitch reference (PDF) v3.

Revisions (Angie feedback, 2026-07-20):
  1) Paper size A3 (was A2).
  2) Thicker walls, darker/heavier ducts and pipes for visibility.
  3) Multi-page deliverable:
       - Page 1: Overall A3 floor plan (1 : 100)
       - Pages 2..8: Zoomed-in detail sheets (one per area):
           * Z-A   (Office Zone A)
           * Z-B   (Office Zone B)
           * Z-C   (Office Zone C)
           * Z-D   (Open Office / Collab D)
           * Meeting Rooms
           * Plant / Mechanical Room
           * Server / Electrical Room
  4) Coloured zone fills, readable labels, full legend, title block,
     north arrow and scale bar all preserved.
  5) "DEMO / PITCH REFERENCE — NOT FOR CONSTRUCTION" stamped prominently
     on EVERY page (red ribbon at top + corner stamp).

Output:
  Operations/Pitch/sample-drawings/multi_zone_ac_floorplan_A3_multipage.pdf
"""

import os
from datetime import date
from reportlab.lib.pagesizes import A3, landscape
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, black, white

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
OUT_DIR = (
    "/Users/ainchorsoc2a/.openclaw/workspace/Operations/Pitch/sample-drawings"
)
OUT = os.path.join(OUT_DIR, "multi_zone_ac_floorplan_A3_multipage.pdf")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Page geometry (A3 landscape)
# ---------------------------------------------------------------------------
PAGE = landscape(A3)
PW, PH = PAGE
PH_MM = PH / mm
PW_MM = PW / mm
PT = mm


def mm_to_pt(v):
    return v * mm


# Page layout (mm) — used for both overall & detail pages.
MARGIN_MM = 12
HEADER_MM = 18
RIBBON_MM = 7
LEGEND_MM = 50
TITLE_MM = 46
FRAME_PAD_MM = 4   # inner padding so nothing touches the frame line

# Common drawing helpers --------------------------------------------------------
class _D:
    """Draw-stack values used by drawing routines (filled in per-page)."""

    def __init__(self):
        self.building_x0 = 0  # pt
        self.building_y0 = 0  # pt
        self.scale = 1.0      # pt per plan-mm
        self.frame_left = 0
        self.frame_right = 0
        self.frame_bottom = 0
        self.frame_top = 0
        self.header_y = 0
        self.ribbon_y = 0
        self.legend_y = 0
        self.title_y = 0


def configure_layout(*, scale, frame_left, frame_right, frame_bottom, frame_top,
                     header_y, ribbon_y, legend_y, title_y,
                     building_x0, building_y0):
    d = _D()
    d.scale = scale
    d.frame_left = frame_left
    d.frame_right = frame_right
    d.frame_bottom = frame_bottom
    d.frame_top = frame_top
    d.header_y = header_y
    d.ribbon_y = ribbon_y
    d.legend_y = legend_y
    d.title_y = title_y
    d.building_x0 = building_x0
    d.building_y0 = building_y0
    return d


DRAW: _D = None  # set per-page


def X(x):
    return DRAW.building_x0 + x * DRAW.scale


def Y(y):
    return DRAW.building_y0 + y * DRAW.scale


def S(l):
    return l * DRAW.scale


# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
WALL_STROKE = HexColor("#0d1117")
WALL_FILL = HexColor("#dde2ea")
BG_PAGE = HexColor("#fdfcf7")
RIBBON_BG = HexColor("#a30000")

OFFICE_FILL = HexColor("#cfe0f5")
MEETING_FILL = HexColor("#cfead0")
LOBBY_FILL = HexColor("#f6dcb0")
PANTRY_FILL = HexColor("#f6c9c9")
SERVER_FILL = HexColor("#dccfea")
PLANT_FILL = HexColor("#fbe9a3")
MECH_FILL = HexColor("#e3dccb")
CORRIDOR_FILL = HexColor("#ececec")
YARD_FILL = HexColor("#dceae0")

AHU_FILL = HexColor("#fff1d6")
AHU_EDGE = HexColor("#7a4a00")
FCU_FILL = HexColor("#fff5d0")
FCU_EDGE = HexColor("#0b3a78")
CRAC_FILL = HexColor("#f7d4d4")
CRAC_EDGE = HexColor("#7a1f1f")
CHILLER_FILL = HexColor("#dddddd")
CHILLER_EDGE = black
CT_FILL = HexColor("#cfe7f5")
CT_EDGE = HexColor("#005a87")
PUMP_FILL = HexColor("#fff7c2")
PUMP_EDGE = HexColor("#7a6300")

# Darker, more saturated service colours (per feedback)
SUPPLY_LINE = HexColor("#0a4fb0")   # darker royal blue
RETURN_LINE = HexColor("#5b1f8a")   # darker purple
CHW_SUPPLY = HexColor("#0a6a3a")    # darker green
CHW_RETURN = HexColor("#8a3525")    # darker red-brown
CW_LINE = HexColor("#0a4a78")       # condenser water dark teal-blue

TEXT_DARK = black
TEXT_MUTED = HexColor("#5b6470")
TEXT_WARN = HexColor("#a30000")
ACCENT_NAVY = HexColor("#0b3a78")
LEGEND_BG = HexColor("#f6f7f9")
NOTES_BG = HexColor("#fffbe6")

# Stroke widths (pt) — scaled per page so they stay readable when zoomed
LW = {
    "wall": 2.6,            # was 1.6–1.8 — thicker
    "wall_outer": 4.4,      # was 3.6
    "duct_main": 3.6,       # was 2.6
    "duct_drop": 2.6,       # was 2.2
    "chw_main": 4.4,        # was 3.6–3.8
    "chw_branch": 2.2,      # was 1.4–1.7
    "cw": 2.4,
    "frame": 1.0,
    "dim": 0.45,
    "outer_border": 0.8,
}


# ---------------------------------------------------------------------------
# Generic helpers
# ---------------------------------------------------------------------------
def rect_pt(c, x_pt, y_pt, w_pt, h_pt, stroke=None, fill=None, lw=0.7, radius=0):
    if fill is not None:
        c.setFillColor(fill)
    if stroke is not None:
        c.setStrokeColor(stroke)
    c.setLineWidth(lw)
    if radius > 0:
        c.roundRect(x_pt, y_pt, w_pt, h_pt, radius,
                    stroke=1, fill=1 if fill is not None else 0)
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


# ---------------------------------------------------------------------------
# Symbols
# ---------------------------------------------------------------------------
def sym_ahu(c, cx_pt, cy_pt, code="AHU-1", cfm="15,000 CFM",
            w_pt=80, h_pt=48, name_size=12, cfm_size=9):
    # If the symbol is drawn outside the frame, skip it (detail pages)
    if DRAW and (cx_pt < DRAW.frame_left or cx_pt > DRAW.frame_right
                 or cy_pt < DRAW.frame_bottom or cy_pt > DRAW.frame_top):
        return
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
    if DRAW and (cx_pt < DRAW.frame_left or cx_pt > DRAW.frame_right
                 or cy_pt < DRAW.frame_bottom or cy_pt > DRAW.frame_top):
        return
    c.setStrokeColor(FCU_EDGE)
    c.setFillColor(FCU_FILL)
    c.setLineWidth(1.4)
    c.roundRect(cx_pt - w_pt / 2, cy_pt - h_pt / 2, w_pt, h_pt, 3.0,
                stroke=1, fill=1)
    label_pt(c, code, cx_pt, cy_pt + 0.4, size=label_size, color=FCU_EDGE,
             bold=True, anchor="center")


def sym_chiller(c, cx_pt, cy_pt, r_pt=22, code="CH-1", name_size=11, sub_size=7.5):
    if DRAW and (cx_pt < DRAW.frame_left or cx_pt > DRAW.frame_right
                 or cy_pt < DRAW.frame_bottom or cy_pt > DRAW.frame_top):
        return
    c.setStrokeColor(CHILLER_EDGE)
    c.setFillColor(CHILLER_FILL)
    c.setLineWidth(1.3)
    c.circle(cx_pt, cy_pt, r_pt, stroke=1, fill=1)
    c.setStrokeColor(CHILLER_EDGE)
    c.setLineWidth(0.7)
    c.circle(cx_pt, cy_pt, r_pt * 0.55, stroke=1, fill=0)
    label_pt(c, code, cx_pt, cy_pt + 2, size=name_size, bold=True, anchor="center")
    label_pt(c, "WATER-COOLED", cx_pt, cy_pt - 5, size=sub_size,
             color=TEXT_MUTED, anchor="center")


def sym_ct(c, cx_pt, cy_pt, r_pt=22, code="CT-1", name_size=11, sub_size=7.5):
    if DRAW and (cx_pt < DRAW.frame_left or cx_pt > DRAW.frame_right
                 or cy_pt < DRAW.frame_bottom or cy_pt > DRAW.frame_top):
        return
    c.setStrokeColor(CT_EDGE)
    c.setFillColor(CT_FILL)
    c.setLineWidth(1.3)
    c.circle(cx_pt, cy_pt, r_pt, stroke=1, fill=1)
    c.setStrokeColor(CT_EDGE)
    c.setLineWidth(0.9)
    c.line(cx_pt - r_pt * 0.7, cy_pt, cx_pt + r_pt * 0.7, cy_pt)
    c.line(cx_pt, cy_pt - r_pt * 0.7, cx_pt, cy_pt + r_pt * 0.7)
    c.circle(cx_pt, cy_pt, r_pt * 0.18, stroke=1, fill=1)
    label_pt(c, code, cx_pt, cy_pt - 1, size=name_size, bold=True,
             color=CT_EDGE, anchor="center")
    label_pt(c, "INDUCED DRAFT", cx_pt, cy_pt - r_pt - 4, size=sub_size,
             color=TEXT_MUTED, anchor="center")


def sym_pump(c, cx_pt, cy_pt, r_pt=11, code="P-1", name_size=10):
    if DRAW and (cx_pt < DRAW.frame_left or cx_pt > DRAW.frame_right
                 or cy_pt < DRAW.frame_bottom or cy_pt > DRAW.frame_top):
        return
    c.setStrokeColor(PUMP_EDGE)
    c.setFillColor(PUMP_FILL)
    c.setLineWidth(1.1)
    c.circle(cx_pt, cy_pt, r_pt, stroke=1, fill=1)
    c.setStrokeColor(PUMP_EDGE)
    c.setLineWidth(0.7)
    c.circle(cx_pt, cy_pt, r_pt * 0.4, stroke=0, fill=1)
    label_pt(c, code, cx_pt, cy_pt - r_pt - 3.5, size=name_size, bold=True,
             color=PUMP_EDGE, anchor="center")


def sym_diffuser(c, cx_pt, cy_pt, r_pt=5.5):
    c.setStrokeColor(SUPPLY_LINE)
    c.setFillColor(white)
    c.setLineWidth(1.0)
    c.rect(cx_pt - r_pt, cy_pt - r_pt, 2 * r_pt, 2 * r_pt, stroke=1, fill=1)
    c.setStrokeColor(SUPPLY_LINE)
    c.setLineWidth(1.0)
    c.line(cx_pt - r_pt * 0.7, cy_pt - r_pt * 0.7,
           cx_pt + r_pt * 0.7, cy_pt + r_pt * 0.7)
    c.line(cx_pt - r_pt * 0.7, cy_pt + r_pt * 0.7,
           cx_pt + r_pt * 0.7, cy_pt - r_pt * 0.7)


def sym_grille(c, cx_pt, cy_pt, r_pt=5.0):
    c.setStrokeColor(RETURN_LINE)
    c.setFillColor(white)
    c.setLineWidth(1.0)
    c.setDash(2.0, 1.5)
    c.rect(cx_pt - r_pt, cy_pt - r_pt, 2 * r_pt, 2 * r_pt, stroke=1, fill=1)
    c.setDash()
    c.setStrokeColor(RETURN_LINE)
    c.setLineWidth(0.7)
    for k in (-2, -1, 0, 1, 2):
        c.line(cx_pt - r_pt * 0.85, cy_pt + k * r_pt * 0.4,
               cx_pt + r_pt * 0.85, cy_pt + k * r_pt * 0.4)


def sym_thermostat(c, cx_pt, cy_pt, r_pt=3.4):
    c.setStrokeColor(black)
    c.setFillColor(white)
    c.setLineWidth(0.7)
    c.circle(cx_pt, cy_pt, r_pt, stroke=1, fill=1)
    c.setFillColor(HexColor("#b14a3a"))
    c.circle(cx_pt, cy_pt, r_pt * 0.35, stroke=0, fill=1)


# ---------------------------------------------------------------------------
# Geometry / rooms (plan-mm; y=0 = bottom of building)
# ---------------------------------------------------------------------------
BUILD_W = 36000
BUILD_H = 18000

ROOMS = [
    # (x, y, w, h, code, name, subtitle, fill)
    (1000,  11000, 7500,  6500, "Z-A", "OFFICE  ZONE  A", "8 workstations",          OFFICE_FILL),
    (9000,  11000, 7500,  6500, "Z-B", "OFFICE  ZONE  B", "8 workstations",          OFFICE_FILL),
    (17000, 11000, 7500,  6500, "Z-C", "OFFICE  ZONE  C", "8 workstations",          OFFICE_FILL),
    (25000, 11000, 10000, 6500, "Z-D", "OPEN  OFFICE  /  COLLAB",
     "12 workstations + 2 huddle", OFFICE_FILL),
    (1000,  5000,  8000,  5300, "M-1", "MEETING  ROOM  1", "10 pax boardroom",      MEETING_FILL),
    (9500,  5000,  8000,  5300, "M-2", "MEETING  ROOM  2", "6 pax huddle",          MEETING_FILL),
    (18000, 5000,  8000,  5300, "M-3", "MEETING  ROOM  3", "8 pax training",        MEETING_FILL),
    (26500, 5000,  8500,  5300, "SER", "SERVER  /  ELECTRICAL", "24/7 critical cooling", SERVER_FILL),
    (1000,  500,   7000,  4000, "MECH", "MECHANICAL  /  PUMP", "CHW pumps • expansion", MECH_FILL),
    (8500,  500,   5000,  4000, "PNT", "PANTRY  /  BREAKOUT", "FCU-5 • EF-1",          PANTRY_FILL),
    (14000, 500,   6000,  4000, "REC", "RECEPTION  /  LOBBY", "FCU-6 • vestibule heat", LOBBY_FILL),
    (26500, 500,   8500,  4000, "PLT", "AHU  PLANT  ROOM", "AHU-1 • 15,000 CFM",      PLANT_FILL),
]

# Detail-page crop windows in plan-mm (x0, y0, x1, y1)
DETAIL_REGIONS = {
    "OVERALL":  (-6500, -5800, 36500, 18200),
    "Z-A":      (500,   10200, 9000,  17800),
    "Z-B":      (8700,  10200, 17200, 17800),
    "Z-C":      (16700, 10200, 25200, 17800),
    "Z-D":      (24700, 10200, 35500, 17800),
    "MEET":     (500,   4300,  26200, 11000),
    "PLANT":    (500,   -4000, 35500, 4700),
    "SERVER":   (25700, 4300,  35500, 11000),
}


# ---------------------------------------------------------------------------
# Plan drawing
# ---------------------------------------------------------------------------
def room_rect(c, x, y, w, h, fill, code, name, subtitle=None, lw_pt=None):
    rect_pt(c, X(x), Y(y), S(w), S(h), stroke=WALL_STROKE, fill=fill,
            lw=lw_pt or LW["wall"])
    short_side_m = min(w, h) / 1000.0
    if short_side_m >= 5.5:
        name_size, sub_size, code_size = 14, 9.5, 9
    elif short_side_m >= 4:
        name_size, sub_size, code_size = 12, 8.5, 8.5
    else:
        name_size, sub_size, code_size = 10, 7.5, 8
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
    label_pt(c, code, X(x) + 4, Y(y + h) - 9, size=code_size,
             color=TEXT_MUTED, bold=True, anchor="left")


def push_clip_to_frame(c):
    """Restrict all subsequent plan drawing to the current plan frame.
    Must be balanced by a c.restoreState() after plan geometry is drawn."""
    c.saveState()
    p = c.beginPath()
    p.rect(DRAW.frame_left + mm_to_pt(FRAME_PAD_MM),
           DRAW.frame_bottom + mm_to_pt(FRAME_PAD_MM),
           DRAW.frame_right - DRAW.frame_left - 2 * mm_to_pt(FRAME_PAD_MM),
           DRAW.frame_top - DRAW.frame_bottom - 2 * mm_to_pt(FRAME_PAD_MM))
    c.clipPath(p, stroke=0, fill=0)


def draw_outer_shell(c):
    c.setFillColor(WALL_FILL)
    c.setStrokeColor(WALL_STROKE)
    c.setLineWidth(LW["wall_outer"])
    c.rect(X(0), Y(0), S(BUILD_W), S(BUILD_H), stroke=1, fill=1)


def draw_rooms(c, *, only_codes=None, except_codes=()):
    for (x, y, w, h, code, name, subtitle, fill) in ROOMS:
        if only_codes is not None and code not in only_codes:
            continue
        if code in except_codes:
            continue
        room_rect(c, x, y, w, h, fill, code, name, subtitle)


def draw_corridor(c):
    CORRIDOR_Y0 = 10300
    CORRIDOR_Y1 = 11000
    rect_pt(c, X(1000), Y(CORRIDOR_Y0), S(34000), S(CORRIDOR_Y1 - CORRIDOR_Y0),
            stroke=WALL_STROKE, fill=CORRIDOR_FILL, lw=LW["wall"])
    # door notches
    DOOR_OPENING = 1200
    for cx in (4750, 12750, 20750, 30000):
        c.setStrokeColor(BG_PAGE)
        c.setLineWidth(2.4)
        c.line(X(cx - DOOR_OPENING / 2), Y(CORRIDOR_Y0),
               X(cx + DOOR_OPENING / 2), Y(CORRIDOR_Y0))
    for cx in (5000, 13500, 22000, 30750):
        c.setStrokeColor(BG_PAGE)
        c.setLineWidth(2.4)
        c.line(X(cx - 800), Y(CORRIDOR_Y1), X(cx + 800), Y(CORRIDOR_Y1))
    # Corridor labels (skip on zoomed detail pages where text would overlap
    # the wall — caller can re-add with detail_label_at to put inside the room)
    label_pt(c, "MAIN  CORRIDOR  /  RETURN  AIR  PLENUM",
             X(18000), Y((CORRIDOR_Y0 + CORRIDOR_Y1) / 2 + 4),
             size=11, bold=True, anchor="center", color=TEXT_MUTED)
    label_pt(c, "EXHAUST  &  RETURN  →  AHU",
             X(18000), Y((CORRIDOR_Y0 + CORRIDOR_Y1) / 2 - 7),
             size=8.5, anchor="center", color=TEXT_MUTED)
    # zone identification tabs
    zone_tags = [(4750, "ZONE  A"), (12750, "ZONE  B"),
                 (20750, "ZONE  C"), (30000, "ZONE  D")]
    for (zx, ztxt) in zone_tags:
        label_pt(c, "▼ " + ztxt, X(zx), Y(11100) + 5,
                 size=9, bold=True, color=ACCENT_NAVY, anchor="center")


def draw_yard(c):
    YARD_Y0 = -5500
    YARD_Y1 = 200
    YARD_X0 = 1000
    YARD_X1 = 35000
    rect_pt(c, X(YARD_X0), Y(YARD_Y0), S(YARD_X1 - YARD_X0),
            S(YARD_Y1 - YARD_Y0),
            stroke=WALL_STROKE, fill=YARD_FILL, lw=LW["wall"])
    label_pt(c, "CENTRAL  PLANT  YARD  (chilled-water primary loop)",
             X(18000), Y(YARD_Y1 - 350), size=11, bold=True, color=ACCENT_NAVY,
             anchor="center")
    label_pt(c, "2× water-cooled chillers (N+1)  •  1× induced-draft "
                "cooling tower  •  3× primary CHW pumps (2W + 1S)",
             X(18000), Y(YARD_Y1 - 900), size=8.5, color=TEXT_MUTED,
             anchor="center")


# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------
def draw_equipment(c):
    # AHU inside plant room
    sym_ahu(c, X(30750), Y(2700), code="AHU-1", cfm="15,000 CFM",
            w_pt=80, h_pt=46, name_size=11, cfm_size=9)
    # OA louver
    c.setStrokeColor(black)
    c.setFillColor(white)
    c.setLineWidth(0.8)
    c.rect(X(35000) - 1, Y(2200), 6, S(2500), stroke=1, fill=1)
    c.setStrokeColor(black)
    c.setLineWidth(0.5)
    for k in range(6):
        c.line(X(35000) - 1, Y(2200 + 200 + k * 360),
               X(35000) + 5, Y(2200 + 200 + k * 360))
    label_pt(c, "OA LOUVER", X(35000) - 5, Y(3450), size=8, bold=True,
             anchor="right")

    # FCUs
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

    # CRAC
    c.setStrokeColor(CRAC_EDGE)
    c.setFillColor(CRAC_FILL)
    c.setLineWidth(1.2)
    c.roundRect(X(29000), Y(5500), S(3500), S(1800), 4, stroke=1, fill=1)
    label_pt(c, "CRAC-1", X(30750), Y(6700), size=12, bold=True,
             color=CRAC_EDGE, anchor="center")
    label_pt(c, "Precision cooling  •  N+1", X(30750), Y(6200), size=9,
             color=CRAC_EDGE, anchor="center")


def draw_ahu_supply(c):
    # AHU supply ducts fan out across the top of the building
    """AHU supply riser + cross-building main (heavier)."""
    # Riser from AHU up into top header
    c.setStrokeColor(SUPPLY_LINE)
    c.setLineWidth(LW["duct_main"])
    c.line(X(30750), Y(2950), X(30750), Y(17500))
    # Cross-building main
    c.line(X(30750), Y(17500), X(1500), Y(17500))
    # Drops down to each FCU-1..4 from the cross main
    for fx in (4750, 12750, 20750, 30000):
        c.setStrokeColor(SUPPLY_LINE)
        c.setLineWidth(LW["duct_drop"])
        c.line(X(fx), Y(17500), X(fx), Y(17000))
    # Branch up from AHU to FCU-7/8/9 corridor
    c.setStrokeColor(SUPPLY_LINE)
    c.setLineWidth(LW["duct_drop"])
    c.line(X(30750), Y(4500), X(5000), Y(4500))  # supply to meeting row
    c.line(X(5000), Y(4500), X(5000), Y(7500))
    c.line(X(5000), Y(7500), X(13500), Y(7500))
    c.line(X(13500), Y(7500), X(13500), Y(7500))
    c.line(X(13500), Y(7500), X(22000), Y(7500))
    c.line(X(22000), Y(7500), X(22000), Y(7500))
    # Drops to FCU-7,8,9
    for fx in (5000, 13500, 22000):
        c.setStrokeColor(SUPPLY_LINE)
        c.setLineWidth(LW["duct_drop"])
        c.line(X(fx), Y(8000), X(fx), Y(8000))
    # Branch to pantry/reception
    c.setStrokeColor(SUPPLY_LINE)
    c.setLineWidth(LW["duct_drop"])
    c.line(X(30750), Y(2700), X(11000), Y(2700))
    c.line(X(11000), Y(2700), X(11000), Y(2500))
    c.line(X(11000), Y(2700), X(17000), Y(2700))
    c.line(X(17000), Y(2700), X(17000), Y(2500))


def draw_fcu_supply_branches(c):
    """Per-zone supply trunks (FCU → manifold → diffusers)."""
    zone_diffs = {
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

    def fcu_supply(fcu_x, fcu_y, trunk_top_y, diff_y, diff_xs):
        c.setStrokeColor(SUPPLY_LINE)
        c.setLineWidth(LW["duct_drop"])
        c.line(X(fcu_x), Y(fcu_y + 600), X(fcu_x), Y(trunk_top_y))
        c.line(X(min(diff_xs) - 300), Y(trunk_top_y),
               X(max(diff_xs) + 300), Y(trunk_top_y))
        for dx in diff_xs:
            c.line(X(dx), Y(trunk_top_y), X(dx), Y(diff_y))
        # arrow at trunk top
        c.setFillColor(SUPPLY_LINE)
        p = c.beginPath()
        p.moveTo(X(fcu_x), Y(trunk_top_y + 280))
        p.lineTo(X(fcu_x) - 4, Y(trunk_top_y))
        p.lineTo(X(fcu_x) + 4, Y(trunk_top_y))
        p.close()
        c.drawPath(p, stroke=0, fill=1)

    fcu_supply(4750,  16700, 17400, DIFF_Y_OFFICE, zone_diffs["Z-A"])
    fcu_supply(12750, 16700, 17400, DIFF_Y_OFFICE, zone_diffs["Z-B"])
    fcu_supply(20750, 16700, 17400, DIFF_Y_OFFICE, zone_diffs["Z-C"])
    fcu_supply(30000, 16700, 17400, DIFF_Y_OFFICE, zone_diffs["Z-D"])
    fcu_supply(5000,  8000,  10900, DIFF_Y_MEET,  zone_diffs["M-1"])
    fcu_supply(13500, 8000,  10900, DIFF_Y_MEET,  zone_diffs["M-2"])
    fcu_supply(22000, 8000,  10900, DIFF_Y_MEET,  zone_diffs["M-3"])

    # Diffusers
    for zone, ys in [("Z-A", DIFF_Y_OFFICE), ("Z-B", DIFF_Y_OFFICE),
                     ("Z-C", DIFF_Y_OFFICE), ("Z-D", DIFF_Y_OFFICE),
                     ("M-1", DIFF_Y_MEET), ("M-2", DIFF_Y_MEET),
                     ("M-3", DIFF_Y_MEET)]:
        for dx in zone_diffs[zone]:
            sym_diffuser(c, X(dx), Y(ys), r_pt=5.5)


def draw_return_drops(c):
    def return_drop(gx, gy, trunk_y):
        c.setStrokeColor(RETURN_LINE)
        c.setLineWidth(LW["duct_drop"])
        c.setDash(4.0, 2.5)
        c.line(X(gx), Y(gy + 600), X(gx), Y(trunk_y))
        c.setDash()

    office_grille_x = {
        "Z-A": [3500, 7500],
        "Z-B": [11200, 15200],
        "Z-C": [19200, 23200],
        "Z-D": [28000, 31000, 33500],
    }
    for xs in office_grille_x.values():
        for gx in xs:
            return_drop(gx, 14100, 10650)
            sym_grille(c, X(gx), Y(14100), r_pt=5.0)

    meet_grille_x = {
        "M-1": [3500, 7000],
        "M-2": [12000, 15500],
        "M-3": [20500, 24000],
    }
    for xs in meet_grille_x.values():
        for gx in xs:
            return_drop(gx, 8000, 11000)
            sym_grille(c, X(gx), Y(8000), r_pt=4.5)

    # Pantry / reception diffusers + grilles
    sym_diffuser(c, X(11000), Y(1800), r_pt=4.5)
    sym_grille(c,    X(13000), Y(1800), r_pt=4.0)
    sym_diffuser(c, X(16500), Y(1800), r_pt=4.5)
    sym_diffuser(c, X(18000), Y(1800), r_pt=4.5)
    sym_grille(c,    X(19000), Y(1800), r_pt=4.0)

    # Corridor return trunk
    c.setStrokeColor(RETURN_LINE)
    c.setLineWidth(LW["duct_main"])
    c.setDash(4, 2.5)
    c.line(X(1000), Y(10650), X(35000), Y(10650))
    c.setDash()
    # RA drop into AHU plant
    c.setStrokeColor(RETURN_LINE)
    c.setLineWidth(LW["duct_main"])
    c.setDash(4, 2.5)
    c.line(X(30750), Y(10650), X(30750), Y(4500))
    c.setDash()
    c.setStrokeColor(RETURN_LINE)
    c.setLineWidth(2.0)
    c.line(X(30750), Y(4500), X(30750), Y(4000))
    label_pt(c, "RA  →", X(30750) + 6, Y(7300), size=9, bold=True,
             color=RETURN_LINE, anchor="left")


def draw_thermostats(c):
    thermo = [
        (4500,  14000), (12500, 14000), (20500, 14000), (30000, 14000),
        (5000,  8200),  (13500, 8200),  (22000, 8200),
        (30500, 8500), (17000, 2500), (11000, 2500),
    ]
    for (tx, ty) in thermo:
        sym_thermostat(c, X(tx), Y(ty), r_pt=3.0)


def draw_yard_equipment(c):
    sym_chiller(c, X(8000),  Y(-1700), r_pt=22, code="CH-1", name_size=11, sub_size=7.5)
    sym_chiller(c, X(11500), Y(-1700), r_pt=22, code="CH-2", name_size=11, sub_size=7.5)
    label_pt(c, "150 TR", X(8000),  Y(-3300), size=9, bold=True, anchor="center")
    label_pt(c, "150 TR", X(11500), Y(-3300), size=9, bold=True, anchor="center")
    sym_ct(c, X(16000), Y(-1700), r_pt=22, code="CT-1", name_size=11, sub_size=7.5)
    for px, code in [(21000, "P-1"), (22500, "P-2"), (24000, "P-3")]:
        sym_pump(c, X(px), Y(-1700), r_pt=12, code=code, name_size=10)
    label_pt(c, "Primary CHW Pumps", X(22500), Y(-3300), size=9, bold=True,
             color=TEXT_MUTED, anchor="center")


def draw_chw_pipes(c):
    """Heavy chilled-water (supply + return) and condenser-water piping."""
    hdr_sup_y = -700
    hdr_ret_y = -1200
    # Yard headers
    c.setStrokeColor(CHW_SUPPLY)
    c.setLineWidth(LW["chw_main"])
    c.line(X(5000), Y(hdr_sup_y), X(33000), Y(hdr_sup_y))
    c.setStrokeColor(CHW_RETURN)
    c.setLineWidth(LW["chw_main"])
    c.line(X(5000), Y(hdr_ret_y), X(33000), Y(hdr_ret_y))
    # Chiller drops
    for cx in (8000, 11500):
        c.setStrokeColor(CHW_SUPPLY)
        c.setLineWidth(LW["chw_branch"])
        c.line(X(cx), Y(hdr_sup_y), X(cx), Y(-1200))
        c.setStrokeColor(CHW_RETURN)
        c.setLineWidth(LW["chw_branch"])
        c.line(X(cx), Y(hdr_ret_y), X(cx), Y(-2200))
    # CW drop to cooling tower
    c.setStrokeColor(CW_LINE)
    c.setLineWidth(LW["cw"])
    c.setDash(3, 2)
    c.line(X(16000), Y(hdr_sup_y), X(16000), Y(-1200))
    c.setDash()
    # Pump drops
    for px in (21000, 22500, 24000):
        c.setStrokeColor(CHW_SUPPLY)
        c.setLineWidth(LW["chw_branch"])
        c.line(X(px), Y(hdr_sup_y), X(px), Y(-1100))

    # Riser to mech room
    MECH_TOP_X = 3000
    MECH_SUP_Y = 4500 + 600
    MECH_RET_Y = 4500 + 200
    c.setStrokeColor(CHW_SUPPLY)
    c.setLineWidth(LW["chw_main"])
    c.line(X(5000), Y(hdr_sup_y), X(MECH_TOP_X), Y(hdr_sup_y))
    c.line(X(MECH_TOP_X), Y(hdr_sup_y), X(MECH_TOP_X), Y(MECH_SUP_Y))
    c.setStrokeColor(CHW_RETURN)
    c.setLineWidth(LW["chw_main"])
    c.line(X(5000), Y(hdr_ret_y), X(4200), Y(hdr_ret_y))
    c.line(X(4200), Y(hdr_ret_y), X(4200), Y(MECH_RET_Y))
    # Mech internal headers
    c.setStrokeColor(CHW_SUPPLY)
    c.setLineWidth(LW["chw_branch"])
    c.line(X(MECH_TOP_X), Y(MECH_SUP_Y), X(8000), Y(MECH_SUP_Y))
    c.setStrokeColor(CHW_RETURN)
    c.setLineWidth(LW["chw_branch"])
    c.line(X(4200), Y(MECH_RET_Y), X(8000), Y(MECH_RET_Y))

    # Cross-building CHW mains
    c.setStrokeColor(CHW_SUPPLY)
    c.setLineWidth(LW["chw_main"])
    c.line(X(8000), Y(MECH_SUP_Y), X(8000), Y(11800))
    c.line(X(8000), Y(11800), X(30750), Y(11800))
    c.line(X(30750), Y(11800), X(30750), Y(5500))
    c.line(X(30750), Y(5500), X(30750), Y(4000))
    c.setStrokeColor(CHW_RETURN)
    c.setLineWidth(LW["chw_main"])
    c.line(X(8000), Y(MECH_RET_Y), X(8000), Y(12000))
    c.line(X(8000), Y(12000), X(30750), Y(12000))
    c.line(X(30750), Y(12000), X(30750), Y(5000))
    c.line(X(30750), Y(5000), X(30750), Y(3300))

    # Flow chevrons
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
        c.drawPath(p, stroke=0, fill=1)

    # Typical CHW tap to FCU
    c.setStrokeColor(CHW_SUPPLY)
    c.setLineWidth(LW["chw_branch"])
    c.setDash(2.5, 2.0)
    c.line(X(4750), Y(11800), X(4750), Y(17000))
    c.setDash()
    c.setStrokeColor(CHW_RETURN)
    c.setLineWidth(LW["chw_branch"])
    c.setDash(2.5, 2.0)
    c.line(X(4500), Y(12000), X(4500), Y(17000))
    c.setDash()
    label_pt(c, "CHW  TAP  —  TYP.", X(5300), Y(14000), size=7, bold=True,
             color=CHW_SUPPLY, anchor="left")

    # Pipe-label callouts
    def pipe_label(x, y, text_, color):
        w, h = 95, 11
        x_pt = X(x); y_pt = Y(y)
        c.setFillColor(white)
        c.setStrokeColor(color)
        c.setLineWidth(0.8)
        c.roundRect(x_pt - w / 2, y_pt - h / 2, w, h, 2, stroke=1, fill=1)
        label_pt(c, text_, x_pt, y_pt - 1.5, size=7.5, bold=True,
                 color=color, anchor="center")

    pipe_label(10500, 11800, "CHW  SUPPLY  44°F", CHW_SUPPLY)
    pipe_label(10500, 12000, "CHW  RETURN  54°F", CHW_RETURN)


# ---------------------------------------------------------------------------
# Dimensions
# ---------------------------------------------------------------------------
def dim_h_pt(c, x1_pt, x2_pt, y_pt, text_, tick=4.0):
    c.setStrokeColor(HexColor("#444444"))
    c.setLineWidth(LW["dim"])
    c.line(x1_pt, y_pt - tick, x1_pt, y_pt + tick)
    c.line(x2_pt, y_pt - tick, x2_pt, y_pt + tick)
    c.line(x1_pt, y_pt, x2_pt, y_pt)
    label_pt(c, text_, (x1_pt + x2_pt) / 2, y_pt + 1.5, size=7.5,
             color=HexColor("#444444"), bold=True, anchor="center")


def dim_v_pt(c, y1_pt, y2_pt, x_pt, text_, tick=4.0):
    c.setStrokeColor(HexColor("#444444"))
    c.setLineWidth(LW["dim"])
    c.line(x_pt - tick, y1_pt, x_pt + tick, y1_pt)
    c.line(x_pt - tick, y2_pt, x_pt + tick, y2_pt)
    c.line(x_pt, y1_pt, x_pt, y2_pt)
    c.saveState()
    c.translate(x_pt - 2.5, (y1_pt + y2_pt) / 2)
    c.rotate(90)
    label_pt(c, text_, 0, 0, size=7.5, color=HexColor("#444444"),
             bold=True, anchor="center")
    c.restoreState()


def draw_dimensions_overall(c):
    dim_h_pt(c, X(0), X(BUILD_W), Y(BUILD_H) + 14, "36 000  (36.0 m)")
    dim_v_pt(c, Y(0), Y(BUILD_H), X(0) - 14, "18 000  (18.0 m)")
    dim_h_pt(c, X(1000),  X(8500),  Y(17500) + 8, "7 500")
    dim_h_pt(c, X(9000),  X(16500), Y(17500) + 8, "7 500")
    dim_h_pt(c, X(17000), X(24500), Y(17500) + 8, "7 500")
    dim_h_pt(c, X(25000), X(35000), Y(17500) + 8, "10 000")


# ---------------------------------------------------------------------------
# North arrow + scale bar
# ---------------------------------------------------------------------------
def north_arrow(c, x_pt, y_pt, size_pt=16, label="N"):
    c.saveState()
    c.translate(x_pt, y_pt)
    c.setFillColor(black)
    c.setStrokeColor(black)
    c.setLineWidth(0.7)
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
    label_pt(c, label, 0, size_pt + 5, size=12, bold=True, anchor="center")
    c.restoreState()


def scale_bar(c, x_pt, y_pt, segments=5, seg_m=2, label_size=8,
              title="SCALE  0"):
    seg_len_pt = seg_m * 12 * mm / 1000.0
    total = segments * seg_len_pt
    for i in range(segments):
        c.setFillColor(black if i % 2 == 0 else white)
        c.setStrokeColor(black)
        c.setLineWidth(0.4)
        c.rect(x_pt + i * seg_len_pt, y_pt, seg_len_pt, 4.0, stroke=1, fill=1)
    c.setStrokeColor(black)
    c.setLineWidth(0.6)
    c.rect(x_pt, y_pt, total, 4.0, stroke=1, fill=0)
    for i in range(segments + 1):
        label_pt(c, f"{i*seg_m}", x_pt + i * seg_len_pt, y_pt - 4.5,
                 size=label_size, anchor="center")
    label_pt(c, f"{title}   {seg_m}   {2*seg_m}   {3*seg_m}   "
                 f"{4*seg_m}   {5*seg_m}  m",
             x_pt + total / 2, y_pt + 7, size=label_size + 0.5, bold=True,
             anchor="center")


# ---------------------------------------------------------------------------
# Page chrome (frame, header, ribbon, legend, title block)
# ---------------------------------------------------------------------------
def draw_page_chrome(c, *, page_title, sheet_no, total_sheets,
                     region_label=None, region_rect=None, overall_rect=None):
    """Draw everything that lives outside the plan: page bg, border, header,
    warning ribbon, plan frame, legend, title block.

    The plan frame is filled with BG_PAGE so any plan area not covered by
    geometry still reads as paper.  Legend always shows.  Key-plan inset
    is added on detail pages (region_rect + overall_rect, both in plan-mm).
    """
    # Paper background
    rect_pt(c, 0, 0, PW, PH, stroke=None, fill=BG_PAGE)
    # Outer page border
    c.setStrokeColor(HexColor("#222222"))
    c.setLineWidth(LW["outer_border"])
    c.rect(mm_to_pt(MARGIN_MM / 2), mm_to_pt(MARGIN_MM / 2),
           PW - mm_to_pt(MARGIN_MM), PH - mm_to_pt(MARGIN_MM),
           stroke=1, fill=0)

    # Header strip
    hdr_y_title = PH - mm_to_pt(6) - 11
    hdr_y_sub = PH - mm_to_pt(6) - 23
    label_pt(c, "MULTI-ZONE AIR CONDITIONING — SAMPLE FLOOR PLAN",
             mm_to_pt(MARGIN_MM), hdr_y_title, size=22, bold=True,
             anchor="left", color=ACCENT_NAVY)
    sub = ("4 office zones + corridor return  •  1× AHU (15,000 CFM) + 9× FCUs"
           "  •  Chilled-water primary plant (2× 150 TR + induced-draft tower)")
    label_pt(c, sub, mm_to_pt(MARGIN_MM), hdr_y_sub, size=10,
             color=TEXT_MUTED, anchor="left")

    # Warning ribbon
    ribbon_top = PH - mm_to_pt(MARGIN_MM + HEADER_MM)
    ribbon_bot = PH - mm_to_pt(MARGIN_MM + HEADER_MM + RIBBON_MM)
    c.setFillColor(RIBBON_BG)
    c.setStrokeColor(RIBBON_BG)
    c.rect(0, ribbon_bot, PW, ribbon_top - ribbon_bot, stroke=0, fill=1)
    c.setFillColor(white)
    label_pt(c, "DEMO / PITCH REFERENCE — NOT FOR CONSTRUCTION",
             PW / 2, ribbon_bot + (ribbon_top - ribbon_bot) / 2 - 3.5,
             size=11, bold=True, anchor="center")

    # Plan-area frame
    c.setStrokeColor(black)
    c.setLineWidth(LW["frame"])
    c.rect(DRAW.frame_left, DRAW.frame_bottom,
           DRAW.frame_right - DRAW.frame_left,
           DRAW.frame_top - DRAW.frame_bottom, stroke=1, fill=1)
    # Inner frame (light double-line)
    c.setStrokeColor(HexColor("#888888"))
    c.setLineWidth(0.3)
    c.rect(DRAW.frame_left + 1.5, DRAW.frame_bottom + 1.5,
           (DRAW.frame_right - DRAW.frame_left) - 3,
           (DRAW.frame_top - DRAW.frame_bottom) - 3, stroke=1, fill=0)

    # Plan-area title (top-right of plan frame)
    pt_x = DRAW.frame_right - 6
    pt_y = DRAW.frame_top - 8
    label_pt(c, f"FLOOR  PLAN  —  {page_title}", pt_x, pt_y, size=11,
             bold=True, color=ACCENT_NAVY, anchor="right")
    label_pt(c, "Engineering scale 1 : 100  •  Drawing units: millimetres",
             pt_x, pt_y - 11, size=8, color=TEXT_MUTED, anchor="right")

    # North + scale bar (top-left of plan)
    north_arrow(c, DRAW.frame_left + 18, DRAW.frame_top - 18)
    scale_bar(c, DRAW.frame_left + 60, DRAW.frame_top - 18)

    # Key-plan inset (detail pages only)
    if region_rect is not None and overall_rect is not None:
        draw_keyplan_inset(c, region_rect, overall_rect, region_label)

    # Legend + title block
    draw_legend(c)
    draw_title_block(c, sheet_no, total_sheets, page_title)


def draw_keyplan_inset(c, region_rect, overall_rect, label):
    """Mini key-plan showing the overall building with the cropped region
    highlighted.  Drawn in the upper-right of the plan frame."""
    # Geometry in plan-mm:
    ox0, oy0, ox1, oy1 = overall_rect
    rx0, ry0, rx1, ry1 = region_rect
    # Target inset size: 110 mm wide, aspect ratio of overall area
    inset_w_mm = 110
    overall_w_mm = (ox1 - ox0) / 1000.0
    overall_h_mm = (oy1 - oy0) / 1000.0
    inset_h_mm = inset_w_mm * (overall_h_mm / overall_w_mm)

    # Place top-right of plan frame with a 6 mm margin
    inset_w_pt = mm_to_pt(inset_w_mm)
    inset_h_pt = mm_to_pt(inset_h_mm)
    inset_x = DRAW.frame_right - inset_w_pt - mm_to_pt(6)
    inset_y = DRAW.frame_top - inset_h_pt - mm_to_pt(36)  # leave room for title

    # Background
    rect_pt(c, inset_x, inset_y, inset_w_pt, inset_h_pt,
            stroke=HexColor("#222222"), fill=white, lw=0.6)
    label_pt(c, "KEY PLAN — region highlighted", inset_x + 3,
             inset_y + inset_h_pt - 7, size=7, bold=True, color=ACCENT_NAVY,
             anchor="left")

    # Map overall_rect into inset coordinates
    s_x = (inset_w_pt - 6) / (ox1 - ox0)
    s_y = (inset_h_pt - 14) / (oy1 - oy0)
    s_min = min(s_x, s_y)
    pad_x = (inset_w_pt - (ox1 - ox0) * s_min) / 2
    pad_y = (inset_h_pt - 14 - (oy1 - oy0) * s_min) / 2
    base_x = inset_x + pad_x
    base_y = inset_y + pad_y

    def to_inset(x, y):
        return (base_x + (x - ox0) * s_min,
                base_y + (y - oy0) * s_min)

    # Building outline
    bx0, by0 = to_inset(0, 0)
    bx1, by1 = to_inset(BUILD_W, BUILD_H)
    c.setFillColor(HexColor("#f4f4ee"))
    c.setStrokeColor(HexColor("#333333"))
    c.setLineWidth(0.5)
    c.rect(bx0, by0, bx1 - bx0, by1 - by0, stroke=1, fill=1)

    # Yard outline
    yx0, yy0 = to_inset(1000, -5500)
    yx1, yy1 = to_inset(35000, 200)
    c.setFillColor(HexColor("#dceae0"))
    c.setStrokeColor(HexColor("#333333"))
    c.setLineWidth(0.4)
    c.rect(yx0, yy0, yx1 - yx0, yy1 - yy0, stroke=1, fill=1)

    # Region highlight
    rx0p, ry0p = to_inset(rx0, ry0)
    rx1p, ry1p = to_inset(rx1, ry1)
    c.setFillColor(HexColor("#a30000"))
    c.setStrokeColor(HexColor("#a30000"))
    c.setLineWidth(1.0)
    # Clip to building extents (highlight = inside building OR in yard)
    c.rect(rx0p, ry0p, rx1p - rx0p, ry1p - ry0p, stroke=1, fill=0)
    # label the region
    label_pt(c, label or "", (rx0p + rx1p) / 2, (ry0p + ry1p) / 2 - 3,
             size=8, bold=True, color=HexColor("#a30000"), anchor="center")


# ---------------------------------------------------------------------------
# Legend
# ---------------------------------------------------------------------------
def draw_legend(c):
    LEG_X = mm_to_pt(MARGIN_MM)
    LEG_Y = mm_to_pt(MARGIN_MM)
    LEG_W = PW - 2 * mm_to_pt(MARGIN_MM)
    LEG_H = mm_to_pt(LEGEND_MM)

    c.setFillColor(LEGEND_BG)
    c.setStrokeColor(black)
    c.setLineWidth(0.7)
    c.rect(LEG_X, LEG_Y, LEG_W, LEG_H, stroke=1, fill=1)
    c.setFillColor(ACCENT_NAVY)
    c.rect(LEG_X, LEG_Y + LEG_H - 11, LEG_W, 11, stroke=0, fill=1)
    label_pt(c, "LEGEND", LEG_X + 6, LEG_Y + LEG_H - 8.5, size=10, bold=True,
             anchor="left", color=white)

    col_w = LEG_W / 5
    col_y_top = LEG_Y + LEG_H - 18
    col_y_bot = LEG_Y + 6
    inner_x0 = LEG_X + 6

    # Col 1: zone fills
    zone_items = [
        (OFFICE_FILL, "Office zone"),
        (MEETING_FILL, "Meeting / training"),
        (SERVER_FILL, "Server / electrical"),
        (PLANT_FILL, "AHU plant room"),
        (MECH_FILL, "Mechanical / pump"),
        (PANTRY_FILL, "Pantry / breakout"),
        (LOBBY_FILL, "Reception / lobby"),
        (CORRIDOR_FILL, "Corridor / return plenum"),
        (YARD_FILL, "Central plant yard"),
    ]
    y_cur = col_y_top - 4
    for fill, txt in zone_items:
        c.setFillColor(fill)
        c.setStrokeColor(black)
        c.setLineWidth(0.4)
        c.rect(inner_x0, y_cur - 7, 11, 9, stroke=1, fill=1)
        label_pt(c, txt, inner_x0 + 14, y_cur - 5, size=8, anchor="left")
        y_cur -= 10

    # Col 2: equipment
    COL2_X = LEG_X + col_w * 1 + 6
    y_cur = col_y_top - 4

    def col2_item(sym_fn, lab):
        nonlocal y_cur
        sym_fn(COL2_X + 6, y_cur - 5)
        label_pt(c, lab, COL2_X + 18, y_cur - 4.5, size=8, anchor="left")
        y_cur -= 12

    col2_item(lambda x, y: sym_ahu(c, x, y, code="AHU", cfm=" ", w_pt=22,
                                   h_pt=14, name_size=6.5),
              "Air-Handling Unit (AHU)")
    col2_item(lambda x, y: sym_fcu(c, x, y, code="FCU", w_pt=14, h_pt=8,
                                   label_size=5.5),
              "Fan-Coil Unit (FCU)")
    col2_item(lambda x, y: sym_chiller(c, x, y, r_pt=7, code="CH",
                                      name_size=5.5, sub_size=4.5),
              "Water-cooled chiller")
    col2_item(lambda x, y: sym_ct(c, x, y, r_pt=7, code="CT",
                                  name_size=5.5, sub_size=4.5),
              "Cooling tower (induced draft)")
    c.setStrokeColor(CRAC_EDGE)
    c.setFillColor(CRAC_FILL)
    c.setLineWidth(0.6)
    c.rect(COL2_X, y_cur - 11, 13, 9, stroke=1, fill=1)
    label_pt(c, "CRAC", COL2_X + 6.5, y_cur - 5, size=5.5, bold=True,
             color=CRAC_EDGE, anchor="center")
    label_pt(c, "Precision cooling (server room)", COL2_X + 18, y_cur - 4.5,
             size=8, anchor="left")
    y_cur -= 12
    col2_item(lambda x, y: sym_pump(c, x, y, r_pt=5.5, code="P",
                                    name_size=5.5),
              "Primary chilled-water pump")
    col2_item(lambda x, y: sym_diffuser(c, x, y, r_pt=3.5),
              "Supply diffuser (4-way)")
    col2_item(lambda x, y: sym_grille(c, x, y, r_pt=3.0),
              "Return-air grille")
    col2_item(lambda x, y: sym_thermostat(c, x, y, r_pt=2.5),
              "Zone thermostat (BACnet)")

    # Col 3: services
    COL3_X = LEG_X + col_w * 2 + 6
    y_cur = col_y_top - 4

    def col3_line(color, lab, dash=None, lw=2.0):
        nonlocal y_cur
        c.setStrokeColor(color)
        c.setLineWidth(lw)
        if dash: c.setDash(*dash)
        c.line(COL3_X, y_cur - 5, COL3_X + 30, y_cur - 5)
        c.setDash()
        label_pt(c, lab, COL3_X + 34, y_cur - 4.5, size=8, anchor="left")
        y_cur -= 11

    col3_line(SUPPLY_LINE, "Supply duct (cool air)", lw=3.0)
    col3_line(RETURN_LINE, "Return duct (warm air)", dash=(4, 2.5), lw=3.0)
    col3_line(CHW_SUPPLY,  "CHW supply  44°F  /  7°C", lw=3.6)
    col3_line(CHW_RETURN,  "CHW return  54°F  /  12°C", lw=3.6)
    col3_line(CW_LINE,     "Condenser water (CW)", dash=(3, 2), lw=2.4)
    col3_line(black,       "Building / partition wall", lw=3.0)
    c.setFillColor(SUPPLY_LINE)
    p = c.beginPath()
    p.moveTo(COL3_X + 12, y_cur - 1)
    p.lineTo(COL3_X + 8, y_cur - 5)
    p.lineTo(COL3_X + 16, y_cur - 5)
    c.drawPath(p, stroke=0, fill=1)
    label_pt(c, "Flow direction arrow", COL3_X + 22, y_cur - 4.5, size=8,
             anchor="left")
    y_cur -= 11
    c.saveState()
    c.translate(COL3_X + 8, y_cur - 5)
    c.setFillColor(black)
    c.setStrokeColor(black)
    c.setLineWidth(0.5)
    p = c.beginPath()
    p.moveTo(0, 5)
    p.lineTo(-3, -3.5)
    p.lineTo(0, -1)
    p.lineTo(3, -3.5)
    c.drawPath(p, stroke=1, fill=1)
    c.restoreState()
    label_pt(c, "North arrow", COL3_X + 22, y_cur - 4.5, size=8, anchor="left")

    # Col 4: notes
    COL4_X = LEG_X + col_w * 3 + 6
    NOTES_W = col_w - 12
    c.setFillColor(NOTES_BG)
    c.setStrokeColor(HexColor("#7a6300"))
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
        c.setFillColor(TEXT_DARK)
        c.setFont("Helvetica", 7.5)
        c.drawString(COL4_X + 4, ny, n)
        ny -= 8

    # Col 5: abbreviations
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


# ---------------------------------------------------------------------------
# Title block
# ---------------------------------------------------------------------------
def draw_title_block(c, sheet_no, total_sheets, page_title):
    TB_W_MM = 240
    TB_H_MM = 42
    TB_X_PT = PW - mm_to_pt(MARGIN_MM) - mm_to_pt(TB_W_MM)
    TB_Y_PT = mm_to_pt(LEGEND_MM) + mm_to_pt(4)
    TB_W_PT = mm_to_pt(TB_W_MM)
    TB_H_PT = mm_to_pt(TB_H_MM)

    c.setFillColor(white)
    c.setStrokeColor(black)
    c.setLineWidth(0.9)
    c.rect(TB_X_PT, TB_Y_PT, TB_W_PT, TB_H_PT, stroke=1, fill=1)
    c.setLineWidth(0.4)
    c.line(TB_X_PT + mm_to_pt(80), TB_Y_PT, TB_X_PT + mm_to_pt(80),
           TB_Y_PT + TB_H_PT)
    c.line(TB_X_PT + mm_to_pt(160), TB_Y_PT, TB_X_PT + mm_to_pt(160),
           TB_Y_PT + TB_H_PT)
    c.line(TB_X_PT, TB_Y_PT + mm_to_pt(24), TB_X_PT + TB_W_PT,
           TB_Y_PT + mm_to_pt(24))

    # Logo
    c.setFillColor(ACCENT_NAVY)
    c.rect(TB_X_PT + 4, TB_Y_PT + TB_H_PT - mm_to_pt(22),
           mm_to_pt(72), mm_to_pt(18), stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(TB_X_PT + 6, TB_Y_PT + TB_H_PT - mm_to_pt(15), "AInchors")
    c.setFont("Helvetica", 6.5)
    c.drawString(TB_X_PT + 6, TB_Y_PT + TB_H_PT - mm_to_pt(19),
                 "HVAC & Smart-Building Engineering")

    c1x = TB_X_PT + mm_to_pt(80) + 4
    label_pt(c, "PROJECT", c1x, TB_Y_PT + TB_H_PT - 6, size=7,
             color=TEXT_MUTED, bold=True, anchor="left")
    label_pt(c, "Multi-Zone AC System", c1x, TB_Y_PT + TB_H_PT - 15,
             size=10, bold=True, anchor="left")
    label_pt(c, page_title, c1x, TB_Y_PT + TB_H_PT - 21, size=7.5,
             anchor="left")
    label_pt(c, f"DRAWING  HVAC-101  •  {sheet_no:02d}/{total_sheets:02d}",
             c1x, TB_Y_PT + 4, size=8, bold=True, anchor="left",
             color=ACCENT_NAVY)

    c2x = TB_X_PT + mm_to_pt(160) + 4
    label_pt(c, "DATE", c2x, TB_Y_PT + TB_H_PT - 6, size=7,
             color=TEXT_MUTED, bold=True, anchor="left")
    label_pt(c, date.today().isoformat(), c2x, TB_Y_PT + TB_H_PT - 15,
             size=10, bold=True, anchor="left")
    label_pt(c, "REV.  B  (A3 multipage)", c2x, TB_Y_PT + TB_H_PT - 21,
             size=7.5, anchor="left")
    label_pt(c, "SCALE  1 : 100  (A3)", c2x, TB_Y_PT + 4, size=8,
             bold=True, anchor="left", color=ACCENT_NAVY)

    # Warning strip
    c.setFillColor(HexColor("#fff5f5"))
    c.rect(TB_X_PT, TB_Y_PT, TB_W_PT, mm_to_pt(24), stroke=1, fill=1)
    label_pt(c, "DEMO / PITCH REFERENCE — NOT FOR CONSTRUCTION",
             TB_X_PT + TB_W_PT - 4, TB_Y_PT + 9, size=8, bold=True,
             color=TEXT_WARN, anchor="right")


# ---------------------------------------------------------------------------
# Equipment schedule box (overall page only)
# ---------------------------------------------------------------------------
def draw_equipment_schedule(c):
    sum_w = mm_to_pt(60)
    sum_h = mm_to_pt(56)
    sum_x = DRAW.frame_right - sum_w - mm_to_pt(6)
    sum_y = DRAW.frame_top - sum_h - mm_to_pt(72)  # below key plan / title
    # Place in top-left of plan area instead (avoid clash with key plan)
    sum_x = DRAW.frame_left + mm_to_pt(6)
    sum_y = DRAW.frame_top - sum_h - mm_to_pt(36)

    c.setFillColor(LEGEND_BG)
    c.setStrokeColor(black)
    c.setLineWidth(0.7)
    c.rect(sum_x, sum_y, sum_w, sum_h, stroke=1, fill=1)
    c.setFillColor(ACCENT_NAVY)
    c.rect(sum_x, sum_y + sum_h - 10, sum_w, 10, stroke=0, fill=1)
    label_pt(c, "EQUIPMENT  SCHEDULE", sum_x + sum_w / 2,
             sum_y + sum_h - 7.5, size=8, bold=True, anchor="center", color=white)
    sched = [
        "1× AHU  •  15,000 CFM",
        "9× FCU  •  18,800 CFM total",
        "2× Chiller  •  300 TR",
        "1× Cooling tower",
        "3× CHW pumps  (2W + 1S)",
        "1× CRAC  •  N+1 server",
    ]
    for i, line in enumerate(sched):
        label_pt(c, line, sum_x + 4, sum_y + sum_h - 18 - i * 7,
                 size=7.5, anchor="left")
    c.setFillColor(white)
    c.rect(sum_x + 2, sum_y + 2, sum_w - 4, 10, stroke=0, fill=1)
    c.setStrokeColor(ACCENT_NAVY)
    c.setLineWidth(0.5)
    c.rect(sum_x + 2, sum_y + 2, sum_w - 4, 10, stroke=1, fill=0)
    label_pt(c, "TOTAL  COOLING  28 TR", sum_x + sum_w / 2, sum_y + 3.5,
             size=8, bold=True, anchor="center", color=ACCENT_NAVY)


# ---------------------------------------------------------------------------
# Page builders
# ---------------------------------------------------------------------------
def build_overall_page(c, sheet_no, total_sheets):
    """A3 overall floor plan."""
    # Plan area
    PLAN_LEFT_PT = mm_to_pt(MARGIN_MM)
    PLAN_RIGHT_PT = PW - mm_to_pt(MARGIN_MM)
    PLAN_TOP_PT = PH - mm_to_pt(MARGIN_MM + HEADER_MM + RIBBON_MM) - mm_to_pt(2)
    PLAN_BOT_PT = mm_to_pt(MARGIN_MM + LEGEND_MM + TITLE_MM + 6)
    PLAN_W_PT = PLAN_RIGHT_PT - PLAN_LEFT_PT
    PLAN_H_PT = PLAN_TOP_PT - PLAN_BOT_PT

    YARD_H_PT = mm_to_pt(48)
    avail_h_pt = PLAN_H_PT - 2 * mm_to_pt(FRAME_PAD_MM) - YARD_H_PT
    avail_w_pt = PLAN_W_PT * 0.94
    scale_h = avail_h_pt / BUILD_H
    scale_w = avail_w_pt / BUILD_W
    scale = min(scale_h, scale_w)
    BUILD_W_PT = BUILD_W * scale
    BUILD_H_PT = BUILD_H * scale
    BUILD_X0 = PLAN_LEFT_PT + (PLAN_W_PT - BUILD_W_PT) / 2
    BUILD_Y0 = PLAN_BOT_PT + (PLAN_H_PT - BUILD_H_PT - YARD_H_PT) / 2

    global DRAW
    DRAW = configure_layout(
        scale=scale,
        frame_left=PLAN_LEFT_PT, frame_right=PLAN_RIGHT_PT,
        frame_bottom=PLAN_BOT_PT, frame_top=PLAN_TOP_PT,
        header_y=PH - mm_to_pt(MARGIN_MM + HEADER_MM),
        ribbon_y=PH - mm_to_pt(MARGIN_MM + HEADER_MM + RIBBON_MM),
        legend_y=mm_to_pt(MARGIN_MM),
        title_y=mm_to_pt(MARGIN_MM + LEGEND_MM) + mm_to_pt(4),
        building_x0=BUILD_X0, building_y0=BUILD_Y0,
    )

    draw_page_chrome(c, page_title="OVERALL  FLOOR  PLAN",
                     sheet_no=sheet_no, total_sheets=total_sheets)

    # Geometry clipped to frame
    push_clip_to_frame(c)
    draw_outer_shell(c)
    draw_yard(c)
    draw_rooms(c)
    draw_corridor(c)
    draw_equipment(c)
    draw_ahu_supply(c)
    draw_fcu_supply_branches(c)
    draw_return_drops(c)
    draw_thermostats(c)
    draw_chw_pipes(c)
    draw_yard_equipment(c)
    c.restoreState()

    draw_dimensions_overall(c)
    draw_equipment_schedule(c)


# Zones where room codes belong to a given page
PAGE_ZONES = {
    "Z-A":  {"Z-A"},
    "Z-B":  {"Z-B"},
    "Z-C":  {"Z-C"},
    "Z-D":  {"Z-D"},
    "MEET": {"M-1", "M-2", "M-3", "REC", "PNT"},   # meeting + amenity row
    "PLANT": {"PLT", "MECH"},                      # bottom-row mechanical rooms + yard
    "SERVER": {"SER"},
}


def build_detail_page(c, key, page_title, sheet_no, total_sheets):
    """One detail sheet per area.  The plan frame fills with the cropped
    region from the overall drawing, scaled up so labels are readable."""
    region = DETAIL_REGIONS[key]
    overall = DETAIL_REGIONS["OVERALL"]
    rx0, ry0, rx1, ry1 = region
    ox0, oy0, ox1, oy1 = overall

    # Plan area
    PLAN_LEFT_PT = mm_to_pt(MARGIN_MM)
    PLAN_RIGHT_PT = PW - mm_to_pt(MARGIN_MM)
    PLAN_TOP_PT = PH - mm_to_pt(MARGIN_MM + HEADER_MM + RIBBON_MM) - mm_to_pt(2)
    PLAN_BOT_PT = mm_to_pt(MARGIN_MM + LEGEND_MM + TITLE_MM + 6)
    PLAN_W_PT = PLAN_RIGHT_PT - PLAN_LEFT_PT
    PLAN_H_PT = PLAN_TOP_PT - PLAN_BOT_PT

    # Available drawing area inside the frame after safe padding
    pad = mm_to_pt(FRAME_PAD_MM)
    avail_w = PLAN_W_PT - 2 * pad
    avail_h = PLAN_H_PT - 2 * pad

    # Reserve space for key-plan inset (top-right) and schedule on plant page.
    if key == "PLANT":
        avail_w -= mm_to_pt(62)
        avail_h -= mm_to_pt(44)
        avail_origin_x = PLAN_LEFT_PT + pad
        avail_origin_y = PLAN_BOT_PT + pad
    else:
        avail_w -= mm_to_pt(116)
        avail_h -= mm_to_pt(36)
        avail_origin_x = PLAN_LEFT_PT + pad
        avail_origin_y = PLAN_BOT_PT + pad

    region_w = rx1 - rx0
    region_h = ry1 - ry0
    scale = min(avail_w / region_w, avail_h / region_h)
    region_w_pt = region_w * scale
    region_h_pt = region_h * scale
    # Centre the region within the available area
    BUILD_X0 = avail_origin_x + (avail_w - region_w_pt) / 2
    BUILD_Y0 = avail_origin_y + (avail_h - region_h_pt) / 2

    global DRAW
    DRAW = configure_layout(
        scale=scale,
        frame_left=PLAN_LEFT_PT, frame_right=PLAN_RIGHT_PT,
        frame_bottom=PLAN_BOT_PT, frame_top=PLAN_TOP_PT,
        header_y=PH - mm_to_pt(MARGIN_MM + HEADER_MM),
        ribbon_y=PH - mm_to_pt(MARGIN_MM + HEADER_MM + RIBBON_MM),
        legend_y=mm_to_pt(MARGIN_MM),
        title_y=mm_to_pt(MARGIN_MM + LEGEND_MM) + mm_to_pt(4),
        building_x0=BUILD_X0, building_y0=BUILD_Y0,
    )

    # Detail pages get the legend & title block, plus a key-plan inset
    draw_page_chrome(c, page_title=page_title, sheet_no=sheet_no,
                     total_sheets=total_sheets, region_label=key,
                     region_rect=region, overall_rect=overall)

    # Geometry — clip to plan frame so nothing spills outside
    push_clip_to_frame(c)
    only = PAGE_ZONES.get(key)
    draw_outer_shell(c)
    draw_yard(c)
    draw_rooms(c, only_codes=only)
    # Corridor stays only for pages that include the corridor band
    if key in ("MEET", "SERVER", "Z-A", "Z-B", "Z-C", "Z-D"):
        draw_corridor(c)
    # Equipment — symbols now self-skip if outside frame
    draw_equipment(c)
    if key in ("Z-A", "Z-B", "Z-C", "Z-D", "MEET"):
        draw_ahu_supply(c)
        draw_fcu_supply_branches(c)
        draw_return_drops(c)
    elif key == "SERVER":
        draw_ahu_supply(c)
        draw_chw_pipes(c)
    elif key == "PLANT":
        draw_chw_pipes(c)
        draw_yard_equipment(c)
        draw_ahu_supply(c)
        draw_thermostats(c)
    else:
        draw_ahu_supply(c)
        draw_fcu_supply_branches(c)
        draw_return_drops(c)
        draw_thermostats(c)
    draw_thermostats(c)
    draw_chw_pipes(c)
    if key == "PLANT":
        draw_yard_equipment(c)
    c.restoreState()

    # Plant page equipment schedule (drawn after clipping so it stays crisp)
    if key == "PLANT":
        draw_equipment_schedule(c)


# ---------------------------------------------------------------------------
# Build the document
# ---------------------------------------------------------------------------
PAGES = [
    ("OVERALL", "OVERALL  FLOOR  PLAN"),
    ("Z-A",     "DETAIL  —  ZONE  A"),
    ("Z-B",     "DETAIL  —  ZONE  B"),
    ("Z-C",     "DETAIL  —  ZONE  C"),
    ("Z-D",     "DETAIL  —  ZONE  D"),
    ("MEET",    "DETAIL  —  MEETING  ROOMS  +  AMENITY"),
    ("PLANT",   "DETAIL  —  PLANT  /  MECHANICAL  ROOM  +  YARD"),
    ("SERVER",  "DETAIL  —  SERVER  /  ELECTRICAL  ROOM"),
]


def main():
    c = canvas.Canvas(OUT, pagesize=PAGE)
    c.setTitle("Multi-Zone AC System — Sample Floor Plan (A3 multipage, pitch reference)")
    c.setAuthor("AInchors")
    c.setSubject("HVAC demo floor plan: 4 office zones + corridor return + central plant")
    c.setKeywords("HVAC, AHU, FCU, chilled water, ductwork, floor plan, pitch, demo, A3")
    c.setPageCompression(1)

    for idx, (key, page_title) in enumerate(PAGES, start=1):
        if key == "OVERALL":
            build_overall_page(c, idx, len(PAGES))
        else:
            build_detail_page(c, key, page_title, idx, len(PAGES))
        c.showPage()

    c.save()
    print("WROTE", OUT, os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    main()
