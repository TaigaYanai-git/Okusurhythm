import json, math, os, shutil

OUT = os.path.expanduser("~/Okusurhythm/Design/IconProposals/round2")
CX = CY = 512.0


def pt(r, deg, cx=None, cy=None):
    cx = CX if cx is None else cx
    cy = CY if cy is None else cy
    a = math.radians(deg)
    return (cx + r * math.sin(a), cy - r * math.cos(a))


def f(p):
    return f"{p[0]:.2f} {p[1]:.2f}"


def arc_band(rc, w, a0, a1, cap0=True, cap1=True, cx=None, cy=None):
    P = lambda r, a: pt(r, a, cx, cy)
    """Annular band centred on radius rc, width w, clockwise from a0 to a1 (0 = top)."""
    R, r, h = rc + w / 2, rc - w / 2, w / 2
    large = 1 if (a1 - a0) % 360 > 180 else 0
    d = f"M {f(P(R, a0))} A {R} {R} 0 {large} 1 {f(P(R, a1))} "
    d += f"A {h} {h} 0 0 1 {f(P(r, a1))} " if cap1 else f"L {f(P(r, a1))} "
    d += f"A {r} {r} 0 {large} 0 {f(P(r, a0))} "
    d += f"A {h} {h} 0 0 1 {f(P(R, a0))} Z" if cap0 else "Z"
    return d


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
            f'viewBox="0 0 1024 1024">{body}</svg>\n')


def c(r, g, b, a=1.0):
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},{a:.5f}"


def hexc(r, g, b):
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def grad(top, bottom):
    return {"linear-gradient": [c(*top), c(*bottom)],
            "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}}}


def layer(name, light, dark=None, glass=True, opacity=None):
    L = {"glass": glass, "image-name": f"{name}.svg", "name": name,
         "position": {"scale": 1, "translation-in-points": [0, 0]},
         "fill-specializations": [{"value": {"solid": c(*light)}},
                                  {"appearance": "dark", "value": {"solid": c(*(dark or light))}}]}
    if opacity is not None:
        L["opacity"] = opacity
    return L


def group(name, layers, shadow="neutral", sop=0.5, trans=0.4, spec=True):
    return {"name": name, "layers": layers,
            "shadow": {"kind": shadow, "opacity": sop},
            "translucency": {"enabled": trans > 0, "value": trans},
            "specular": spec}


def write_icon(name, bg_light, bg_dark, groups, shapes):
    d = os.path.join(OUT, f"{name}.icon")
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(os.path.join(d, "Assets"))
    for fname, body in shapes.items():
        with open(os.path.join(d, "Assets", f"{fname}.svg"), "w") as fh:
            fh.write(svg(body))
    doc = {"fill-specializations": [{"value": bg_light}, {"appearance": "dark", "value": bg_dark}],
           "groups": groups,
           "supported-platforms": {"circles": ["watchOS"], "squares": "shared"}}
    with open(os.path.join(d, "icon.json"), "w") as fh:
        json.dump(doc, fh, indent=2)


# palette
PRIMARY = (0.20, 0.55, 0.91)
LIGHT = (0.88, 0.94, 1.00)
WHITE = (1.0, 1.0, 1.0)
GREEN = (0.18, 0.72, 0.42)
NAVY = (0.10, 0.22, 0.48)
SKY_TOP = (0.45, 0.72, 0.98)
SKY_BOT = (0.16, 0.47, 0.86)
NIGHT_TOP = (0.05, 0.09, 0.19)
NIGHT_BOT = (0.09, 0.17, 0.34)
BG_L = grad(SKY_TOP, SKY_BOT)
BG_D = grad(NIGHT_TOP, NIGHT_BOT)


def p(d, col):
    return f'<path d="{d}" fill="{hexc(*col)}"/>'


def circ(x, y, r, col):
    return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r:.2f}" fill="{hexc(*col)}"/>'


def rrect(x, y, w, h, col, rad=None):
    rad = h / 2 if rad is None else rad
    return f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" rx="{rad:.2f}" fill="{hexc(*col)}"/>'



CAPL = (0.80, 0.89, 0.99)   # light half of the original capsule
CAPL_D = (0.62, 0.76, 0.98)
WH_D = (0.94, 0.96, 1.0)


def half(cx, cy, L, r, ang, side, col, gap=3):
    """One half of a capsule. side=-1 is the round-left half (white in the original)."""
    if side < 0:
        d = (f"M {-gap} {-r} H {-L/2} A {r} {r} 0 0 0 {-L/2} {r} H {-gap} Z")
    else:
        d = (f"M {gap} {-r} H {L/2} A {r} {r} 0 0 1 {L/2} {r} H {gap} Z")
    return (f'<g transform="translate({cx:.2f} {cy:.2f}) rotate({ang})">'
            f'<path d="{d}" fill="{hexc(*col)}"/></g>')


