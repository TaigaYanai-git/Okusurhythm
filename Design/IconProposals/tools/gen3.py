import json, math, os, shutil

OUT = os.path.expanduser("~/Okusurhythm/Design/IconProposals/round3")
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



def head(rc, w, a1, col, k=1.05, cx=512, cy=512):
    hh = w * k
    delta = math.degrees(w * 1.15 / rc)
    b0, b1, tip = pt(rc - hh, a1, cx, cy), pt(rc + hh, a1, cx, cy), pt(rc, a1 + delta, cx, cy)
    return f'<path d="M {f(b0)} L {f(b1)} L {f(tip)} Z" fill="{hexc(*col)}"/>'


def arrow(rc, w, a0, a1, col):
    return p(arc_band(rc, w, a0, a1 + 0.5, cap0=True, cap1=False), col) + head(rc, w, a1, col)


def ticks(n, r1, r2, w, col, skip=()):
    out = ""
    for i in range(n):
        a = 360 * i / n
        if i in skip:
            continue
        out += (f'<g transform="rotate({a} 512 512)">'
                + rrect(512 - w / 2, 512 - r2, w, r2 - r1, col) + '</g>')
    return out


def hand(prefix=""):
    return capsule_layers(prefix)


CAPL = (0.74, 0.86, 0.99)
CAP = (512, 512, 330, 112, -45)
HAND = {"white": half(*CAP, -1, WHITE), "blue": half(*CAP, 1, CAPL)}
RC, AW = 372, 58
FACE_L, FACE_D = (0.93, 0.96, 1.0), (0.20, 0.30, 0.52)
G_D = (0.22, 0.78, 0.48)

# 1. Hitomawari: one arrow, one full turn; pale face with 4 ticks
write_icon("1-Hitomawari", BG_L, BG_D, [
    group("hand", hand(), sop=0.55, trans=0.15),
    group("ring", [layer("ring", WHITE, WH_D)], sop=0.45, trans=0.15),
    group("face", [layer("ticks", PRIMARY, (0.55, 0.70, 0.98), glass=False),
                   layer("face", FACE_L, FACE_D, opacity=0.35)], sop=0.2, trans=0.5),
], {**HAND,
    "ring": arrow(RC, AW, 30, 318, WHITE),
    "ticks": ticks(4, 268, 318, 26, PRIMARY),
    "face": circ(512, 512, 330, FACE_L)})

# 2. Sanbyoshi: three arrows = morning / noon / night; 3 dots between them
segs = [(14, 92), (134, 212), (254, 332)]
write_icon("2-Sanbyoshi", BG_L, BG_D, [
    group("hand", hand(), sop=0.55, trans=0.15),
    group("ring", [layer("ring", WHITE, WH_D)], sop=0.45, trans=0.15),
    group("face", [layer("face", FACE_L, FACE_D, opacity=0.3)], sop=0.15, trans=0.5),
], {**HAND,
    "ring": "".join(arrow(RC, AW, a0, a1, WHITE) for a0, a1 in segs),
    "face": circ(512, 512, 320, FACE_L)})

# 3. Glass Dial: a floating glass disc with 12 ticks; arrow ring outside
write_icon("3-GlassDial", BG_L, BG_D, [
    group("hand", hand(), sop=0.6, trans=0.15),
    group("dial", [layer("ticks", PRIMARY, (0.60, 0.74, 1.0), glass=False),
                   layer("disc", WHITE, (0.55, 0.68, 0.95), opacity=0.55)],
          shadow="neutral", sop=0.6, trans=0.55),
    group("ring", [layer("ring", LIGHT, (0.70, 0.80, 1.0))], sop=0.35, trans=0.3),
], {**HAND,
    "ticks": ticks(12, 268, 300, 18, PRIMARY, ),
    "disc": circ(512, 512, 318, WHITE),
    "ring": arrow(382, 50, 24, 324, LIGHT)})

# 4. Futairo: the ring inherits the capsule's two colours, two arrows chasing; 3 dots for 朝昼夜
dots3 = "".join(circ(*pt(292, a), 20, PRIMARY) for a in (0, 120, 240))
write_icon("4-Futairo", BG_L, BG_D, [
    group("hand", hand(), sop=0.55, trans=0.15),
    group("ring", [layer("ring-white", WHITE, WH_D), layer("ring-blue", CAPL, CAPL_D)],
          sop=0.45, trans=0.15),
    group("face", [layer("dots", PRIMARY, (0.60, 0.74, 1.0), glass=False),
                   layer("face", FACE_L, FACE_D, opacity=0.3)], sop=0.15, trans=0.5),
], {**HAND,
    "ring-white": arrow(RC, AW, 200, 352, WHITE),
    "ring-blue": arrow(RC, AW, 20, 172, CAPL),
    "dots": dots3,
    "face": circ(512, 512, 320, FACE_L)})
print("ok")
