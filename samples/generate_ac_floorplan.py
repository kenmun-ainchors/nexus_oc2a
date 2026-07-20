"""
Multi-zone AC system floor plan — sample/demo PDF.
Pure ReportLab vector output. No raster, so it scales cleanly for mobile/client review.
"""

from reportlab.lib.pagesizes import A3, landscape
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.lib.colors import (
    HexColor, black, white, lightgrey, grey, red, blue, green, orange, cyan
)
import os

OUT = "/Users/ainchorsoc2a/.openclaw/workspace/samples/multi_zone_ac_floorplan.pdf"

# ---------- page setup: A3 landscape, generous drawable area ----------
PAGE = landscape(A3)                # 420 x 297 mm
PW, PH = PAGE

# Layout grid
MARGIN_L = 18 * mm
MARGIN_R = 18 * mm
MARGIN_T = 18 * mm
MARGIN_B = 18 * mm

DRAW_W = PW - MARGIN_L - MARGIN_R
DRAW_H = PH - MARGIN_T - MARGIN_B

# Drawing units: 1 drawing unit = 1 mm at A3 scale.
# Plan area: 36m x 18m building floor → 36000 x 18000 in plan units (1 unit = 1mm)
BUILD_W = 36000   # 36 m
BUILD_H = 18000   # 18 m
SCALE = DRAW_W / BUILD_W          # mm per plan-mm

# Convert plan mm → page mm
def X(x):
    return MARGIN_L + x * SCALE
def Y(y):
    return MARGIN_T + y * SCALE
def S(l):
    return l * SCALE

# ---------- colors ----------
WALL = black
WALL_FILL = HexColor("#fafafa")
ROOM_FILL = HexColor("#fdfdfd")
CORRIDOR_FILL = HexColor("#f3f5f7")
AHU_FILL = HexColor("#fff1d6")
AHU_EDGE = HexColor("#a06b00")
FCU_FILL = HexColor("#dde9ff")
FCU_EDGE = HexColor("#1a3f8a")
SUPPLY_LINE = HexColor("#1f6feb")
RETURN_LINE = HexColor("#7a4ec8")
CHW_SUPPLY = HexColor("#0b8a4a")
CHW_RETURN = HexColor("#b14a3a")
DIFFUSER = HexColor("#1f6feb")
RETURN_GRILLE = HexColor("#7a4ec8")
CHILLER = HexColor("#2c2c2c")
TEXT = black
DIM = HexColor("#444444")
LEAF_BG = HexColor("#f6f7f9")

# ---------- helpers ----------
def wall(c, x1, y1, x2, y2, t=180):
    c.setStrokeColor(WALL)
    c.setLineWidth(S(t))
    c.line(X(x1), Y(y1), X(x2), Y(y2))

def rect(c, x, y, w, h, stroke=black, fill=None, lw=80):
    if fill is not None:
        c.setFillColor(fill)
    c.setStrokeColor(stroke)
    c.setLineWidth(S(lw))
    c.rect(X(x), Y(y), S(w), S(h), stroke=1, fill=1 if fill is not None else 0)

def label(c, text_, x, y, size=140, color=TEXT, anchor="center", bold=False):
    c.setFillColor(color)
    f = "Helvetica-Bold" if bold else "Helvetica"
    c.setFont(f, size)
    if anchor == "center":
        c.drawCentredString(X(x), Y(y), text_)
    elif anchor == "left":
        c.drawString(X(x), Y(y), text_)
    elif anchor == "right":
        c.drawRightString(X(x), Y(y), text_)

def dim_h(c, x1, x2, y, text_, offset=600):
    """Horizontal dimension line above/below plan."""
    yo = y + offset
    c.setStrokeColor(DIM)
    c.setLineWidth(40)
    # extension lines
    c.line(X(x1), Y(y), X(x1), Y(yo + 200))
    c.line(X(x2), Y(y), X(x2), Y(yo + 200))
    # main dim line
    c.line(X(x1), Y(yo), X(x2), Y(yo))
    # ticks
    for xt in (x1, x2):
        c.line(X(xt), Y(yo - 120), X(xt), Y(yo + 120))
    # text
    label(c, text_, (x1 + x2) / 2, yo - 250, size=130, color=DIM, anchor="center", bold=True)

def dim_v(c, y1, y2, x, text_, offset=600):
    xo = x - offset
    c.setStrokeColor(DIM)
    c.setLineWidth(40)
    c.line(X(x), Y(y1), X(xo - 200), Y(y1))
    c.line(X(x), Y(y2), X(xo - 200), Y(y2))
    c.line(X(xo), Y(y1), X(xo), Y(y2))
    for yt in (y1, y2):
        c.line(X(xo - 120), Y(yt), X(xo + 120), Y(yt))
    c.saveState()
    c.translate(X(xo - 350), Y((y1 + y2) / 2))
    c.rotate(90)
    c.setFillColor(DIM)
    c.setFont("Helvetica-Bold", 130)
    c.drawCentredString(0, 0, text_)
    c.restoreState()

def diffuser(c, cx, cy, r=350):
    """Square supply diffuser (4-direction swirl)."""
    c.setStrokeColor(DIFFUSER)
    c.setFillColor(white)
    c.setLineWidth(60)
    c.rect(X(cx - r), Y(cy - r), S(2 * r), S(2 * r), stroke=1, fill=1)
    # X cross
    c.line(X(cx - r * 0.7), Y(cy - r * 0.7), X(cx + r * 0.7), Y(cy + r * 0.7))
    c.line(X(cx - r * 0.7), Y(cy + r * 0.7), X(cx + r * 0.7), Y(cy - r * 0.7))

