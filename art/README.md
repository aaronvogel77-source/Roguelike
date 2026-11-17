# Hand-made pixel art sources

One file per figure/creature/icon: `<id>.txt` with sections

    [palette]
    k = 0c0910
    [head pivot=7,16]
    ....rows....

`tools/build_handmade.py` turns them into `scripts/ui/stage/handmade_art.gd`.
Shared skin/hair/leather colours come from `_common.txt`. Rules: `.claude/skills/pixel-art/SKILL.md`.
