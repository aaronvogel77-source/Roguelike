---
name: pixel-art
description: Style rules and a review loop for Arcana's pixel art (figures, enemies, bosses, skins, fusions, backgrounds, icons). Use before drawing or changing any sprite, and to review art before showing it to the player.
---

# Arcana pixel art

The battle stage is a 300×130 pixel viewport scaled up with nearest filtering, so every
single pixel is visible. Art is either drawn with code (`figure_art.gd`, `creature_art.gd`)
or hand-made as pixel grids (`handmade_art.gd`), which gives the best detail.

## Style rules ("Prunk & Reliquie", dark with glowing effects)
1. **One light source, top left.** Highlights on top/left edges, shadows bottom/right, everywhere.
2. **Four-tone ramps with hue shift:** shadows go cooler (towards violet/blue), highlights warmer
   (towards yellow). Never just darker/lighter grey of the same hue. Ramps live in `FigureArt.RAMPS`.
3. **Silhouette first.** Each figure must be recognisable as a black shape: weapon, headgear and
   posture differ between figures. Check by imagining it filled with one colour.
4. **Readability at 1×:** faces get 2-3 pixels for the eye area, weapons at least 2 px wide at the grip,
   no single stray pixels inside flat areas (no noise), no 1-px checkerboards.
5. **Outline:** dark outline `PixelCanvas.OUTLINE` around every part (call `outline()`); inner lines use
   the darkest ramp tone, not black.
6. **Rank by material:** iron (page) → steel (knight) → silver (queen) → gold (king); legends and
   recipes gold, only legendary skins and recipes shimmer.
7. **Suit by gem and cloth:** coins green, wands red-orange, cups blue, swords violet.
8. **Name and ability show in the design:** e.g. Henker = black hood + axe, Midas = golden hand + crown.
9. **Faces are never covered:** weapons are drawn behind the head (`figure_actor.gd` draw order).
10. **Enemies look different from heroes:** creatures and corrupted bodies with sickly/bronze/blood ramps.
11. **Effects glow, bodies stay dark:** saturated bright colours are reserved for fire, magic, gold glints.

## Hand-made grids (`scripts/ui/stage/handmade_art.gd`)
- One grid per rig part (`head`, `torso`, `armF`, `armB`, `legF`, `legB`, `weapon`, `cape`) plus `pivot`.
- One character per pixel, `.` = transparent; each figure has its own palette of characters → colours.
- Pivots must match the procedural parts (head: neck, bottom centre; torso: hip, bottom centre;
  arms: shoulder; legs: hip; weapon: grip) so animations keep working.
- Facing right; the outline is added automatically.

## Review loop (do this before every art hand-off)
1. Render: `godot --headless -s tools/render_figures.gd -- <scratchpad>/figs.png`
   (creatures: `tools/render_creatures.gd`, fusions: `tools/render_fusions.gd`).
2. Look at it enlarged (crop + resize ×2 with nearest) next to the previous version.
3. Check every rule above; write down what fails, fix, render again (at least one pass).
4. Check in battle with the `browser-check` skill (`?arena=1`): readable at real size, against the
   background, during attacks and next to neighbours.
5. Show the player a before/after image and ask for feedback before converting more figures.
