# Aura Bank promo (15 s, 1920x1080, 60 fps)

A HyperFrames composition. `index.html` is only the layer stack and the audio;
every layer is a sub-composition under `compositions/` with its own timeline.

| Layer | Window (s) | What it does |
| --- | --- | --- |
| `world` | 0–15 | GPU aurora (one fragment pass) and a parallax star field that streaks with camera speed. Its camera follows every scene move: logo dive, whip to web, tilt to console, finale rush. |
| `s1-logo` | 0–2.6 | The mark is traced by a light comet shedding sparks, the badge forms behind it, the wordmark unrolls, then the camera dives through the arch. |
| `s2-mobile` | 2.3–5.75 | Pull-back out of the dive onto a phone with a milled 3D edge: Face ID scan, wallet, notification, odometer balance, spark burst. |
| `card3d` | 4.6–5.8 | Three.js: the wallet card lifts out of the phone as a real beveled card (clearcoat, foil ribbon with iridescence, HDR studio reflections, sub-frame motion blur) and carries the whip to the web. |
| `s3-web` | 5.3–8.75 | Browser on a 3D rig, cursor on curved paths, CTA that becomes the modal, send button that morphs to a spinner and lands. |
| `s4-console` | 8.15–12.15 | Console rises with the tilt, Laya scans the queue, two hand-drawn signatures, approval flips like a departures board, rush into the downbeat. |
| `s5-endcard` | 11.9–15 | Out of the flash: badge turns into place with real depth, tagline catches the light, three surfaces. |
| `fx` | 0–15 | Light that crosses cuts: the sent transfer's comet, rush streaks, finale shockwave and sparks. |
| `finish` | 0–15 | Light leaks on each hand-off, impact flash, seeded film grain, fade out. |

Shared helpers, brand palette and the card painter (used by the DOM cards and the
3D card texture) live in `assets/js/aura-kit.js`. Canvas layers are pure
functions of time, so any frame renders identically in any seek order.

Voiceover and music bed are unchanged; SFX are retimed to the new beats.

```bash
npm run check    # lint, runtime, layout, motion, contrast
npm run render   # MP4
```
