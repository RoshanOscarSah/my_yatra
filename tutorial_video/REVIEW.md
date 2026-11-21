# Review: How to use MyYatra (tutorial)

1920×1080, 30 fps, 122.7 s. Intro, 12 chapters and an outro. Built from
`build.py`; edit `CHAPTERS` there and run `python3 build.py`.

## Checked

- `npx hyperframes check`: passes. Warnings left on purpose:
  - `film_silent`: no music source (the HeyGen catalog needs a sign-in).
  - `timeline_track_too_dense` on `stage.html`: the phone holds all 27
    screenshots so the push transition can run between chapters.
- Review snapshots of every scene start and middle, and of a screen swap:
  - The phone shows the step's own screen.
  - Each step line appears as its screen arrives, and the previous step dims.
  - No text overlaps, and every reading line is 28 px or larger.
- Every line is held for at least 0.5 s + 0.3 s a word.
- The screenshots are real captures from the iOS simulator (demo account Maya
  Gurung, emulator data). The welcome screen's charging icon was replaced with
  the status bar from the sign-up shot.

## Known limits

- Silent. Add music by signing in (`npx hyperframes auth login`) and asking for a
  calm, warm bed around 90–100 bpm.
- The app screenshots were taken before the Inter font fix, so the app's body
  text shows the iOS system font (SF Pro). At video size it looks almost the
  same as Inter.