def return_grille(c, cx, cy, r=320):
    """Return grille — dotted square with horizontal slats."""
    c.setStrokeColor(RETURN_GRILLE)
    c.setFillColor(white)
    c.setLineWidth(60)
    c.setDash(120, 90)
    c.rect(X(cx - r), Y(cy - r), S(2 * r), S(2 * r), stroke=1, fill=1)
    c.setDash()
    # slats
    for k in range(-2, 3):
        c.line(X(cx - r * 0.8), Y(cy + k * r * 0.35), X(cx + r * 0.8), Y(cy + k * r * 0.35))

def ahu(c, cx, cy, w=2800, h=1800):
    """AHU — rounded rectangle with label."""
    c.setStrokeColor(AHU_EDGE)
    c.setFillColor(AHU_FILL)
    c.setLineWidth(110)
    c.roundRect(X(cx - w / 2), Y(cy - h / 2), S(w), S(h), 250, stroke=1, fill=1)
    label(c, "AHU-1", cx, cy + 200, size=180, color=AHU_EDGE, bold=True)
    label(c, "15,000 CFM", cx, cy - 200, size=130, color=AHU_EDGE)

def fcu(c, cx, cy, w=1400, h=900):
    """FCU — small rounded rectangle."""
    c.setStrokeColor(FCU_EDGE)
    c.setFillColor(FCU_FILL)
    c.setLineWidth(90)
    c.roundRect(X(cx - w / 2), Y(cy - h / 2), S(w), S(h), 200, stroke=1, fill=1)
    label(c, "FCU", cx, cy + 80, size=140, color=FCU_EDGE, bold=True)

def chiller(c, cx, cy, r=1100):
    """Chiller — circle with C."""
    c.setStrokeColor(CHILLER)
    c.setFillColor(HexColor("#dddddd"))
    c.setLineWidth(110)
    c.circle(X(cx), Y(cy), S(r), stroke=1, fill=1)
    label(c, "CHILLER", cx, cy + 250, size=170, color=black, bold=True)
    label(c, "300 TR", cx, cy - 250, size=150, color=black, bold=True)

def pipe_seg(c, x1, y1, x2, y2, color, lw=110, dash=None):
    c.setStrokeColor(color)
    c.setLineWidth(S(lw))
    if dash:
        c.setDash(*dash)
    c.line(X(x1), Y(y1), X(x2), Y(y2))
    c.setDash()
    # Arrow at end
    ang = (1, 0) if x2 > x1 else ((-1, 0) if x2 < x1 else ((0, 1) if y2 > y1 else (0, -1)))
    al = 0.012  # arrow length in plan units
    aw = 0.006
    if ang[0] != 0:
        ex, ey = x2, y2
        ax1, ay1 = x2 - ang[0] * al, y2 - aw
        ax2, ay2 = x2 - ang[0] * al, y2 + aw
    else:
        ex, ey = x2, y2
        ax1, ay1 = x2 - aw, y2 - ang[1] * al
        ax2, ay2 = x2 + aw, y2 - ang[1] * al
    c.setFillColor(color)
    p = c.beginPath()
    p.moveTo(X(ex), Y(ey))
    p.lineTo(X(ax1), Y(ay1))
    p.lineTo(X(ax2), Y(ay2))
    p.close()
    c.drawPath(p, stroke=0, fill=1)

def supply_main(c, x1, y1, x2, y2):
    pipe_seg(c, x1, y1, x2, y2, SUPPLY_LINE, lw=120)
    # flow direction chevrons
    dx, dy = x2 - x1, y2 - y1
    L = (dx * dx + dy * dy) ** 0.5
    if L < 1:
        return
    ux, uy = dx / L, dy / L
    # perpendicular
    px, py = -uy, ux
    # draw 2 chevrons
    for t in (0.35, 0.7):
        cx0 = x1 + dx * t
        cy0 = y1 + dy * t
        s = 220
        c.setStrokeColor(white)
        c.setLineWidth(80)
        c.line(X(cx0 - ux * s - px * s * 0.6), Y(cy0 - uy * s - py * s * 0.6),
               X(cx0), Y(cy0))
        c.line(X(cx0 - ux * s + px * s * 0.6), Y(cy0 - uy * s + py * s * 0.6),
               X(cx0), Y(cy0))

# ---------- begin drawing ----------
c = canvas.Canvas(OUT, pagesize=PAGE)
c.setTitle("Multi-Zone AC System — Sample Floor Plan")
c.setAuthor("AInchors")
c.setSubject("HVAC demo floor plan (4 office zones + corridor/return)")
c.setKeywords("HVAC, AHU, FCU, chilled water, ductwork, floor plan")

# Border
c.setStrokeColor(grey)
c.setLineWidth(60)
c.rect(MARGIN_L - 4 * mm, MARGIN_T - 4 * mm,
       DRAW_W + 8 * mm, DRAW_H + 8 * mm, stroke=1, fill=0)

# North arrow + scale bar (top-right of plan area)
def north_arrow(c, x, y, size_=2.2 * mm):
    cx, cy = X(x), Y(y)
    c.saveState()
    c.translate(cx, cy)
    c.setFillColor(black)
    c.setStrokeColor(black)
    c.setLineWidth(40)
    p = c.beginPath()
    p.moveTo(0, size_)
    p.lineTo(-size_ * 0.6, -size_ * 0.8)
    p.lineTo(0, -size_ * 0.3)
    p.lineTo(size_ * 0.6, -size_ * 0.8)
    p.close()
    c.drawPath(p, stroke=1, fill=1)
    c.setFont("Helvetica-Bold", 150)
    c.drawCentredString(0, size_ + 200, "N")
    c.restoreState()

north_arrow(c, BUILD_W - 1500, BUILD_H - 1500)

