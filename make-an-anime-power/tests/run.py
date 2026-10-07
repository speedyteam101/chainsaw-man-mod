"""Runs the shared-module tests in the standalone Luau VM.

The shared modules use Roblox's `script.Parent.X` requires and a couple of
Roblox types (Color3, Vector3), so this bundles them into one file with small
stand-ins for those, then runs it with the `luau` command-line tool.

Usage: python3 tests/run.py [path/to/luau]
"""

import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"
MODULES = ["Config", "Elements", "AbilityTypes", "Templates", "PowerValidator"]

PRELUDE = """
Color3 = {}
function Color3.fromRGB(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end
function Color3.new(r, g, b) return { R = r, G = g, B = b } end
Vector3 = {}
function Vector3.new(x, y, z) return { X = x, Y = y, Z = z } end

local loaders, loaded = {}, {}
local function require(ref)
\tlocal name = ref.__module
\tif loaded[name] == nil then
\t\tloaded[name] = loaders[name]()
\tend
\treturn loaded[name]
end
local script = { Parent = setmetatable({}, { __index = function(_, key) return { __module = key } end }) }
"""


def main():
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
    parts = [PRELUDE]
    for name in MODULES:
        source = (SHARED / f"{name}.lua").read_text()
        parts.append(f"loaders[{name!r}] = function()\n{source}\nend\n")
    parts.append((ROOT / "tests" / "shared.spec.lua").read_text())
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as bundle:
        bundle.write("\n".join(parts))
    sys.exit(subprocess.call([luau, bundle.name]))


if __name__ == "__main__":
    main()
