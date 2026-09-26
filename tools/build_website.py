"""Assemble the Speed's Mods website into one self-contained folder.

Layout of the output:
    index.html, chainsaw-man.html, doors.html, robot-jack.html, shinobi.html
    site.css, speeds.css, img/...      (from docs/speeds-mods and docs/assets)
    chainsaw/...                       (the full Chainsaw Man wiki from docs/)

Usage: python3 tools/build_website.py OUTPUT_DIR
"""

import re
import shutil
import sys
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"
SPEEDS = DOCS / "speeds-mods"
CHAINSAW_PAGES = ["index.html", "chainsaw-man.html", "hybrids.html", "devils.html", "items.html", "install.html"]


def main(out: Path) -> None:
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    # Speed's Mods pages at the top level.
    shutil.copy(DOCS / "assets" / "site.css", out / "site.css")
    shutil.copy(SPEEDS / "speeds.css", out / "speeds.css")
    shutil.copytree(SPEEDS / "img", out / "img")
    for page in SPEEDS.glob("*.html"):
        html = page.read_text()
        html = html.replace('href="../assets/site.css"', 'href="site.css"')
        # Links into the Chainsaw Man wiki: ../foo.html -> chainsaw/foo.html
        html = re.sub(r'href="\.\./([\w-]+\.html)', r'href="chainsaw/\1', html)
        (out / page.name).write_text(html)

    # The full Chainsaw Man wiki under chainsaw/.
    wiki = out / "chainsaw"
    wiki.mkdir()
    shutil.copytree(DOCS / "assets", wiki / "assets")
    shutil.copytree(DOCS / "img", wiki / "img")
    for name in CHAINSAW_PAGES:
        html = (DOCS / name).read_text()
        html = html.replace('href="speeds-mods/index.html"', 'href="../index.html"')
        (wiki / name).write_text(html)

    # Leftover parent-relative links would point outside the site.
    for page in out.rglob("*.html"):
        rel = page.relative_to(out)
        for target in re.findall(r'(?:href|src|data-src)="([^"#:]+)"', page.read_text()):
            if not (page.parent / target).resolve().is_relative_to(out.resolve()):
                sys.exit(f"{rel}: link {target} leaves the site")
            if not (page.parent / target).exists():
                sys.exit(f"{rel}: link {target} is missing")

    print(f"Built {sum(1 for p in out.rglob('*') if p.is_file())} files into {out}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]).resolve())
