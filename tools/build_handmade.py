#!/usr/bin/env python3
"""Builds scripts/ui/stage/handmade_art.gd from the pixel grids in art/*.txt.

File format (one asset per file, name = id):
    kind = figure | creature | icon
    [palette]
    k = 0c0910            # one character -> hex colour ("." is transparent)
    [head pivot=7,16]     # figure parts: head, torso, armF, armB, legF, legB, weapon, cape
    ....rows....
    [sprite feet=16,39 hand=10,-16]   # creatures: one sprite
    [icon]                            # icons: one grid
Shared colours come from art/_common.txt ([palette] only); a file may override them.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art"
OUT = ROOT / "scripts/ui/stage/handmade_art.gd"


def parse(path):
    data = {"kind": "figure", "palette": {}, "sections": []}
    current = None
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].rstrip()  # "#" starts a comment; grids never use it
        if not line.strip():
            continue
        if line.startswith("kind"):
            data["kind"] = line.split("=", 1)[1].strip()
        elif line.startswith("["):
            head = line.strip("[]").split()
            current = {"name": head[0], "args": dict(a.split("=") for a in head[1:]), "rows": []}
            if head[0] == "palette":
                current = "palette"
            else:
                data["sections"].append(current)
        elif current == "palette":
            key, value = [p.strip() for p in line.split("=")]
            assert len(key) == 1 and re.fullmatch(r"[0-9a-fA-F]{6}", value), (path, line)
            data["palette"][key] = value
        else:
            current["rows"].append(line.strip())
    return data


def gd_rows(rows, indent):
    return "\n".join(f'{indent}"{r}",' for r in rows)


def main():
    common = parse(ART / "_common.txt")["palette"] if (ART / "_common.txt").exists() else {}
    figures, creatures, icons = [], [], []
    for path in sorted(ART.glob("*.txt")):
        if path.name.startswith("_"):
            continue
        d = parse(path)
        palette = dict(common)
        palette.update(d["palette"])
        used = set("".join("".join(s["rows"]) for s in d["sections"])) - {"."}
        missing = used - set(palette)
        if missing:
            sys.exit(f"{path.name}: colours missing for {sorted(missing)}")
        pal = ", ".join(f'"{k}": "{palette[k]}"' for k in sorted(used))
        if d["kind"] == "figure":
            parts = []
            for s in d["sections"]:
                px, py = s["args"]["pivot"].split(",")
                parts.append(f'\t\t"{s["name"]}": {{"pivot": [{px}, {py}], "rows": [\n{gd_rows(s["rows"], chr(9) * 3)}\n\t\t]}},')
            figures.append(f'\t"{path.stem}": {{\n\t\t"palette": {{{pal}}},\n' + "\n".join(parts) + "\n\t},")
        elif d["kind"] == "creature":
            s = d["sections"][0]
            fx, fy = s["args"]["feet"].split(",")
            hx, hy = s["args"]["hand"].split(",")
            creatures.append(f'\t"{path.stem}": {{\n\t\t"palette": {{{pal}}},\n\t\t"feet": [{fx}, {fy}], "hand": [{hx}, {hy}],\n'
                             f'\t\t"rows": [\n{gd_rows(s["rows"], chr(9) * 3)}\n\t\t],\n\t}},')
        else:
            s = d["sections"][0]
            icons.append(f'\t"{path.stem}": {{\n\t\t"palette": {{{pal}}},\n\t\t"rows": [\n{gd_rows(s["rows"], chr(9) * 3)}\n\t\t],\n\t}},')
    template = (ROOT / "tools/handmade_art.gd.in").read_text()
    OUT.write_text(template.replace("%FIGURES%", "\n".join(figures)).replace("%CREATURES%", "\n".join(creatures))
                   .replace("%ICONS%", "\n".join(icons)))
    print(f"{len(figures)} figures, {len(creatures)} creatures, {len(icons)} icons -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