# Scale bar
def scale_bar(c, x, y):
    c.setStrokeColor(black)
    c.setLineWidth(40)
    seg = 5
    seg_len = 2000  # 2 m per segment
    total = seg * seg_len
    c.setFillColor(black)
    c.rect(X(x), Y(y), S(total / 2), S(180), stroke=0, fill=1)
    c.setFillColor(white)
    c.rect(X(x + total / 2), Y(y), S(total / 2), S(180), stroke=0, fill=1)
    c.setStrokeColor(black)
    c.rect(X(x), Y(y), S(total), S(180), stroke=1, fill=0)
    c.setFont("Helvetica", 110)
    c.setFillColor(black)
    for i in range(seg + 1):
        xx = x + i * seg_len
        c.drawCentredString(X(xx), Y(y) - 280, f"{i*2}")
    c.setFont("Helvetica-Bold", 120)
    c.drawCentredString(X(x + total / 2), Y(y) + 380, "SCALE  0   2   4   6   8   10  m")

scale_bar(c, BUILD_W - 8500, BUILD_H - 700)

# ===================== PLAN GEOMETRY =====================
# Building: 36m x 18m.
# Internal layout (4 office zones along top, corridor mid, 4 meeting/service rooms along bottom)
# All coords in plan mm.

# Outer walls
c.setFillColor(WALL_FILL)
c.setStrokeColor(WALL)
c.setLineWidth(S(220))
c.rect(X(0), Y(0), S(BUILD_W), S(BUILD_H), stroke=1, fill=1)

# Room definitions (x, y, w, h, name, code, fill)
ROOMS = [
    # (x, y, w, h, name, code, fill)
    (1000,  12000, 7500, 5500, "OFFICE ZONE A",  "Z-A",  ROOM_FILL),
    (9000,  12000, 7500, 5500, "OFFICE ZONE B",  "Z-B",  ROOM_FILL),
    (17000, 12000, 7500, 5500, "OFFICE ZONE C",  "Z-C",  ROOM_FILL),
    (25000, 12000, 10000, 5500, "OPEN OFFICE / COLLAB", "Z-D", ROOM_FILL),
    (1000,  5500,  8000, 5500, "MEETING ROOM 1", "M-1", ROOM_FILL),
    (9500,  5500,  8000, 5500, "MEETING ROOM 2", "M-2", ROOM_FILL),
    (18000, 5500,  8000, 5500, "MEETING ROOM 3", "M-3", ROOM_FILL),
    (26500, 5500,  8500, 5500, "SERVER / ELECT.", "SER", ROOM_FILL),
]

# Corridor: y from 11000 to 11500, full width (x 1000..35000, w 34000)
# Draw corridor background
rect(c, 1000, 10800, 34000, 800, stroke=WALL, fill=CORRIDOR_FILL, lw=120)

# Draw rooms
for (x, y, w, h, name, code, fill) in ROOMS:
    rect(c, x, y, w, h, stroke=WALL, fill=fill, lw=160)
    # Room name
    label(c, name, x + w / 2, y + h - 700, size=190, bold=True)
    label(c, code, x + w / 2, y + 1100, size=180, color=HexColor("#666666"), bold=True)

# Corridor label
label(c, "MAIN CORRIDOR  /  RETURN AIR PLENUM", 18000, 11200, size=180, bold=True, color=HexColor("#555555"))

# Plant room (top-right of building, small dedicated space) — we put AHU outside the office block.
# AHU penthouse on the right of zone D? Let's place AHU on the south-east exterior.
# We'll show AHU on its own platform outside the main office footprint but within the page drawing area.
# Simpler: put AHU in a small plant room in the bottom-right of the building, and chiller outside.

# Plant room at bottom-right
rect(c, 26500, 1000, 8500, 4000, stroke=WALL, fill=AHU_FILL, lw=160)
label(c, "AHU PLANT ROOM", 30750, 4500, size=190, bold=True, color=AHU_EDGE)
label(c, "AHU-1", 30750, 3800, size=170, bold=True, color=AHU_EDGE)
label(c, "15,000 CFM  •  4-Zone VAV", 30750, 3200, size=130, color=AHU_EDGE)
label(c, "Chilled Water Coil / Filter / Fan Section", 30750, 2600, size=110, color=AHU_EDGE)
label(c, "Outside Air Intake  ↗", 30750, 1800, size=110, color=AHU_EDGE, bold=True)

# Mechanical room (bottom-left)
rect(c, 1000, 1000, 7000, 4000, stroke=WALL, fill=HexColor("#eeeeee"), lw=160)
label(c, "MECHANICAL / PUMP ROOM", 4500, 4500, size=180, bold=True)
label(c, "Primary CHW Pumps • Expansion Tank • Air Separator", 4500, 3700, size=110, color=HexColor("#555555"))

# Restroom + Pantry strip
rect(c, 8500, 1000, 5000, 4000, stroke=WALL, fill=HexColor("#f4f0e6"), lw=160)
label(c, "PANTRY / BREAKOUT", 11000, 4200, size=170, bold=True)
label(c, "FCU-5 (1,200 CFM)", 11000, 3600, size=120, color=FCU_EDGE, bold=True)
label(c, "Exhaust fan EF-1", 11000, 3100, size=120, color=grey, bold=True)

rect(c, 14000, 1000, 6000, 4000, stroke=WALL, fill=HexColor("#eaf3ea"), lw=160)
label(c, "RECEPTION / LOBBY", 17000, 4200, size=180, bold=True)
label(c, "FCU-6 (2,000 CFM)", 17000, 3600, size=120, color=FCU_EDGE, bold=True)
label(c, "Vestibule Heaters", 17000, 3100, size=120, color=HexColor("#666666"), bold=True)

# Server room reinforced
label(c, "DEDICATED 24/7 COOLING", 30750, 6700, size=120, color=HexColor("#7a1f1f"), bold=True)
label(c, "CRAC unit + independent split", 30750, 6300, size=110, color=HexColor("#7a1f1f"))

# ===================== HVAC: AHU, FCUs, DUCTS, DIFFUSERS, GRILLES =====================

# AHU location: center of plant room
ahu(c, 30750, 3200, w=6500, h=2400)

