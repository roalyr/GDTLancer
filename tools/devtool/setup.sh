#!/bin/sh
# Prepares the development tool's own Python environment, .dev/venv (the one tools/dev.py runs its
# menu in): makes the venv, installs tools/devtool/requirements.txt (Textual) and checks it imports.
# tools/dev.py does the same on its first run; use this to set up ahead (before going offline) or to
# repair a broken venv.
#
#     tools/devtool/setup.sh          make or update .dev/venv
#     tools/devtool/setup.sh --fresh  remove .dev/venv first and make it anew
#
# PYTHON picks the interpreter (default python3, 3.9 or newer). Linux only, as the tool.

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
VENV="$ROOT/.dev/venv"
REQUIREMENTS="$HERE/requirements.txt"
PYTHON=${PYTHON:-python3}

if ! command -v "$PYTHON" >/dev/null 2>&1; then
	echo "No $PYTHON. Install Python 3 (Debian/Ubuntu: sudo apt install python3 python3-venv), or set PYTHON." >&2
	exit 1
fi
if ! "$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
	echo "$PYTHON is $("$PYTHON" --version 2>&1); the tool needs 3.9 or newer (set PYTHON)." >&2
	exit 1
fi

if [ "${1:-}" = "--fresh" ]; then
	echo "Removing $VENV"
	rm -rf "$VENV"
fi

mkdir -p "$ROOT/.dev"
if [ ! -x "$VENV/bin/python" ]; then
	echo "Making $VENV with $("$PYTHON" --version 2>&1)"
	if ! "$PYTHON" -m venv "$VENV"; then
		rm -rf "$VENV"
		echo "Could not make the venv. Debian/Ubuntu: sudo apt install python3-venv, then run this again." >&2
		exit 1
	fi
fi

echo "Installing $(tr '\n' ' ' < "$REQUIREMENTS")"
if ! "$VENV/bin/python" -m pip install -q --upgrade pip || ! "$VENV/bin/python" -m pip install -q -r "$REQUIREMENTS"; then
	echo "pip failed (no network?). Fix that and run this again; --fresh starts the venv over." >&2
	exit 1
fi

"$VENV/bin/python" -c 'import textual; print("Textual", textual.__version__, "ready in .dev/venv")'
echo "Run the tool: tools/dev.py (tests: tools/dev.py selftest)"
