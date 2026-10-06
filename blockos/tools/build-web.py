#!/usr/bin/env python3
"""Builds the web version of BlockOS (for phones, tablets and browsers) into blockos/build/web/.

It's the BlockOS desktop with every game listed in the catalog, plus the kit and 3D library.
index.html loses its <html>/<head>/<body> wrapper because the web host adds its own.
Run:  python3 blockos/tools/build-web.py
"""
import json
import pathlib
import re
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHELL = ROOT / "shell"
OUT = ROOT / "build" / "web"

ids = json.loads(subprocess.check_output(
    ["node", "-e", "global.window={};require(process.argv[1]);console.log(JSON.stringify(window.BLOCKOS_GAMES.map(g=>g.id)))",
     str(SHELL / "games" / "catalog.js")], text=True))

if OUT.exists():
    shutil.rmtree(OUT)
(OUT / "games").mkdir(parents=True)
for name in ("style.css", "app.js", "avatar.js", "config.js"):
    shutil.copy2(SHELL / name, OUT / name)
shutil.copytree(SHELL / "assets", OUT / "assets")
for name in ("catalog.js", "kit.js", "kit.css", "kit3d.js", "touch.js"):
    shutil.copy2(SHELL / "games" / name, OUT / "games" / name)
shutil.copytree(SHELL / "games" / "lib", OUT / "games" / "lib")
for game_id in ids:
    shutil.copytree(SHELL / "games" / game_id, OUT / "games" / game_id,
                    ignore=shutil.ignore_patterns("meta.json"))

html = (SHELL / "index.html").read_text(encoding="utf-8")
html = re.sub(r"(?is)<!doctype html>\s*|</?html[^>]*>\s*|</?head>\s*|</?body>\s*", "", html)
html = re.sub(r'(?i)<meta charset="utf-8">\s*|<meta name="viewport"[^>]*>\s*', "", html)
(OUT / "index.html").write_text(html, encoding="utf-8")

files = [p for p in OUT.rglob("*") if p.is_file()]
size = sum(p.stat().st_size for p in files)
print(f"build/web: {len(ids)} games, {len(files)} files, {size / 1e6:.1f} MB")