# Outside air intake louver (right wall of plant room) - small graphic
c.setStrokeColor(black); c.setFillColor(white); c.setLineWidth(60)
c.rect(X(35000 - 50), Y(2200), S(60), S(2200), stroke=1, fill=1)
for k in range(8):
    c.line(X(35000 - 30), Y(2200 + 200 + k * 220), X(35000 + 30), Y(2200 + 200 + k * 220))

# FCU locations: one per office zone + meeting rooms + pantry/reception
# Place FCUs near room edges, with supply duct runs to diffusers
FCU_POS = {
    "FCU-1 (Z-A)": (4750,  15000, 4750, 17000),  # (label_cx, label_cy, x, y) for unit
    "FCU-2 (Z-B)": (12750, 15000, 12750, 17000),
    "FCU-3 (Z-C)": (20750, 15000, 20750, 17000),
    "FCU-4 (Z-D)": (30000, 15000, 30000, 17000),
    "FCU-7 (M-1)": (5000,  9000,  5000, 10500),
    "FCU-8 (M-2)": (13500, 9000,  13500, 10500),
    "FCU-9 (M-3)": (22000, 9000,  22000, 10500),
}
# We already have FCU-5 in pantry (11000, 3800) and FCU-6 in reception (17000, 3800) — label only.
# Place them visually
fcu_units = [
    (4750,  16700, "FCU-1", "2,400 CFM"),
    (12750, 16700, "FCU-2", "2,400 CFM"),
    (20750, 16700, "FCU-3", "2,400 CFM"),
    (30000, 16700, "FCU-4", "3,600 CFM"),
    (5000,  10200, "FCU-7", "1,500 CFM"),
    (13500, 10200, "FCU-8", "1,500 CFM"),
    (22000, 10200, "FCU-9", "1,500 CFM"),
    (11000, 3200,  "FCU-5", "1,200 CFM"),
    (17000, 3200,  "FCU-6", "2,000 CFM"),
]
for (cx, cy, code, cfm) in fcu_units:
    fcu(c, cx, cy)
    # If the fcu label inside the unit doesn't fit, skip; otherwise rely on default.
    # Place code + cfm nearby
    label(c, f"{code}", cx, cy + 60, size=130, color=FCU_EDGE, bold=True)

# Supply ducts (from FCU upward into the zone): draw a vertical supply trunk then branches to diffusers
def fcu_supply_branch(c, fcu_x, fcu_y, zone_y_top, diff_y, diff_xs):
    """Draw a supply trunk from FCU up to zone ceiling plane, then branches to diffusers."""
    # trunk
    c.setStrokeColor(SUPPLY_LINE)
    c.setLineWidth(S(120))
    trunk_top = zone_y_top - 300
    c.line(X(fcu_x), Y(fcu_y + 600), X(fcu_x), Y(trunk_top))
    # horizontal branch at trunk_top
    c.line(X(min(diff_xs) - 200), Y(trunk_top), X(max(diff_xs) + 200), Y(trunk_top))
    # drops to diffusers
    for dx in diff_xs:
        c.line(X(dx), Y(trunk_top), X(dx), Y(diff_y))
        # arrow into diffuser
        c.setFillColor(SUPPLY_LINE)
        p = c.beginPath()
        p.moveTo(X(dx), Y(diff_y - 50))
        p.lineTo(X(dx - 150), Y(diff_y + 250))
        p.lineTo(X(dx + 150), Y(diff_y + 250))
        p.close()
        c.drawPath(p, stroke=0, fill=1)
        c.setStrokeColor(SUPPLY_LINE)

# Return ducts (return air via corridor): horizontal return trunk in corridor + drops to grilles
def return_branch(c, grille_x, grille_y, trunk_y):
    c.setStrokeColor(RETURN_LINE)
    c.setLineWidth(S(120))
    c.setDash(180, 120)
    c.line(X(grille_x), Y(grille_y + 600), X(grille_x), Y(trunk_y))
    c.setDash()

def corridor_return_trunk(c, x1, x2, y):
    c.setStrokeColor(RETURN_LINE)
    c.setLineWidth(S(150))
    c.setDash(200, 140)
    c.line(X(x1), Y(y), X(x2), Y(y))
    c.setDash()

# Zone A: FCU-1 (4750, 16700) -> 4 diffusers in zone A (1000..8500, 12000..17500)
diff_a = [2500, 4750, 7000, 9250]  # x positions for diffusers, slightly outside also
# Place 4 diffusers well-distributed in zone A (x 1000..8500)
zone_a_diffs = [2700, 4500, 6300, 8200]
fcu_supply_branch(c, 4750, 16700, 17500, 13500, zone_a_diffs)
# return grilles: 2 in zone A
for gx in [3500, 7500]:
    return_grille(c, gx, 13800, r=320)
    return_branch(c, gx, 13800, 11400)

# Zone B: 4 diffusers
zone_b_diffs = [10500, 12300, 14100, 16000]
fcu_supply_branch(c, 12750, 16700, 17500, 13500, zone_b_diffs)
for gx in [11200, 15200]:
    return_grille(c, gx, 13800, r=320)
    return_branch(c, gx, 13800, 11400)

# Zone C
zone_c_diffs = [18500, 20300, 22100, 24000]
fcu_supply_branch(c, 20750, 16700, 17500, 13500, zone_c_diffs)
for gx in [19200, 23200]:
    return_grille(c, gx, 13800, r=320)
    return_branch(c, gx, 13800, 11400)

# Zone D (open office / collab)
zone_d_diffs = [27000, 28800, 30600, 32400, 34200]
# Custom branch: fcu is at x=30000
fcu_supply_branch(c, 30000, 16700, 17500, 13500, zone_d_diffs)
for gx in [28000, 31000, 33500]:
    return_grille(c, gx, 13800, r=320)
    return_branch(c, gx, 13800, 11400)

