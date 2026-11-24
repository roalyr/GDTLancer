# Getting started

This guide is for anyone new to working on GDTLancer. It takes about half an hour: install what the
tools need, run them once, and make two small changes with a guide at each step. None of it needs code.

The first of the guides the [README](../README.md#documentation) lists. Next: [CONTENT.md](CONTENT.md), how the game's content fits together and how to change each kind.

**Contents**
- [Requirements](#requirements): what to install, with links
- [First run](#first-run)
- [Finding your way round the tool](#finding-your-way-round-the-tool)
- [Your first change: a word the player reads](#your-first-change-a-word-the-player-reads)
- [A change other files follow: tuning a part](#a-change-other-files-follow-tuning-a-part)
- [What next](#what-next)

## Requirements

You need **Linux**: the tools are only made and tested there. Install these:

| What | Version | Download | Needed for |
|---|---|---|---|
| Godot | 3.6.2, the standard Linux x11 build | [3.6.2 page](https://godotengine.org/download/archive/3.6.2-stable/) ([x11 64-bit zip](https://github.com/godotengine/godot/releases/download/3.6.2-stable/Godot_v3.6.2-stable_x11.64.zip)) | everything |
| Python | 3.9 or newer, with `venv` and `pip` | your distribution's packages (Debian and Ubuntu: `python3` and `python3-venv`), or [python.org](https://www.python.org/downloads/) | the development tool |
| git | any recent | your distribution's packages, or [git-scm.com](https://git-scm.com/downloads) | getting the project, committing |
| Blender | 3.6 LTS (3.6.22 is tested) | [Blender 3.6 releases](https://download.blender.org/release/Blender3.6/) (`blender-3.6.22-linux-x64.tar.xz`) | making models only |

Godot 4 cannot open the project, and Godot's server or headless build crashes on its scenes. Use the x11 build, even for the command line.

**Only to build the Android APK:**
- Godot's export templates for 3.6.2: [Godot_v3.6.2-stable_export_templates.tpz](https://github.com/godotengine/godot/releases/download/3.6.2-stable/Godot_v3.6.2-stable_export_templates.tpz) (install them from the Godot editor: Editor, Manage Export Templates).
- OpenJDK 17 ([Temurin 17](https://adoptium.net/temurin/releases/?version=17)) and the Android SDK ([command-line tools](https://developer.android.com/studio#command-tools)) with the parts Godot's guide lists: [Exporting for Android (Godot 3.6)](https://docs.godotengine.org/en/3.6/tutorials/export/exporting_for_android.html). Set their paths in the Godot editor (Editor Settings, Export, Android).

**Already included; nothing to install:**
- **GUT 7.4.3**, the test framework, in `addons/gut/` (from [GUT v7.4.3](https://github.com/bitwes/Gut/releases/tag/v7.4.3)). GUT 7 is the line made for Godot 3: keep this one, since GUT 9 needs Godot 4.
- **Textual 8.2.8**, the development tool's one Python package (`tools/devtool/requirements.txt`). The tool installs it into its own `.dev/venv` on its first run.
- **GDFormat**, an optional Godot editor plugin in `addons/gdformat/`: it formats GDScript with `gdformat` from [godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit), which you install yourself if you want it (`pip install "gdtoolkit==3.*"`; version 3 is for Godot 3). Nothing else needs it.

**Tell the tools where the programs are,** if they are not on your PATH as `godot` and `blender`:
- `GODOT=/path/to/godot`: the Godot 3.6 binary.
- `BLENDER=/path/to/blender`: Blender 3.6. A link at `tools/blender` also works (git ignores it).
- `GDTLANCER_APK=/path/to/file.apk`: where the debug APK goes (only if you build for Android).

Set them in your shell profile (for example `export GODOT=~/apps/godot-3.6.2/godot` in `~/.profile`).

## First run

1. Clone the repository.
2. Run `tools/dev.py`. The first run:
   - installs its one package (Textual) into `.dev/venv`, which only this tool uses;
   - imports the project: Godot converts the art and models into `.import/`, which git does not keep. This takes under a minute.

   (`tools/devtool/setup.sh` does the first step on its own: to set up ahead, or `--fresh` to repair the venv. Opening the project once in the Godot editor also imports it.)
3. The tool opens on the **Overview** tab, which checks everything. If Godot or Blender is missing or is the wrong version, or the project was never imported, a red **Setup** line says what to do.
4. Play the game: Tools tab (`0`), then **Play**. Or run `godot` in the project folder.

## Finding your way round the tool

The tool is a menu in the terminal. Everything you edit, you edit here: it checks every save against the game's rules, and it can undo.

**Keys that work on every tab:**
- `1` to `9`, `0` and `-` switch tabs. Tab and shift+Tab move between boxes.
- Enter opens or runs what is picked.
- `ctrl+s` saves. `ctrl+u` undoes the last save (press it again to undo the one before).
- `?` shows the keys. Plain letters are each tab's own actions, and the footer lists them.
- `q` quits.

**The tabs**, one line each (their keys are in [CONTENT.md](CONTENT.md#the-development-tools-tabs)):

| Key | Tab | What it is for |
|---|---|---|
| `1` | Overview | Is everything right? Every problem, and what is out of date |
| `2` | Models | Ship, station and rock models |
| `3` | Archetypes | The ship designs the game flies |
| `4` | Factions | Who is at war, and what each faction flies |
| `5` | World | Sectors: their bodies, stations and beacons, on a map |
| `6` | Parts | Weapons, modules, cargo and starting kits |
| `7` | Look | Shaders, paints and music |
| `8` | Data | Every data file, in a form |
| `9` | Constants | The game's tuning values |
| `0` | Tools | Everything else: play, tests, commit |
| `-` | Strings | Every word the player reads, in each language |

You don't need most of these at first. The two changes below use only Strings, Parts, Data, the Overview and Tools.

## Your first change: a word the player reads

1. Press `-` for Strings. Type `menu.button` in the box at the top: the list keeps only the main menu's buttons.
2. Pick `menu.button.new`. Its English and Ukrainian texts show on the right. Change the English from `New` to `Begin`, then press `ctrl+s`. The tool saves it and says whether anything is wrong (a language left empty, say).
3. Tools (`0`), **Play**. The game opens on its main menu, and the first button now reads Begin.
4. Quit the game. Back in the tool, `ctrl+u` puts the word back.

What this shows: every word the player reads is a key with a text in each language; a save is checked at once; and `ctrl+u` takes it back.

## A change other files follow: tuning a part

Some data you edit, and some is **derived**: tools work it out from other data. A part's stats (its damage, range, price) are made from its **law genes**, and every ship design that fits the part carries a copy of those genes. So one edit can leave other files out of date. The Overview finds them and gives you the key that brings them up to date.

1. Parts (`6`), `w` for weapons. Pick **Laser Mk I-light** and press Enter. It opens in Data: a form built from the part's script, with a note on each field.
2. Find `law_genes` and raise `energy` a little (from 2.511 to 3, say). Press `ctrl+s`.
3. Overview (`1`): it says the laser's stats are not what its law genes give. Press `a`: the tool rebuilds them from the genes.
4. It then says some archetypes are out of date: every design that fits a light laser. Press `f` to build them again. If it says `CATALOG.md` is out of date, press `c`. Then everything is green.
5. Tools (`0`), `g`: the review lists every file the change touched (the laser and the designs rebuilt from it). This is where you would write a message and commit.

To put it back, do it again with the old value: `energy` back to 2.511, save, then `a` and `f` on the Overview. The review (`g`) then shows nothing left over.

What this shows: edit the source (the genes), never what is made from it (the stats); the Overview says what follows from an edit; and the review shows a change whole before it is committed.

## What next

- **Making content:** [CONTENT.md](CONTENT.md). Read its first section, [How the content fits together](CONTENT.md#how-the-content-fits-together). Then use its [step-by-step tasks](CONTENT.md#common-tasks), and look up each kind of content in its reference sections when you need them.
- **Words you don't know:** the [glossary](CONTENT.md#glossary).
- **Running tests, releases or evolution:** [MAINTAINING.md](MAINTAINING.md), once you know your way round.
