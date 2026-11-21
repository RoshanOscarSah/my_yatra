#!/usr/bin/env python3
"""Builds the MyYatra tutorial composition.

The steps below are the single source of the timing: every screenshot on the
phone and every line on the right is placed from this list, so the two stay in
sync. Edit STEPS, then run `python3 build.py` to rewrite index.html and
compositions/*.html.
"""
import html
import json
import os

FPS = 30

# (chapter title, [(screenshot, step text), ...])
CHAPTERS = [
    ("Create your account", [
        ("01_welcome", "Open MyYatra and tap Get started."),
        ("02_signup", "Enter your name, email and a password, then tap Create account."),
    ]),
    ("Tell us how you travel", [
        ("03_interests", "Pick the kinds of places you enjoy."),
        ("04_style", "Say how often, how and with whom you travel."),
        ("05_plan", "Set your budget, distance and favourite season."),
        ("06_visited", "Tick the districts you have already visited."),
    ]),
    ("Your home screen", [
        ("07_home", "See your footprint, your Journey DNA and this week's picks."),
    ]),
    ("Explore districts", [
        ("08_explore", "Search all 77 districts or filter by province."),
        ("09_district", "Open a district for seasons, costs, travel and food."),
    ]),
    ("Mark a visit", [
        ("10_mark", "Tap Mark visited and choose the date."),
        ("11_places", "Add the places you went and what you did there."),
        ("12_visited_card", "Your visit is saved on the district page."),
    ]),
    ("Safety, reviews and offline", [
        ("13_safety", "Check safety notes and emergency numbers."),
        ("14_review", "Rate and review the district."),
        ("15_review_done", "Your review appears for other travellers."),
        ("16_offline", "Save the district to read it offline."),
    ]),
    ("Plan an itinerary", [
        ("17_itinerary", "Pick dates, budget and companions, then plan day by day."),
    ]),
    ("Your footprint map", [
        ("18_map", "Visited, recommended and not-yet districts on one map."),
    ]),
    ("Picks made for you", [
        ("19_foryou", "Each pick says why it suits you. Thumbs up or down to tune them."),
    ]),
    ("Your Journey DNA", [
        ("20_dna", "Your traveller type and scores across six categories."),
        ("21_gaps", "Gap analysis shows what you have not explored yet."),
    ]),
    ("Journal and statistics", [
        ("22_journal_form", "Write an entry with dates, a story and photos."),
        ("23_journal", "Entries, history and statistics live in one tab."),
        ("24_stats", "Track districts, provinces and journeys over time."),
    ]),
    ("Profile and badges", [
        ("25_profile", "Your profile links to DNA, badges, itineraries and downloads."),
        ("26_badges", "Earn badges and complete district challenges."),
    ]),
]

import wave


def snap(t):
    return round(round(t * FPS) / FPS, 4)


VO_DELAY = 0.2  # voice starts this long after its step appears
VO_GAP = 0.55  # silence after a line before the next step


def vo_len(key):
    path = f"assets/voice/{key}.wav"
    if not os.path.exists(path):
        return 0.0
    with wave.open(path) as w:
        return w.getnframes() / w.getframerate()


INTRO_VO_AT = 0.5
INTRO = snap(max(6.0, INTRO_VO_AT + vo_len("intro") + 0.8))
OUTRO_VO_AT = 0.5
OUTRO = snap(max(5.0, OUTRO_VO_AT + vo_len("outro") + 1.5))
CHAPTER_LEAD = 0.9  # chapter title shows alone before its first step
SWAP = 0.5  # screenshot slide-in time


def step_duration(text, shot):
    words = len(text.split())
    return snap(max(3.6, 1.1 + 0.32 * words, VO_DELAY + vo_len(shot) + VO_GAP))


# ---- timing -------------------------------------------------------------
t = INTRO
chapters = []
for ci, (title, steps) in enumerate(CHAPTERS):
    start = t
    t += CHAPTER_LEAD
    st = []
    for shot, text in steps:
        d = step_duration(text, shot)
        st.append({"shot": shot, "text": text, "start": snap(t), "dur": d})
        t += d
    chapters.append({"i": ci, "title": title, "start": snap(start),
                     "dur": snap(t - start), "steps": st})