# Corridor return trunk (dashed purple) running east-west
corridor_return_trunk(c, 1000, 35000, 11400)
# Drops from corridor to AHU plant room
c.setStrokeColor(RETURN_LINE); c.setLineWidth(S(150)); c.setDash(200, 140)
c.line(X(30750), Y(11400), X(30750), Y(5000))  # down to plant room
c.setDash()
# Plant-room internal return
c.setStrokeColor(RETURN_LINE); c.setLineWidth(S(150))
c.line(X(30750), Y(5000), X(30750), Y(4200))  # into AHU

# Meeting rooms supply
# M-1 (1000..9000 x 5500..11000), FCU-7 at (5000, 10200)
m1_diffs = [2500, 5000, 7500]
fcu_supply_branch(c, 5000, 10200, 11000, 7500, m1_diffs)
for gx in [3500, 7000]:
    return_grille(c, gx, 7800, r=280)
    return_branch(c, gx, 7800, 11400)

# M-2
m2_diffs = [11000, 13500, 16000]
fcu_supply_branch(c, 13500, 10200, 11000, 7500, m2_diffs)
for gx in [12000, 15500]:
    return_grille(c, gx, 7800, r=280)
    return_branch(c, gx, 7800, 11400)

# M-3
m3_diffs = [19500, 22000, 24500]
fcu_supply_branch(c, 22000, 10200, 11000, 7500, m3_diffs)
for gx in [20500, 24000]:
    return_grille(c, gx, 7800, r=280)
    return_branch(c, gx, 7800, 11400)

# Server room: separate CRAC (label only) - little cooling unit graphic
c.setStrokeColor(HexColor("#7a1f1f")); c.setFillColor(HexColor("#fbeaea")); c.setLineWidth(80)
c.roundRect(X(29000), Y(6800), S(2400), S(1400), 150, stroke=1, fill=1)
label(c, "CRAC", 30200, 7600, size=160, color=HexColor("#7a1f1f"), bold=True)
label(c, "N+1 redundancy", 30200, 7200, size=110, color=HexColor("#7a1f1f"))

# Pantry FCU-5 small diffuser
diffuser(c, 11000, 1800, r=300)
return_grille(c, 13000, 1800, r=280)
# Reception FCU-6
diffuser(c, 16500, 1800, r=300)
diffuser(c, 18000, 1800, r=300)
return_grille(c, 19000, 1800, r=280)

# Now place the actual diffuser symbols on top of branch endpoints
for zone_diffs in (zone_a_diffs, zone_b_diffs, zone_c_diffs, zone_d_diffs):
    for dx in zone_diffs:
        diffuser(c, dx, 13500, r=300)
for m_diffs in (m1_diffs, m2_diffs, m3_diffs):
    for dx in m_diffs:
        diffuser(c, dx, 7500, r=280)

# ===================== CHILLED WATER PIPING =====================
# Chiller outside the building footprint (south of building, below plan area)
# We'll place it in the page margin below the building outline, in the title block area.
# Better: place a "Plant Yard" zone below the building.
# Add an exterior plant yard: a rectangle below BUILD_H that we draw outside the building.
YARD_Y = -4500
YARD_H = 4000
rect(c, 1000, YARD_Y, 34000, YARD_H, stroke=black, fill=HexColor("#eef3f7"), lw=140)
label(c, "CENTRAL PLANT YARD", 18000, YARD_Y + YARD_H - 700, size=200, bold=True)

# Chiller(s) — place 2 chillers
# Legend sits at x=1000..17000 (left half of page). Chillers at x=8000/12000 fall under it.
# So we shrink the legend's horizontal extent, or move chillers right. Move chillers right
# and split chillers / cooling tower / pumps into the right half of the yard.
chiller(c, 21000, YARD_Y + YARD_H / 2 + 300, r=1100)
chiller(c, 25000, YARD_Y + YARD_H / 2 + 300, r=1100)
label(c, "CH-1  150 TR", 21000, YARD_Y + YARD_H / 2 - 1100, size=140, bold=True)
label(c, "CH-2  150 TR", 25000, YARD_Y + YARD_H / 2 - 1100, size=140, bold=True)

# Cooling tower
ct_x, ct_y, ct_r = 30500, YARD_Y + YARD_H / 2 + 300, 1100
c.setStrokeColor(HexColor("#005a87")); c.setFillColor(HexColor("#cfe7f5")); c.setLineWidth(110)
c.circle(X(ct_x), Y(ct_y), S(ct_r), stroke=1, fill=1)
label(c, "CT-1", ct_x, ct_y + 250, size=170, bold=True, color=HexColor("#005a87"))
label(c, "INDUCED DRAFT", ct_x, ct_y - 250, size=120, color=HexColor("#005a87"))

# Primary chilled water pumps
for px, code in [(15500, "P-1"), (17000, "P-2"), (18500, "P-3")]:
    c.setStrokeColor(black); c.setFillColor(HexColor("#fff7c2")); c.setLineWidth(80)
    c.circle(X(px), Y(ct_y), S(550), stroke=1, fill=1)
    label(c, code, px, ct_y + 80, size=140, bold=True)

# Header piping: CHW supply (green) and CHW return (red) running from chiller yard up to mechanical room
# Mechanical room center: x=4500, top edge y=5000. Connect from yard top (YARD_Y + YARD_H = -500) up to mech room.
MECH_TOP_X = 4500
MECH_TOP_Y = 5000
YARD_TOP_Y = YARD_Y + YARD_H  # -500

