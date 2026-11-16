"""Renames the exported game pack to a versioned file name so browsers never
load a stale index.pck from cache after a new deploy.

Usage: python3 tools/ci/cache_bust.py build/web <version-tag>
"""
import json
import pathlib
import re
import sys

web_dir = pathlib.Path(sys.argv[1])
tag = re.sub(r"[^A-Za-z0-9]", "", sys.argv[2])[:12]
html_path = web_dir / "index.html"
html = html_path.read_text(encoding="utf-8")

match = re.search(r"GODOT_CONFIG = (\{.*?\});", html)
config = json.loads(match.group(1))
new_pack = f"index-{tag}.pck"
(web_dir / "index.pck").rename(web_dir / new_pack)
config["mainPack"] = new_pack
sizes = config.get("fileSizes", {})
if "index.pck" in sizes:
    sizes[new_pack] = sizes.pop("index.pck")
html = html.replace(match.group(1), json.dumps(config, separators=(",", ":")))
html_path.write_text(html, encoding="utf-8")
print("pack renamed to", new_pack)