TOTAL = snap(t + OUTRO)
OUTRO_START = snap(t)

# Phone screens: the first chapter's first step reuses the intro screen.
screens = [{"shot": "01_welcome", "start": 0.0}]
for ch in chapters:
    for i, s in enumerate(ch["steps"]):
        # Show the screen as the chapter title lands for a chapter's first step.
        at = ch["start"] + 0.3 if i == 0 else s["start"]
        if s["shot"] != screens[-1]["shot"]:
            screens.append({"shot": s["shot"], "start": snap(at)})
screens.append({"shot": "07_home", "start": snap(OUTRO_START + 0.2)})
for i, s in enumerate(screens):
    end = screens[i + 1]["start"] + SWAP if i + 1 < len(screens) else TOTAL
    s["dur"] = snap(end - s["start"])

# ---- shared styles ------------------------------------------------------
FONTS = """
@font-face { font-family: 'Lora'; font-weight: 600; src: url('assets/fonts/Lora-SemiBold.ttf'); }
"""
TOKENS = """
  --background: #FFF6EC; --surface: #FFFFFF; --primary: #8B2635;
  --primary-soft: #F3DDE0; --lavender: #EDE6F6; --gold-soft: #FBF0D9;
  --gold: #E0A63A; --text: #2A1E1E; --text-2: #6E625F; --border: #EADBCB;
"""
E = html.escape


def write(path, text):
    with open(path, "w") as f:
        f.write(text)


# ---- stage: background, brand and phone ---------------------------------
PH_H = 880
PH_W = round(PH_H * 1206 / 2622)  # 405
BEZEL = 14
FRAME_W, FRAME_H = PH_W + 2 * BEZEL, PH_H + 2 * BEZEL
FRAME_X = 600 - FRAME_W // 2
FRAME_Y = (1080 - FRAME_H) // 2

imgs, tweens = [], []
for i, s in enumerate(screens):
    sid = f"scr-{i:02d}"
    imgs.append(
        f'        <img id="{sid}" class="clip scr" src="assets/shots/{s["shot"]}.png" '
        f'alt="" data-start="{s["start"]}" data-duration="{s["dur"]}" '
        f'data-track-index="{2 + i % 2}" style="z-index:{i + 1}" />')
    if i > 0:
        tweens.append(
            f'      tl.to("#{sid}", '
            f'{{ xPercent: 0, duration: {SWAP}, ease: "power3.inOut" }}, {s["start"]});')
        # The outgoing screen slides partly left underneath, like an iOS push.
        tweens.append(
            f'      tl.to("#scr-{i - 1:02d}", '
            f'{{ xPercent: -30, duration: {SWAP}, ease: "power3.inOut" }}, {s["start"]});')

stage = f"""<template>
  <style>
    {FONTS}
    #root {{ position: absolute; inset: 0; {TOKENS}
      background: var(--background); overflow: hidden; }}
    #stage-glow-a {{ position: absolute; width: 1100px; height: 1100px; left: -260px; top: -40px;
      border-radius: 50%; background: radial-gradient(circle, rgba(243,221,224,0.95) 0%, rgba(243,221,224,0) 68%); }}
    #stage-glow-b {{ position: absolute; width: 900px; height: 900px; right: -300px; bottom: -420px;
      border-radius: 50%; background: radial-gradient(circle, rgba(251,240,217,1) 0%, rgba(251,240,217,0) 70%); }}
    #stage-brand {{ position: absolute; left: 72px; top: 54px; display: flex; align-items: center; gap: 12px;
      font-family: 'Lora'; font-weight: 600; font-size: 30px; color: var(--primary); }}
    #stage-brand span {{ font-family: 'Inter'; font-weight: 400; font-size: 28px; color: var(--text-2);
      padding-left: 14px; border-left: 2px solid var(--border); }}
    #stage-dot {{ width: 16px; height: 16px; border-radius: 50%; background: var(--primary); }}
    #stage-phone {{ position: absolute; left: {FRAME_X}px; top: {FRAME_Y}px; width: {FRAME_W}px; height: {FRAME_H}px;
      border-radius: 70px; background: #1C1416; padding: {BEZEL}px;
      box-shadow: 0 50px 90px rgba(139,38,53,0.20), 0 10px 24px rgba(42,30,30,0.18), inset 0 0 0 2px #3a2d30; }}
    #stage-screen {{ position: relative; width: {PH_W}px; height: {PH_H}px; border-radius: 56px; overflow: hidden;
      background: var(--background); }}
    .scr {{ position: absolute; left: 0; top: 0; width: 100%; height: 100%; box-shadow: -12px 0 30px rgba(42,30,30,0.18); }}
    #stage-island {{ position: absolute; left: 50%; top: 11px; width: 118px; height: 34px; margin-left: -59px;
      border-radius: 20px; background: #000; z-index: 200; }}
  </style>
  <div id="root" data-composition-id="stage" data-width="1920" data-height="1080">
    <div id="stage-glow-a" data-layout-allow-overflow></div>
    <div id="stage-glow-b" data-layout-allow-overflow></div>
    <div id="stage-brand"><div id="stage-dot"></div>MyYatra<span>App tutorial</span></div>
    <div id="stage-phone">
      <div id="stage-screen">
{chr(10).join(imgs)}
        <div id="stage-island"></div>
      </div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
    // Baseline: every screen but the first waits off to the right.
    tl.set(".scr", {{ xPercent: 100 }}, 0);
    tl.set("#scr-00", {{ xPercent: 0 }}, 0);
{chr(10).join(tweens)}
    window.__timelines["stage"] = tl;
  </script>
</template>
"""
write("compositions/stage.html", stage)

