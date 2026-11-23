import json, math, os, shutil

OUT = os.path.expanduser("~/Okusurhythm/Design/IconProposals")
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


# ---------- 1. Hitomeguri: a day ring in three beats, progress through the day ----------
RC, W = 316, 92
segs = [(14, 106), (134, 226), (254, 346)]  # morning / noon / night
write_icon(
    "1-Hitomeguri", BG_L, BG_D,
    [
        group("tablet", [layer("score", PRIMARY, (0.30, 0.55, 0.90), glass=False),
                         layer("tablet", WHITE, (0.92, 0.95, 1.0))], sop=0.5, trans=0.15),
        group("done", [layer("done", WHITE, (0.92, 0.95, 1.0))], sop=0.45, trans=0.2),
        group("next", [layer("next", LIGHT, (0.55, 0.70, 0.95), opacity=0.55)],
              sop=0.25, trans=0.6),
    ],
    {
        "score": f'<g transform="rotate(-45 512 512)">' + rrect(512 - 100, 512 - 13, 200, 26, PRIMARY) + "</g>",
        "tablet": circ(512, 512, 148, WHITE),
        "done": p(arc_band(RC, W, *segs[0]), WHITE) + p(arc_band(RC, W, *segs[1]), WHITE),
        "next": p(arc_band(RC, W, *segs[2]), LIGHT),
    })

# ---------- 2. Asa-Hiru-Yoru: three tablets travelling the sky like the sun ----------
ACX, ACY, AR = 512, 965, 470
tabs = [(*pt(AR, -46, ACX, ACY), 100), (*pt(AR, 0, ACX, ACY), 120), (*pt(AR, 46, ACX, ACY), 100)]
def scored(x, y, r, col, ang):
    L, T = r * 1.24, r * 0.16
    return (f'<g transform="rotate({ang} {x:.2f} {y:.2f})">'
            + rrect(x - L / 2, y - T / 2, L, T, col) + '</g>')
write_icon(
    "2-AsaHiruYoru", BG_L, BG_D,
    [
        group("tablets", [
            layer("scores", PRIMARY, (0.30, 0.55, 0.90), glass=False, opacity=0.8),
            layer("noon", WHITE, (0.95, 0.97, 1.0)),
            layer("morning", LIGHT, (0.80, 0.88, 1.0)),
            layer("night", NAVY, (0.30, 0.42, 0.75)),
        ], shadow="layer-color", sop=0.5, trans=0.2),
        group("horizon", [layer("path", LIGHT, (0.45, 0.60, 0.90), opacity=0.6)],
              sop=0.2, trans=0.6),
    ],
    {
        "scores": scored(*tabs[0], PRIMARY, -46) + scored(*tabs[1], PRIMARY, 0)
                  + scored(*tabs[2], PRIMARY, 46),
        "noon": circ(*tabs[1], WHITE),
        "morning": circ(*tabs[0], LIGHT),
        "night": circ(*tabs[2], NAVY),
        # the arc the tablets ride on
        "path": p(arc_band(AR, 30, -60, 60, cx=ACX, cy=ACY), LIGHT),
    })

# ---------- 3. Kizami: a step sequencer, one capsule per row = morning / noon / night ----------
rows = [332, 512, 692]
cap_x = [170, 367, 564]  # left edge of the capsule on each row
CW, CH = 290, 124
tracks = "".join(rrect(160, y - 20, 704, 40, LIGHT) for y in rows)
left = "".join(rrect(x, y - CH / 2, CW / 2 + CH / 2, CH, WHITE) for x, y in zip(cap_x, rows))
right_parts = []
for x, y in zip(cap_x, rows):
    # right half: flat left edge, round right end
    x0 = x + CW / 2 + 3
    right_parts.append(f'<path d="M {x0:.2f} {y-CH/2:.2f} H {x+CW-CH/2:.2f} '
                       f'A {CH/2} {CH/2} 0 0 1 {x+CW-CH/2:.2f} {y+CH/2:.2f} H {x0:.2f} Z" '
                       f'fill="{hexc(*LIGHT)}"/>')
# left half: round left end, flat right edge
left = "".join(f'<path d="M {x+CW/2-3:.2f} {y-CH/2:.2f} H {x+CH/2:.2f} '
               f'A {CH/2} {CH/2} 0 0 0 {x+CH/2:.2f} {y+CH/2:.2f} H {x+CW/2-3:.2f} Z" '
               f'fill="#ffffff"/>' for x, y in zip(cap_x, rows))
write_icon(
    "3-Kizami", BG_L, BG_D,
    [
        group("capsules", [layer("cap-left", WHITE, (0.94, 0.96, 1.0)),
                           layer("cap-right", LIGHT, (0.62, 0.76, 0.98))],
              sop=0.5, trans=0.2),
        group("tracks", [layer("tracks", LIGHT, (0.45, 0.60, 0.90), opacity=0.45)],
              sop=0.15, trans=0.6),
    ],
    {"cap-left": left, "cap-right": "".join(right_parts), "tracks": tracks})

# ---------- 4. Meguru Capsule: the two-tone capsule bent into a loop, next dose in the gap ----------
RC4, W4 = 268, 150
seam = 225
write_icon(
    "4-MeguruCapsule", BG_L, BG_D,
    [
        group("dose", [layer("dose", GREEN, (0.22, 0.78, 0.48))], shadow="layer-color",
              sop=0.5, trans=0.1),
        group("capsule", [layer("half-a", WHITE, (0.94, 0.96, 1.0)),
                          layer("half-b", LIGHT, (0.62, 0.76, 0.98))], sop=0.5, trans=0.25),
    ],
    {
        "half-a": p(arc_band(RC4, W4, 85, seam - 1.2, cap0=True, cap1=False), WHITE),
        "half-b": p(arc_band(RC4, W4, seam + 1.2, 365, cap0=False, cap1=True), LIGHT),
        "dose": circ(*pt(RC4, 45), 70, GREEN),
    })
print("ok")
