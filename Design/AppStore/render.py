#!/usr/bin/env python3
"""App Store 用スクリーンショットを HTML で組み、Chrome で 1320×2868 の PNG に書き出す。

  python3 Design/AppStore/render.py            → screenshots/appstore/*.png
  python3 Design/AppStore/render.py 1 3        → 1枚目と3枚目だけ

素材: screenshots/iPhone_17_Pro_Max/*.png（scripts/screenshots.sh で撮影）
"""
import html
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent
SHOTS = ROOT / "screenshots" / "iPhone_17_Pro_Max"
OUT = ROOT / "screenshots" / "appstore"
WORK = ROOT / "build" / "appstore_html"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1320, 2868

# 各ページ: 見出し（[ ] は強調色）、補足、画面、拡大して見せる部分（画面上の px: x, y, w, h）と位置
PAGES = [
    dict(
        key="01_home",
        eyebrow="服薬管理アプリ",
        title="飲み忘れを、<br>[もう]しない。",
        sub="朝・昼・夜・寝る前。今日飲む薬が<br>ひと目でわかり、タップで記録できます",
        shot="1_home", hero=True,
        banner=("おくすリズム", "朝のお薬の時間です", "高血圧の薬（ノルバスク）ほか2件"),
    ),
    dict(
        key="02_interactions",
        eyebrow="飲み合わせチェック",
        title="薬どうしの<br>[飲み合わせ]がわかる",
        sub="今飲んでいる薬の組み合わせを<br>添付文書にもとづいて確認",
        shot="2_interactions",
        badge="出典：PMDA 医療用医薬品の添付文書",
    ),
    dict(
        key="03_visit",
        eyebrow="病院予約リマインド",
        title="薬が切れる前に<br>[受診]をお知らせ",
        sub="残りの数から「なくなる日」を計算。<br>10日前から予約を忘れないよう通知します",
        shot="4_medications",
    ),
    dict(
        key="04_foods",
        eyebrow="飲食物の注意",
        title="[食べ合わせ]も<br>ひと目でわかる",
        sub="お酒・グレープフルーツ・牛乳など<br>気をつけたい飲食物を薬ごとに表示",
        shot="3_foods",
    ),
    dict(
        key="05_calendar",
        eyebrow="カレンダー",
        title="飲めた日が<br>[色でわかる]",
        sub="飲み忘れた日もすぐに見つかり、<br>診察のときにも見せられます",
        shot="5_calendar",
    ),
    dict(
        key="06_stats",
        eyebrow="服薬の記録",
        title="続けた成果が<br>[グラフ]で見える",
        sub="週・月・年の達成率で、<br>毎日の積み重ねを実感できます",
        shot="6_stats",
    ),
    dict(
        key="07_edit",
        eyebrow="かんたん登録",
        title="薬の写真を撮って<br>[かんたん登録]",
        sub="飲む時間と残りの数を入れるだけ。<br>通知は自動で設定されます",
        shot="7_edit",
    ),
]

FONT = (HERE / "fonts").as_uri()

