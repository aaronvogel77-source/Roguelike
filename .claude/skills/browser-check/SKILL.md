---
name: browser-check
description: Build the Arcana web export, serve it locally and take Playwright screenshots of menu, run, packs, vault or the skin arena. Use to verify any visible change before reporting it.
---

# Browser check

Everything runs locally: the build is served on `localhost:8765` only, the browser is the pre-installed Chromium.
Screenshots go to the session scratchpad, never into the repository.

1. **Build and serve:**
   ```bash
   godot --headless --export-release "Web" build/web/index.html 2>&1 | grep -E "SCRIPT ERROR|Parse Error"
   pgrep -f "http.server 8765" >/dev/null || (nohup python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web >/dev/null 2>&1 &)
   ```
2. **Run a sequence** (iPhone 13 landscape, 750×342 CSS pixels):
   ```bash
   node .claude/skills/browser-check/scripts/shot_seq.js <out_dir> '<url query>' '<steps json>'
   ```
   Steps: `["tap", x, y, wait_ms, screenshot 0/1]` or `["wait", 0, 0, wait_ms, 1]`.
   Screenshots are 2250×1026; CSS coordinates = screenshot pixels / 3.
3. **Useful URLs:** `?debug=1` (main menu, debug tools), `?seed=7&debug=1` (run starts directly),
   `?arena=1&seed=N` (test battles with random fusions), `?arena=1&skins=1` (the four legendary skins).
4. **Known taps** (CSS): region intro "Betreten" (375,264); enemy choice easy "Wählen" (130,231);
   planning first arcana pack (320,292); pack "Alle aufdecken"/"Weiter" (375,314); debug toggle (720,14);
   main menu with debug: "Krypta-Lager" (375,190), "Grimoire" (375,226), "Einstellungen" (375,259), "+50 Seelenglut" (375,286);
   vault stations "Öffnen": chests (185,232), mirror (565,232).
   Layouts change: always look at a screenshot before trusting a coordinate.
5. Downscale or crop screenshots with PIL before viewing them; combine frames into a sheet for sequences.