# ---- right-hand text: shared CSS ---------------------------------------
PANEL_CSS = f"""
    {FONTS}
    #root {{ position: absolute; inset: 0; {TOKENS} }}
    .panel {{ position: absolute; left: 1000px; top: 0; width: 780px; height: 1080px;
      display: flex; flex-direction: column; justify-content: center; }}
    .kicker {{ font-family: 'Inter'; font-weight: 600; font-size: 28px; letter-spacing: 0.12em;
      text-transform: uppercase; color: var(--primary); margin-bottom: 18px; }}
    .title {{ font-family: 'Lora'; font-weight: 600; font-size: 70px; line-height: 1.08; color: var(--text);
      letter-spacing: -0.01em; margin-bottom: 44px; }}
    .steps {{ display: flex; flex-direction: column; gap: 26px; }}
    .step {{ display: flex; align-items: flex-start; gap: 24px; }}
    .num {{ flex: none; width: 52px; height: 52px; border-radius: 50%; display: flex; align-items: center;
      justify-content: center; font-family: 'Inter'; font-weight: 700; font-size: 28px;
      background: var(--primary); color: #fff; }}
    .txt {{ position: relative; font-family: 'Inter'; font-weight: 400; font-size: 34px; line-height: 1.32;
      color: var(--text); padding-top: 4px; }}
    .progress {{ position: absolute; left: 1000px; bottom: 74px; display: flex; gap: 8px; }}
    .seg {{ width: 46px; height: 6px; border-radius: 3px; background: var(--border); overflow: hidden; }}
    .seg-fill {{ width: 100%; height: 100%; background: var(--primary); transform-origin: left center; }}
"""


def progress(ci, cid, anim_at):
    segs = []
    for k in range(12):
        fill = ""
        if k < ci:
            fill = '<div class="seg-fill"></div>'
        elif k == ci:
            fill = f'<div class="seg-fill" id="{cid}-cur"></div>'
        segs.append(f'<div class="seg">{fill}</div>')
    return f'<div class="progress" id="{cid}-progress">{"".join(segs)}</div>'


hosts = []
hosts.append(("intro", 0.0, INTRO))