# Main CHW supply riser (green): from chiller header up to mech room, then across to AHU
# 1) chiller to header at yard top
# Common header across yard
hdr_y = YARD_TOP_Y - 150
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(S(140))
c.line(X(3000), Y(hdr_y), X(33000), Y(hdr_y))
# drops to each chiller pump / chiller
c.line(X(21000), Y(hdr_y), X(21000), Y(ct_y - 1200))
c.line(X(25000), Y(hdr_y), X(25000), Y(ct_y - 1200))
c.line(X(15500), Y(hdr_y), X(15500), Y(ct_y - 650))
c.line(X(17000), Y(hdr_y), X(17000), Y(ct_y - 650))
c.line(X(18500), Y(hdr_y), X(18500), Y(ct_y - 650))
# continue header down to chiller return? We'll route return on a separate header below
# CHW return header (red) below the supply header
ret_hdr_y = YARD_TOP_Y - 800
c.setStrokeColor(CHW_RETURN); c.setLineWidth(S(140))
c.line(X(3000), Y(ret_hdr_y), X(33000), Y(ret_hdr_y))
# drops to chillers
c.line(X(21000), Y(ret_hdr_y), X(21000), Y(ct_y - 1800))
c.line(X(25000), Y(ret_hdr_y), X(25000), Y(ct_y - 1800))

# Vertical riser from yard up to mechanical room (along x = 4500)
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(S(160))
c.line(X(3000), Y(hdr_y), X(3000), Y(MECH_TOP_Y + 600))   # up the left side into mech room
c.setStrokeColor(CHW_RETURN); c.setLineWidth(S(160))
c.line(X(2200), Y(ret_hdr_y), X(2200), Y(MECH_TOP_Y + 200))  # return

# Inside mechanical room header
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(S(160))
c.line(X(2200), Y(MECH_TOP_Y + 600), X(8000), Y(MECH_TOP_Y + 600))
c.setStrokeColor(CHW_RETURN); c.setLineWidth(S(160))
c.line(X(2200), Y(MECH_TOP_Y + 200), X(8000), Y(MECH_TOP_Y + 200))

# Cross-building CHW supply main from mech room to AHU plant room (right side)
# Go up to corridor level then east across corridor then down into AHU
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(S(170))
c.line(X(8000), Y(MECH_TOP_Y + 600), X(8000), Y(11700))   # up to corridor
c.line(X(8000), Y(11700), X(30750), Y(11700))              # east across
c.line(X(30750), Y(11700), X(30750), Y(5500))              # down into plant room to AHU
c.line(X(30750), Y(5500), X(30750), Y(4500))               # down to AHU supply inlet
# CHW return main (red), parallel above
c.setStrokeColor(CHW_RETURN); c.setLineWidth(S(170))
c.line(X(8000), Y(MECH_TOP_Y + 200), X(8000), Y(11900))
c.line(X(8000), Y(11900), X(30750), Y(11900))
c.line(X(30750), Y(11900), X(30750), Y(5000))
c.line(X(30750), Y(5000), X(30750), Y(3700))  # to AHU return outlet

# Branch take-offs to each FCU from CHW mains (in corridor)
# We'll branch a small tap up to each FCU position. We need to know FCU y and x.
# We already placed FCUs in zones (y=16700 or y=10200). The CHW mains run at y=11700/11900.
# We draw a vertical drop from main to a point above the FCU, and label tap.

# Instead of branching every FCU (cluttered), we'll show one labeled branch to FCU-1 and indicate "typ." for the rest.
def chw_tap(c, x, main_y, fcu_y, label_):
    c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(S(80))
    c.setDash(120, 80)
    c.line(X(x), Y(main_y), X(x), Y(fcu_y + 600))
    c.setDash()
    c.setStrokeColor(CHW_RETURN); c.setLineWidth(S(80))
    c.setDash(120, 80)
    c.line(X(x - 250), Y(main_y + 200), X(x - 250), Y(fcu_y + 400))
    c.setDash()
    label(c, label_, x + 350, (main_y + fcu_y) / 2, size=110, color=CHW_SUPPLY, bold=True, anchor="left")

# Show one tap with a "TYP." note
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(S(80))
c.setDash(120, 80)
c.line(X(4750), Y(11700), X(4750), Y(17000))
c.setDash()
c.setStrokeColor(CHW_RETURN); c.setLineWidth(S(80))
c.setDash(120, 80)
c.line(X(4500), Y(11900), X(4500), Y(17000))
c.setDash()
label(c, "CHW TAP — TYP.", 5100, 14500, size=120, color=CHW_SUPPLY, bold=True, anchor="left")

# Pipe direction arrow on the long horizontal supply
c.setFillColor(CHW_SUPPLY)
ax_x, ax_y = 20000, 11700
c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(60)
c.line(X(ax_x - 400), Y(ax_y - 250), X(ax_x + 400), Y(ax_y - 250))
c.line(X(ax_x - 400), Y(ax_y + 250), X(ax_x + 400), Y(ax_y + 250))
c.line(X(ax_x - 400), Y(ax_y - 250), X(ax_x - 600), Y(ax_y))
c.line(X(ax_x - 400), Y(ax_y + 250), X(ax_x - 600), Y(ax_y))
# Flow chevron
for k in range(3):
    xx = 14000 + k * 2500
    c.setStrokeColor(CHW_SUPPLY); c.setLineWidth(80)
    c.line(X(xx - 200), Y(11700 - 200), X(xx + 200), Y(11700))
    c.line(X(xx - 200), Y(11700 + 200), X(xx + 200), Y(11700))

# ===================== DIMENSIONS =====================
# Overall building dimensions
dim_h(c, 0, BUILD_W, BUILD_H + 600, "36 000 mm  (36.0 m)")
dim_v(c, 0, BUILD_H, -800, "18 000 mm  (18.0 m)")

# A couple of room dimensions for credibility
dim_h(c, 1000, 9000, 17500 + 700, "8 000 mm  (8.0 m)")
dim_h(c, 9000, 17000, 17500 + 700, "8 000 mm  (8.0 m)")
dim_h(c, 17000, 25000, 17500 + 700, "8 000 mm  (8.0 m)")

# ===================== LEGEND =====================
LEG_X = 1000
LEG_Y = -13000
LEG_W = 16000
LEG_H = 7500