CSS = f"""
@font-face {{ font-family: Maru; font-weight: 500; src: url('{FONT}/ZenMaruGothic-Medium.ttf'); }}
@font-face {{ font-family: Maru; font-weight: 700; src: url('{FONT}/ZenMaruGothic-Bold.ttf'); }}
@font-face {{ font-family: Maru; font-weight: 900; src: url('{FONT}/ZenMaruGothic-Black.ttf'); }}
:root {{
  --navy: #14243f; --blue: #3389e8; --blue-deep: #1f6fd1; --sub: #4f5d74;
  --bg1: #f4f8fe; --bg2: #d9e9fd;
}}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: {W}px; height: {H}px; overflow: hidden; }}
body {{
  font-family: Maru, "Hiragino Maru Gothic ProN", sans-serif; color: var(--navy);
  background: linear-gradient(165deg, var(--bg1) 0%, #e6f0fe 45%, var(--bg2) 100%);
  position: relative; -webkit-font-smoothing: antialiased;
}}
body.hero {{ background: linear-gradient(160deg, #3a93ee 0%, #2b7fe0 45%, #1d63c4 100%); color: #fff; }}

/* 背景の大きな円（奥行き） */
.orb {{ position: absolute; border-radius: 50%; }}
.orb.a {{ width: 1100px; height: 1100px; right: -520px; top: 980px;
  background: radial-gradient(circle at 35% 35%, rgba(255,255,255,.75), rgba(255,255,255,0) 68%); }}
.orb.b {{ width: 900px; height: 900px; left: -480px; top: 1900px;
  background: radial-gradient(circle at 60% 40%, rgba(51,137,232,.16), rgba(51,137,232,0) 70%); }}
body.hero .orb.a {{ background: radial-gradient(circle at 35% 35%, rgba(255,255,255,.22), rgba(255,255,255,0) 68%); }}
body.hero .orb.b {{ background: radial-gradient(circle at 60% 40%, rgba(10,40,110,.35), rgba(10,40,110,0) 70%); }}

.head {{ position: absolute; left: 0; right: 0; top: 150px; text-align: center; }}
.eyebrow {{
  display: inline-block; font-weight: 700; font-size: 46px; letter-spacing: .08em;
  color: var(--blue-deep); background: rgba(255,255,255,.85); border-radius: 999px;
  padding: 16px 44px 18px; margin-bottom: 44px;
  box-shadow: 0 6px 20px rgba(31,111,209,.12);
}}
body.hero .eyebrow {{ color: #fff; background: rgba(255,255,255,.18); box-shadow: none; }}
h1 {{ font-weight: 900; font-size: 122px; line-height: 1.22; letter-spacing: .01em; }}
h1 em {{ font-style: normal; color: var(--blue); }}
body.hero h1 em {{ color: #ffe27a; }}
.sub {{ margin-top: 40px; font-weight: 500; font-size: 50px; line-height: 1.6; color: var(--sub); }}
body.hero .sub {{ color: rgba(255,255,255,.88); }}

/* 端末 */
.phone {{
  position: absolute; left: 50%; transform: translateX(-50%);
  top: 950px; width: 880px; height: 1880px; border-radius: 132px;
  background: #0d0f14; padding: 26px;
  box-shadow: 0 0 0 6px #3a3f4a, 0 0 0 9px #1a1d24, 0 60px 120px rgba(20,45,90,.35), 0 20px 40px rgba(20,45,90,.2);
}}
body.hero .phone {{ top: 975px; box-shadow: 0 0 0 6px #4a515e, 0 0 0 9px #1a1d24, 0 60px 140px rgba(5,25,70,.55); }}
.screen {{ width: 100%; height: 100%; border-radius: 108px; overflow: hidden; position: relative; background: #fff; }}
.screen img {{ width: 100%; display: block; }}
.island {{ position: absolute; top: 26px; left: 50%; transform: translateX(-50%); width: 262px; height: 77px;
  background: #000; border-radius: 50px; }}

/* 通知バナー（1枚目） */
.banner {{
  position: absolute; left: 110px; right: 110px; top: 905px; z-index: 5;
  background: rgba(255,255,255,.97); border-radius: 64px; padding: 44px 52px; display: flex; gap: 40px; align-items: center;
  box-shadow: 0 40px 90px rgba(5,25,70,.40), 0 8px 20px rgba(5,25,70,.18); color: var(--navy);
}}
.banner img {{ width: 150px; height: 150px; border-radius: 36px; flex: none; }}
.banner .app {{ font-size: 40px; font-weight: 700; color: #6b778a; display: flex; justify-content: space-between; }}
.banner .t {{ font-size: 58px; font-weight: 900; margin: 8px 0 6px; }}
.banner .d {{ font-size: 44px; font-weight: 500; color: var(--sub); }}

.badge {{
  position: absolute; left: 50%; transform: translateX(-50%); bottom: 120px; z-index: 5; white-space: nowrap;
  font-size: 42px; font-weight: 700; color: var(--navy); background: #fff; border-radius: 999px; padding: 26px 56px;
  box-shadow: 0 20px 50px rgba(20,45,90,.22);
}}
.badge b {{ display: inline-block; width: 22px; height: 22px; border-radius: 50%; background: #2fb86b; margin-right: 18px; vertical-align: 2px; }}
"""


def title_html(t: str) -> str:
    return t.replace("[", "<em>").replace("]", "</em>")


def page_html(p: dict) -> str:
    shot = (SHOTS / f"{p['shot']}.png").as_uri()
    hero = p.get("hero")
    parts = [f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}</style></head>",
             f"<body class='{'hero' if hero else ''}'>",
             "<div class='orb a'></div><div class='orb b'></div>",
             "<div class='head'>",
             f"<div class='eyebrow'>{html.escape(p['eyebrow'])}</div>",
             f"<h1>{title_html(p['title'])}</h1>",
             f"<p class='sub'>{p['sub']}</p></div>",
             f"<div class='phone'><div class='screen'><img src='{shot}'></div><div class='island'></div></div>"]
    if p.get("banner"):
        app, t, d = p["banner"]
        icon = (HERE / "icon.png").as_uri()
        parts.append(f"<div class='banner'><img src='{icon}'><div style='flex:1'>"
                     f"<div class='app'><span>{app}</span><span>今</span></div>"
                     f"<div class='t'>{t}</div><div class='d'>{d}</div></div></div>")
    if p.get("badge"):
        parts.append(f"<div class='badge'><b></b>{html.escape(p['badge'])}</div>")
    parts.append("</body></html>")
    return "".join(parts)


def main() -> None:
    only = {int(a) for a in sys.argv[1:]}
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    for i, p in enumerate(PAGES, 1):
        if only and i not in only:
            continue
        src = WORK / f"{p['key']}.html"
        src.write_text(page_html(p), encoding="utf-8")
        png = OUT / f"{p['key']}.png"
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                        f"--window-size={W},{H}", "--force-device-scale-factor=1", "--virtual-time-budget=3000",
                        f"--screenshot={png}", src.as_uri()], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(png)


if __name__ == "__main__":
    main()
