#!/usr/bin/env python3
"""Copies the shared blocks of assets/art/shaders/shader_common.glsl into every shader.

A shader marks where a block goes with a "// @common <name>" line and a "// @end" line; whatever
sits between them is replaced by the block from shader_common.glsl. Run from the project root:
    python3 tools/sync_shader_blocks.py          # rewrite the shaders
    python3 tools/sync_shader_blocks.py --check  # only list the shaders that are out of date
"""
import glob
import re
import sys

COMMON = "assets/art/shaders/shader_common.glsl"
SHADERS = "assets/art/shaders/*.gdshader"
BLOCK = re.compile(r"^// @common (\w+)\n(.*?)^// @end\n", re.S | re.M)


def blocks(text):
    return {m.group(1): m.group(2) for m in BLOCK.finditer(text)}


def main():
    check = "--check" in sys.argv
    common = blocks(open(COMMON).read())
    stale = []
    for path in sorted(glob.glob(SHADERS)):
        text = open(path).read()
        missing = [name for name in blocks(text) if name not in common]
        if missing:
            sys.exit("%s: no block named %s in %s" % (path, ", ".join(missing), COMMON))
        synced = BLOCK.sub(lambda m: "// @common %s\n%s// @end\n" % (m.group(1), common[m.group(1)]), text)
        if synced != text:
            stale.append(path)
            if not check:
                open(path, "w").write(synced)
    for path in stale:
        print(("out of date: " if check else "synced: ") + path)
    if check and stale:
        sys.exit(1)


if __name__ == "__main__":
    main()