# Legend background
c.setFillColor(LEAF_BG)
c.setStrokeColor(black)
c.setLineWidth(80)
c.rect(X(LEG_X), Y(LEG_Y), S(LEG_W), S(LEG_H), stroke=1, fill=1)

label(c, "LEGEND", LEG_X + 600, LEG_Y + LEG_H - 800, size=220, bold=True)

# Column 1: Equipment
LX1 = LEG_X + 600
LY1 = LEG_Y + LEG_H - 1500
def legend_item(c, x, y, draw_fn, text_):
    draw_fn(x, y)
    label(c, text_, x + 1400, y - 60, size=140, anchor="left", bold=False)

def lg_ahu(x, y):
    ahu(c, x, y, w=2400, h=1500)
def lg_fcu(x, y):
    fcu(c, x, y, w=1300, h=800)
def lg_chiller(x, y):
    chiller(c, x, y, r=900)
def lg_diffuser(x, y):
    diffuser(c, x, y, r=280)
def lg_grille(x, y):
    return_grille(c, x, y, r=260)
def lg_damper(x, y):
    # simple damper symbol
    c.setStrokeColor(black); c.setLineWidth(60)
    c.line(X(x - 400), Y(y + 400), X(x + 400), Y(y - 400))
    c.setFillColor(white)
    c.rect(X(x - 80), Y(y - 80), S(160), S(160), stroke=1, fill=1)
def lg_thermostat(x, y):
    c.setStrokeColor(black); c.setFillColor(white); c.setLineWidth(60)
    c.circle(X(x), Y(y), S(280), stroke=1, fill=1)
    c.setFont("Helvetica-Bold", 160)
    c.setFillColor(black)
    c.drawCentredString(X(x), Y(y) - 70, "T")

# Equipment items
items_col1 = [
    (lg_ahu,         "AHU — Air Handling Unit"),
    (lg_fcu,         "FCU — Fan Coil Unit"),
    (lg_chiller,     "Chiller (water-cooled)"),
    (lg_damper,      "Motorized Damper"),
    (lg_thermostat,  "Zone Thermostat"),
]
yy = LY1 - 100
for (fn, txt) in items_col1:
    fn(LX1 + 800, yy)
    label(c, txt, LX1 + 2000, yy - 60, size=140, anchor="left")
    yy -= 1300

# Column 2: Ductwork & piping
LX2 = LEG_X + 7800
LY2 = LEG_Y + LEG_H - 1500
items_col2 = [
    ("supply",  "Supply Duct (cool air)"),
    ("return",  "Return Duct / Grille (warm air)"),
    ("chw_sup", "CHW Supply (44°F / 7°C)"),
    ("chw_ret", "CHW Return (54°F / 12°C)"),
    ("diff",    "Supply Diffuser (4-way)"),
    ("grille",  "Return Air Grille"),
]
def lg_line(c, x, y, color, dash=None, lw=130, label_=None):
    c.setStrokeColor(color); c.setLineWidth(S(lw))
    if dash:
        c.setDash(*dash)
    c.line(X(x), Y(y), X(x + 2400), Y(y))
    c.setDash()
    if label_:
        label(c, label_, x + 2700, y - 60, size=140, anchor="left")

yy = LY2 - 100
lg_line(c, LX2 + 400, yy, SUPPLY_LINE, lw=140)
label(c, "Supply Duct (cool air)", LX2 + 3000, yy - 60, size=140, anchor="left")
yy -= 1100
lg_line(c, LX2 + 400, yy, RETURN_LINE, lw=140, dash=(200, 140))
label(c, "Return Duct (warm air)", LX2 + 3000, yy - 60, size=140, anchor="left")
yy -= 1100
lg_line(c, LX2 + 400, yy, CHW_SUPPLY, lw=140)
label(c, "CHW Supply (44°F)", LX2 + 3000, yy - 60, size=140, anchor="left")
yy -= 1100
lg_line(c, LX2 + 400, yy, CHW_RETURN, lw=140)
label(c, "CHW Return (54°F)", LX2 + 3000, yy - 60, size=140, anchor="left")
yy -= 1100
diffuser(c, LX2 + 800, yy, r=300)
label(c, "Supply Diffuser (4-way)", LX2 + 2000, yy - 60, size=140, anchor="left")
yy -= 1100
return_grille(c, LX2 + 800, yy, r=280)
label(c, "Return Air Grille", LX2 + 2000, yy - 60, size=140, anchor="left")

# Notes box (small)
NOTES_X = LEG_X + 15000
NOTES_W = 18000
NOTES_Y = LEG_Y
NOTES_H = 7500
c.setFillColor(HexColor("#fffbe6"))
c.setStrokeColor(black)
c.setLineWidth(80)
c.rect(X(NOTES_X), Y(NOTES_Y), S(NOTES_W), S(NOTES_H), stroke=1, fill=1)
label(c, "DESIGN NOTES", NOTES_X + 600, NOTES_Y + NOTES_H - 800, size=220, bold=True)
notes = [
    "• Total cooling load (estimated): 28 TR",
    "• Air-side: 1× AHU (15,000 CFM), 9× FCUs",
    "• Chilled water: 2× 150 TR water-cooled chillers (N+1)",
    "• CHW supply/return: 44°F / 54°F  (ΔT 10°F)",
    "• Zoning: 4 office zones + corridor return",
    "• Outside air: 20 CFM/person (ASHRAE 62.1)",
    "• Filtration: MERV-13 (AHU) + MERV-8 (FCU return)",
    "• Controls: BACnet/Modbus DDC, VAV on AHU zone dampers",
    "• Redundancy: CRAC N+1 in server room",
    "• Acoustics: NC-35 target (offices), NC-40 (open zones)",
]
ny = NOTES_Y + NOTES_H - 1500
for n in notes:
    c.setFillColor(black)
    c.setFont("Helvetica", 130)
    c.drawString(X(NOTES_X + 500), Y(ny), n)
    ny -= 550