# ---- intro --------------------------------------------------------------
intro = f"""<template>
  <style>
    {PANEL_CSS}
    #intro-title {{ font-size: 96px; margin-bottom: 30px; }}
    #intro-sub {{ font-family: 'Inter'; font-size: 34px; line-height: 1.4; color: var(--text-2); max-width: 700px; }}
    #intro-rule {{ width: 120px; height: 6px; border-radius: 3px; background: var(--gold); margin-bottom: 34px; transform-origin: left center; }}
  </style>
  <div id="root" data-composition-id="intro" data-width="1920" data-height="1080">
    <div class="panel" id="intro-panel" data-hold>
      <div class="kicker" id="intro-kicker">App tutorial</div>
      <div class="title" id="intro-title">How to use MyYatra</div>
      <div id="intro-rule"></div>
      <div id="intro-sub">Every district, a new story. Twelve steps, from sign-up to your first badge.</div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
    tl.fromTo("#intro-kicker", {{ y: 16, opacity: 0 }}, {{ y: 0, opacity: 1, duration: 0.5, ease: "power3.out" }}, 0.15);
    tl.fromTo("#intro-title", {{ y: 30, opacity: 0 }}, {{ y: 0, opacity: 1, duration: 0.8, ease: "power3.out" }}, 0.3);
    tl.fromTo("#intro-rule", {{ scaleX: 0 }}, {{ scaleX: 1, duration: 0.6, ease: "power2.inOut" }}, 0.7);
    tl.fromTo("#intro-sub", {{ y: 16, opacity: 0 }}, {{ y: 0, opacity: 1, duration: 0.6, ease: "power3.out" }}, 0.8);
    tl.to("#intro-panel", {{ opacity: 0, y: -20, duration: 0.4, ease: "power2.in" }}, {INTRO - 0.45});
    window.__timelines["intro"] = tl;
  </script>
</template>
"""
write("compositions/intro.html", intro)

# ---- chapters -----------------------------------------------------------
for ch in chapters:
    cid = f"ch{ch['i'] + 1:02d}"
    rows, tw = [], []
    base = ch["start"]
    for k, s in enumerate(ch["steps"]):
        local = snap(s["start"] - base)
        rid = f"{cid}-s{k}"
        rows.append(f"""        <div class="step" id="{rid}">
          <div class="num" id="{rid}-num">{k + 1}</div>
          <div class="txt" id="{rid}-txt">{E(s['text'])}</div>
        </div>""")
        # Arrive, then dim when the next step arrives.
        tw.append(f'    tl.fromTo("#{rid}", {{ y: 24, opacity: 0 }}, {{ y: 0, opacity: 1, duration: 0.5, ease: "power3.out" }}, {local});')
        if k + 1 < len(ch["steps"]):
            nxt = snap(ch["steps"][k + 1]["start"] - base)
            tw.append(f'    tl.fromTo("#{rid}-num", {{ backgroundColor: "#8B2635", color: "#FFFFFF" }}, {{ backgroundColor: "#F3DDE0", color: "#8B2635", duration: 0.4, ease: "power2.out" }}, {nxt});')
            tw.append(f'    tl.fromTo("#{rid}-txt", {{ color: "#2A1E1E" }}, {{ color: "#6E625F", duration: 0.4, ease: "power2.out" }}, {nxt});')
    end = ch["dur"]
    comp = f"""<template>
  <style>
    {PANEL_CSS}
  </style>
  <div id="root" data-composition-id="{cid}" data-width="1920" data-height="1080">
    <div class="panel" id="{cid}-panel">
      <div class="kicker" id="{cid}-kicker">Step {ch['i'] + 1:02d} of 12</div>
      <div class="title" id="{cid}-title">{E(ch['title'])}</div>
      <div class="steps">
{chr(10).join(rows)}
      </div>
    </div>
    {progress(ch['i'], cid, 0.3)}
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
    tl.fromTo("#{cid}-kicker", {{ y: 14, opacity: 0 }}, {{ y: 0, opacity: 1, duration: 0.45, ease: "power3.out" }}, 0.1);
    tl.fromTo("#{cid}-title", {{ y: 26, opacity: 0 }}, {{ y: 0, opacity: 1, duration: 0.6, ease: "power3.out" }}, 0.2);
    tl.fromTo("#{cid}-cur", {{ scaleX: 0 }}, {{ scaleX: 1, duration: {snap(end - 0.6)}, ease: "none" }}, 0.2);
{chr(10).join(tw)}
    tl.to("#{cid}-panel", {{ opacity: 0, y: -18, duration: 0.35, ease: "power2.in" }}, {snap(end - 0.4)});
    window.__timelines["{cid}"] = tl;
  </script>
</template>
"""
    write(f"compositions/{cid}.html", comp)
    hosts.append((cid, ch["start"], ch["dur"]))