def capsule_layers(prefix):
    return [layer(f"{prefix}white", WHITE, WH_D), layer(f"{prefix}blue", CAPL, CAPL_D)]


# ---------- A. Ankokoro (safe): the original, in Liquid Glass ----------
C = (470, 470, 396, 136, -45)
check = ('<path d="M 690 742 L 735 788 L 808 700" fill="none"/>')
# check mark as filled polygon (strokes are unreliable in ictool)
def thick_poly(pts, w):
    out = ""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy)
        ang = math.degrees(math.atan2(dy, dx))
        out += (f'<g transform="translate({x0} {y0}) rotate({ang:.2f})">'
                f'<rect x="{-w/2}" y="{-w/2}" width="{L + w:.2f}" height="{w}" rx="{w/2}" fill="#ffffff"/></g>')
    return out
write_icon(
    "A-Anshin", BG_L, BG_D,
    [
        group("badge", [layer("check", WHITE, WHITE, glass=False),
                        layer("badge", GREEN, (0.22, 0.78, 0.48)),
                        layer("rim", WHITE, WH_D)], shadow="layer-color", sop=0.5, trans=0.1),
        group("capsule", capsule_layers(""), sop=0.5, trans=0.2),
    ],
    {
        "white": half(*C, -1, WHITE), "blue": half(*C, 1, CAPL),
        "check": thick_poly([(682, 744), (733, 795), (812, 700)], 44),
        "badge": circ(748, 748, 140, GREEN),
        "rim": circ(748, 748, 168, WHITE),
    })

# ---------- B. Mittsu no Tsubu: capsule + three beats (morning / noon / night) ----------
C = (466, 466, 420, 142, -45)
dots = [(560, 790), (680, 680), (800, 560)]
write_icon(
    "B-MittsuNoTsubu", BG_L, BG_D,
    [
        group("capsule", capsule_layers(""), sop=0.5, trans=0.2),
        group("beats", [layer("done", GREEN, (0.22, 0.78, 0.48)),
                        layer("next", WHITE, (0.80, 0.86, 1.0), opacity=0.6)],
              shadow="layer-color", sop=0.4, trans=0.3),
    ],
    {
        "white": half(*C, -1, WHITE), "blue": half(*C, 1, CAPL),
        "done": circ(*dots[0], 56, GREEN) + circ(*dots[1], 56, GREEN),
        "next": circ(*dots[2], 56, WHITE),
    })

# ---------- C. Tokei no Hari: the capsule is the hand of a day dial ----------
C = (512, 512, 400, 132, -45)
ticks = [pt(380, a) for a in (0, 120, 240)]
write_icon(
    "C-TokeiNoHari", BG_L, BG_D,
    [
        group("hand", capsule_layers(""), sop=0.55, trans=0.2),
        group("ticks", [layer("now", GREEN, (0.22, 0.78, 0.48)),
                        layer("ticks", WHITE, WH_D)], shadow="layer-color", sop=0.35, trans=0.2),
        group("dial", [layer("dial", LIGHT, (0.45, 0.60, 0.90), opacity=0.5)], sop=0.15, trans=0.6),
    ],
    {
        "white": half(*C, -1, WHITE), "blue": half(*C, 1, CAPL),
        "now": circ(*ticks[0], 40, GREEN),
        "ticks": circ(*ticks[1], 40, WHITE) + circ(*ticks[2], 40, WHITE),
        "dial": p(arc_band(380, 22, 8, 112), LIGHT) + p(arc_band(380, 22, 128, 232), LIGHT)
                + p(arc_band(380, 22, 248, 352), LIGHT),
    })

# ---------- D. Kasanari: three capsules in step, today over yesterday ----------
caps = [(392, 392), (512, 512), (632, 632)]
L, R = 320, 104
write_icon(
    "D-Kasanari", BG_L, BG_D,
    [
        group("front", capsule_layers(""), sop=0.55, trans=0.2),
        group("middle", [layer("mid", LIGHT, (0.55, 0.70, 0.95), opacity=0.75)], sop=0.35, trans=0.45),
        group("back", [layer("back", LIGHT, (0.45, 0.60, 0.90), opacity=0.45)], sop=0.2, trans=0.6),
    ],
    {
        "white": half(*caps[2], L, R, -45, -1, WHITE), "blue": half(*caps[2], L, R, -45, 1, CAPL),
        "mid": half(*caps[1], L, R, -45, -1, LIGHT) + half(*caps[1], L, R, -45, 1, LIGHT),
        "back": half(*caps[0], L, R, -45, -1, LIGHT) + half(*caps[0], L, R, -45, 1, LIGHT),
    })
print("ok")