# ===================== TITLE BLOCK =====================
# Bottom-right title block
TB_W = 16000
TB_H = 4500
TB_X = BUILD_W - TB_W
TB_Y = -13000
c.setFillColor(white)
c.setStrokeColor(black)
c.setLineWidth(120)
c.rect(X(TB_X), Y(TB_Y), S(TB_W), S(TB_H), stroke=1, fill=1)
# internal divisions
c.setLineWidth(50)
# vertical splits
c.line(X(TB_X + 5000), Y(TB_Y), X(TB_X + 5000), Y(TB_Y + TB_H))
c.line(X(TB_X + 10000), Y(TB_Y), X(TB_X + 10000), Y(TB_Y + TB_H))
# horizontal split
c.line(X(TB_X), Y(TB_Y + 2500), X(TB_X + TB_W), Y(TB_Y + 2500))

# Title block fields
label(c, "PROJECT", TB_X + 300, TB_Y + TB_H - 600, size=140, color=grey, bold=True)
label(c, "Multi-Zone AC System", TB_X + 300, TB_Y + TB_H - 1100, size=210, bold=True)
label(c, "Sample Office Floor — HVAC Layout", TB_X + 300, TB_Y + TB_H - 1500, size=150)

label(c, "DRAWING", TB_X + 300, TB_Y + 1900, size=140, color=grey, bold=True)
label(c, "HVAC-101  •  Floor Plan", TB_X + 300, TB_Y + 1500, size=200, bold=True)
label(c, "Demo / Pitch Reference", TB_X + 300, TB_Y + 1100, size=140)
label(c, "Not for construction", TB_X + 300, TB_Y + 600, size=120, color=HexColor("#a30000"), bold=True)

label(c, "DATE", TB_X + 5300, TB_Y + TB_H - 600, size=140, color=grey, bold=True)
label(c, "2026-07-20", TB_X + 5300, TB_Y + TB_H - 1100, size=200, bold=True)
label(c, "REV.  A", TB_X + 5300, TB_Y + TB_H - 1500, size=160, bold=True)

label(c, "SCALE", TB_X + 5300, TB_Y + 1900, size=140, color=grey, bold=True)
label(c, "1 : 100 (A3)", TB_X + 5300, TB_Y + 1500, size=200, bold=True)
label(c, "Drawing units: millimetres", TB_X + 5300, TB_Y + 1100, size=120)

label(c, "DRAWN BY", TB_X + 10300, TB_Y + TB_H - 600, size=140, color=grey, bold=True)
label(c, "AInchors — Yoda", TB_X + 10300, TB_Y + TB_H - 1100, size=200, bold=True)
label(c, "Checked: K. Mun", TB_X + 10300, TB_Y + TB_H - 1500, size=150)

label(c, "SHEET", TB_X + 10300, TB_Y + 1900, size=140, color=grey, bold=True)
label(c, "01 of 01", TB_X + 10300, TB_Y + 1500, size=200, bold=True)
label(c, "A3 Landscape", TB_X + 10300, TB_Y + 1100, size=140)

# Logo placeholder (top of title block left)
c.setFillColor(HexColor("#0b3a78"))
c.rect(X(TB_X + 200), Y(TB_Y + TB_H - 2400), S(2200), S(1500), stroke=0, fill=1)
c.setFillColor(white)
c.setFont("Helvetica-Bold", 360)
c.drawCentredString(X(TB_X + 1300), Y(TB_Y + TB_H - 2050), "A")
c.setFillColor(white)
c.setFont("Helvetica-Bold", 160)
c.drawString(X(TB_X + 1700), Y(TB_Y + TB_H - 2050), "Inchors")

# ===================== HEADER (above plan) =====================
HDR_Y = BUILD_H + 1500
c.setFillColor(black)
c.setFont("Helvetica-Bold", 320)
c.drawString(X(1000), Y(HDR_Y), "MULTI-ZONE AIR CONDITIONING — SAMPLE FLOOR PLAN")
c.setFont("Helvetica", 180)
c.setFillColor(grey)
c.drawString(X(1000), Y(HDR_Y - 500),
             "4 Office Zones + Corridor Return  •  AHU + 9 FCUs  •  Chilled Water Primary Plant")
c.setFont("Helvetica-Oblique", 150)
c.setFillColor(HexColor("#7a1f1f"))
c.drawRightString(X(BUILD_W - 1000), Y(HDR_Y),
                  "DEMO / PITCH REFERENCE — NOT FOR CONSTRUCTION")

# ===================== ZONE TAGS (overlaid on plan) =====================
# Add zone identification labels near corridor entrance of each zone
zone_tags = [
    (4750,  11000, "ZONE A"),
    (12750, 11000, "ZONE B"),
    (20750, 11000, "ZONE C"),
    (30000, 11000, "ZONE D"),
]
for (zx, zy, ztxt) in zone_tags:
    c.setFillColor(HexColor("#1a3f8a"))
    c.setFont("Helvetica-Bold", 150)
    c.drawCentredString(X(zx), Y(zy - 200), f"▼ {ztxt}")

# Zone thermostat dots
thermo_positions = [
    (4500,  14000), (12500, 14000), (20500, 14000), (30000, 14000),
    (5000,  8200),  (13500, 8200),  (22000, 8200),
]
for (tx, ty) in thermo_positions:
    c.setStrokeColor(black); c.setFillColor(white); c.setLineWidth(50)
    c.circle(X(tx), Y(ty), S(200), stroke=1, fill=1)
    c.setFillColor(red); c.circle(X(tx), Y(ty), S(60), stroke=0, fill=1)
    label(c, "T", tx, ty - 50, size=110, color=black, bold=True)

# Add legend key entry for thermostat via re-render of column 1 already covered.

# Finalize
c.showPage()
c.save()
print("WROTE", OUT, os.path.getsize(OUT), "bytes")