# ---- outro --------------------------------------------------------------
outro = f"""<template>
  <style>
    {PANEL_CSS}
    #outro-title {{ font-size: 92px; margin-bottom: 30px; }}
    #outro-sub {{ font-family: 'Inter'; font-size: 34px; line-height: 1.4; color: var(--text-2); max-width: 700px; }}
    #outro-rule {{ width: 120px; height: 6px; border-radius: 3px; background: var(--gold); margin-bottom: 34px; transform-origin: left center; }}
  </style>
  <div id="root" data-composition-id="outro" data-width="1920" data-height="1080">
    <div class="panel">
      <div class="kicker" id="outro-kicker">You're ready</div>
      <div class="title" id="outro-title">Start your yatra.</div>
      <div id="outro-rule"></div>
      <div id="outro-sub">Mark your first district and watch your Journey DNA grow.</div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
    tl.fromTo("#outro-kicker", {{ y: 16, opacity: 0 }}, {{ y: 0, opacity: 1, duration: 0.5, ease: "power3.out" }}, 0.3);
    tl.fromTo("#outro-title", {{ y: 30, opacity: 0 }}, {{ y: 0, opacity: 1, duration: 0.8, ease: "power3.out" }}, 0.45);
    tl.fromTo("#outro-rule", {{ scaleX: 0 }}, {{ scaleX: 1, duration: 0.6, ease: "power2.inOut" }}, 0.9);
    tl.fromTo("#outro-sub", {{ y: 16, opacity: 0 }}, {{ y: 0, opacity: 1, duration: 0.6, ease: "power3.out" }}, 1.1);
    window.__timelines["outro"] = tl;
  </script>
</template>
"""
write("compositions/outro.html", outro)
hosts.append(("outro", OUTRO_START, snap(TOTAL - OUTRO_START)))

# ---- root ---------------------------------------------------------------
host_tags = [f"""      <div id="stage" data-composition-id="stage" data-composition-src="compositions/stage.html"
        data-start="0" data-duration="{TOTAL}" data-track-index="0" data-track-kind="graphics"
        data-width="1920" data-height="1080" style="z-index:0"></div>"""]
for n, (cid, start, dur) in enumerate(hosts):
    host_tags.append(f"""      <div id="{cid}" data-composition-id="{cid}" data-composition-src="compositions/{cid}.html"
        data-start="{start}" data-duration="{dur}" data-track-index="{1 + n % 2}" data-track-kind="graphics"
        data-width="1920" data-height="1080" style="z-index:1"></div>""")

vo_tags = []


def vo_tag(key, start):
    d = vo_len(key)
    if d:
        vo_tags.append(f'      <audio id="vo-{key}" class="clip" src="assets/voice/{key}.wav" '
                       f'data-start="{snap(start)}" data-duration="{round(d, 3)}" '
                       f'data-track-index="{5 + len(vo_tags) % 2}"></audio>')


vo_tag("intro", INTRO_VO_AT)
for ch in chapters:
    for s_ in ch["steps"]:
        vo_tag(s_["shot"], s_["start"] + VO_DELAY)
vo_tag("outro", OUTRO_START + OUTRO_VO_AT)

index = f"""<!doctype html>
<html lang="en" data-resolution="landscape">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1920, height=1080" />
    <title>How to use MyYatra</title>
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.15.0/dist/gsap.min.js"></script>
    <style>
      * {{ margin: 0; padding: 0; box-sizing: border-box; }}
      html, body {{ margin: 0; width: 1920px; height: 1080px; overflow: hidden; background: #FFF6EC; }}
      #root {{ position: relative; width: 100%; height: 100%; }}
      #root > div {{ position: absolute; inset: 0; }}
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{TOTAL}"
      data-width="1920" data-height="1080">
{chr(10).join(host_tags)}
{chr(10).join(vo_tags)}
    </div>
    <script>
      window.__timelines["main"] = gsap.timeline({{ paused: true }});
    </script>
  </body>
</html>
"""
write("index.html", index)
print(f"total {TOTAL}s, {len(screens)} screens, {len(chapters)} chapters")
print(json.dumps([(c['title'], c['start'], c['dur']) for c in chapters]))
