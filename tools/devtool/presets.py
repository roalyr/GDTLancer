"""
The archetypes' character sheets (docs/PRESETS.md): each sheet names an evolved design (Base, a
genome id from evolution's life log) and hand tweaks (pilot genes, hull shares, parts). This prices
the tweaks with trait models fitted to the era's lives, and builds the archetypes from the sheets.

    python3 tools/devtool/presets.py price [write=yes] [refit=yes]   what each sheet's tweaks cost
    python3 tools/devtool/presets.py build                           the archetypes from the sheets

price: the era's lives (era.json's era, from its start time in the newest life log) give, for each
ship family, a ridge model of fitness, death and earnings on the traits a player feels (speed,
toughness, firepower, reach, cargo...) and the pilot genes, with a bootstrap by design for its
intervals and a held-out R2 for how much it explains. The models are kept in .dev/out/ until the log
grows (refit=yes fits them again). write=yes puts the prices on the sheets' Price lines.
build: each sheet's base genome (its last life in the log) with its tweaks, through
tools/build_presets.gd (a sheet whose result is the archetype as it is stays untouched), then
refit_archetypes and classify_presets. Needs numpy (price only) and Godot.
"""

import ast
import collections
import copy
import glob
import json
import math
import os
import re
import subprocess
import sys

if __package__ in (None, ""):  # Run as a file: tools/devtool/presets.py
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    __package__ = "devtool"

from . import constants  # noqa: E402
from .tasks import ROOT, environment, godot_script, out_file, user_dir  # noqa: E402

DOC = os.path.join(ROOT, "docs", "PRESETS.md")
PARTS_DIR = os.path.join(ROOT, "database", "presets", "parts")
ARCHETYPES_DIR = os.path.join(ROOT, "database", "presets", "archetypes")
SHEETS_JSON = "preset_sheets.json"  # In .dev/out/: what build hands tools/build_presets.gd
EFFECTS_JSON = "preset_effects.json"  # In .dev/out/: the fitted models, with the log they came from
FAMILIES = ["fighter", "raider", "prospector", "scavenger", "trader"]
TYPES = {1: "light", 2: "medium", 3: "heavy"}
TYPE_OF = {name: number for number, name in TYPES.items()}
TOOL_KINDS = ("laser", "cannon", "missile", "harpoon")
RETIRED = {"capacitor": "power_cell"}  # Old genomes' part kinds -> the catalogue's
UPKEEP = 0.4  # Evolution's upkeep: this share of a ship's cost an hour (Evolution.fitness_of)
PRIOR, PRIOR_SD = 2.0, 1.1  # PresetExporter.ranked's shrinkage
BOOTSTRAP = 200
GENES = ["engage", "caution", "disengage", "pursuit", "retreat_hull", "return_fire", "mercy", "range",
         "burn", "quiet", "teamwork", "haul", "prospect", "trade"]


# --- The game's numbers (Constants.gd, the part catalogue) ---

def game_constants(root=ROOT):
    """The Constants the stats need, as Python values."""
    entries = {e.name: e for e in constants.parse(read(os.path.join(root, constants.PATH)))}
    out = {}
    for name in ("LAW_HULL", "LAW_THRUST", "LAW_REGEN", "LAW_CAPACITY", "LAW_HOLD", "LAW_SHIP_REF_MASS", "LAW_SHIP_SIZE_MIN",
                 "LAW_SHIP_SIZE_MAX", "LAW_SHIP_SHARES", "LAW_SHIP_SHARE_MIN", "PRESET_WEIGHT_CLASSES", "EVO_BEHAVIOR_RANGES"):
        out[name] = literal(entries[name].value)
    return out


def read(path):
    with open(path) as handle:
        return handle.read()


def literal(text):
    """A GDScript constant's value as Python: its comments dropped, INF as infinity."""
    lines = [line.split("#", 1)[0] for line in text.splitlines()]
    return ast.literal_eval(re.sub(r"\bINF\b", "1e999", "\n".join(lines)).strip())


def parse_tres(path):
    """A .tres resource's top-level values: numbers, strings and flat {key: number} dictionaries."""
    out, block, name = {}, None, None
    for line in read(path).splitlines():
        if block is not None:
            if line == "}":
                out[name], block = block, None
            else:
                m = re.match(r'"(\w+)": ([-\d.e+]+)', line)
                if m:
                    block[m.group(1)] = float(m.group(2))
            continue
        m = re.match(r"^(\w+) = \{$", line)
        if m:
            name, block = m.group(1), {}
            continue
        m = re.match(r"^(\w+) = (.+)$", line)
        if m:
            value = m.group(2).strip('"')
            try:
                value = float(value)
            except ValueError:
                pass
            out[m.group(1)] = value
    return out


def catalogue(parts_dir=PARTS_DIR):
    parts = {}
    for path in glob.glob(os.path.join(parts_dir, "*.tres")):
        p = parse_tres(path)
        if "template_id" in p:
            parts[p["template_id"]] = p
    return parts


def part_id(part):
    """PartCatalog.id: preset_<kind>_<weight>, the harpoon alone."""
    kind = RETIRED.get(part["kind"], part["kind"])
    if kind == "harpoon":
        return "preset_harpoon"
    return "preset_%s_%s" % (kind, TYPES.get(int(part.get("type", 1)), "light"))


def law(spec, mass):
    k, a, e = spec
    return 0.0 if mass <= 0 else a * (mass / k) ** e


def stats(genome, consts, parts):
    """What a player feels of a genome: ShipLaws' hull from its genes, plus its parts."""
    g = genome["ship"]
    size = min(max(float(g.get("size", 1.0)), consts["LAW_SHIP_SIZE_MIN"]), consts["LAW_SHIP_SIZE_MAX"])
    base, least = consts["LAW_SHIP_SHARES"], consts["LAW_SHIP_SHARE_MIN"]
    shares = {k: max(float(g.get("shares", {}).get(k, base[k])), least[k]) for k in base}
    total = sum(shares.values())
    shares = {k: v / total for k, v in shares.items()}
    mass = consts["LAW_SHIP_REF_MASS"] * size
    s = {"hull": law(consts["LAW_HULL"], mass * shares["structure"]), "thrust": law(consts["LAW_THRUST"], mass * shares["engine"]),
         "regen": law(consts["LAW_REGEN"], mass * shares["reactor"]), "capacity": law(consts["LAW_CAPACITY"], mass * shares["capacitor"]),
         "cargo": law(consts["LAW_HOLD"], mass * shares["hold"]), "mass": mass, "sensor": 1.0, "afterburner": 0.0, "decoys": 0.0,
         "damper": 0.0, "lance": 0.0, "harpoon": 0.0, "dps_laser": 0.0, "dps_cannon": 0.0, "dps_missile": 0.0, "range": 0.0, "junk": 0.0}
    kinds = collections.Counter()
    for part in genome.get("tools", []) + genome.get("modules", []):
        p = parts.get(part_id(part)) if part else None
        if p is None:
            continue
        kind = RETIRED.get(part["kind"], part["kind"])
        kinds[kind] += 1
        s["mass"] += float(p.get("mass", 0.0))
        if kind in ("laser", "cannon", "missile"):
            s["dps_" + kind] += float(p.get("damage", 0.0)) / max(float(p.get("cycle_time", 1.0)), 0.01)
            s["range"] = max(s["range"], float(p.get("optimal_range", 0.0)))
        elif kind == "harpoon":
            s["harpoon"] = 1.0
        elif kind == "lance":
            s["lance"] += float(p.get("mass", 0.0))
        mods = p.get("stat_modifiers") if isinstance(p.get("stat_modifiers"), dict) else {}
        for key, field in (("hull", "hull"), ("thrust", "linear_thrust"), ("regen", "power_regen"), ("capacity", "power_capacity"),
                           ("sensor", "sensor_strength"), ("afterburner", "afterburner_thrust"), ("decoys", "decoy_charges"),
                           ("damper", "damper_mass")):
            s[key] += mods.get(field, 0.0)
    s["junk"] = float(kinds["magazine"] > 0 and kinds["cannon"] == 0) + float(kinds["rack"] > 0 and kinds["missile"] == 0)
    s["accel"] = s["thrust"] / s["mass"]
    s["boost"] = s["afterburner"] / s["mass"]
    s["dps"] = s["dps_laser"] + s["dps_cannon"] + s["dps_missile"]
    return s


def part_value(genome, parts):
    return sum(float(parts.get(part_id(p), {}).get("base_value", 0.0)) for p in genome.get("tools", []) + genome.get("modules", []) if p)


# The traits a player feels (logs where they span orders of magnitude), then the pilot genes.
TRAITS = collections.OrderedDict([
    ("speed", lambda d: math.log(max(d["s"]["accel"], 1e-9))),
    ("afterburner", lambda d: math.log1p(d["s"]["boost"])),
    ("toughness", lambda d: math.log(max(d["s"]["hull"], 1e-9))),
    ("firepower", lambda d: math.log1p(d["s"]["dps"])),
    ("laser share", lambda d: d["s"]["dps_laser"] / max(d["s"]["dps"], 1e-6)),
    ("missile share", lambda d: d["s"]["dps_missile"] / max(d["s"]["dps"], 1e-6)),
    ("reach", lambda d: math.log1p(d["s"]["range"])),
    ("power regen", lambda d: math.log(d["s"]["regen"] + 1e-3)),
    ("cargo", lambda d: math.log1p(d["s"]["cargo"])),
    ("sensor", lambda d: d["s"]["sensor"]),
    ("damper", lambda d: math.log1p(d["s"]["damper"])),
    ("decoys", lambda d: d["s"]["decoys"]),
    ("lance", lambda d: math.log1p(d["s"]["lance"])),
    ("harpoon", lambda d: d["s"]["harpoon"]),
    ("dead-weight bays", lambda d: d["s"]["junk"]),
    ("price", lambda d: math.log(max(d["cost"], 1.0))),
])
for _gene in GENES:
    TRAITS["gene " + _gene] = (lambda name: lambda d: float(d["genome"].get("behavior", {}).get(name, 0.0)))(_gene)
OUTCOMES = collections.OrderedDict([("fitness", lambda d: d["fitness"]), ("dies", lambda d: float(d["died"])), ("net", lambda d: d["net"])])


# --- The era's lives ---

def weight_of(niche, weights):
    size = float(niche.split("|")[0][1:])
    return next((name for name, top in weights if size <= top), weights[-1][0])


def family_of(niche):
    role = niche.split("|")[1]
    for kind in ("raider", "fighter"):
        if role.endswith(kind):
            return kind
    return role


def era_info(folder=None):
    """(era number, start in game seconds, the newest life log) of evolution's era.json."""
    folder = folder or os.path.join(user_dir(), "evolution")
    info = {}
    try:
        info = json.loads(read(os.path.join(folder, "era.json")))
    except (OSError, ValueError):
        pass
    logs = sorted(glob.glob(os.path.join(folder, "logs", "*.jsonl")), key=os.path.getmtime)
    return int(info.get("era", 0)), float(info.get("game_time", 0.0)), (logs[-1] if logs else "")


def read_lives(log, since, consts, parts):
    """The log's lives from game time `since` on (drifters left out), each with its family, weight
    class, stats and net earnings per cost; and every genome id's last genome (any era)."""
    weights = [(w[0], w[1]) for w in consts["PRESET_WEIGHT_CLASSES"]]
    lives, genomes = [], {}
    for line in read(log).splitlines():
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if "genome_id" not in d or "niche" not in d:
            continue
        genomes[d["genome_id"]] = d
        if d.get("t", 0.0) < since or "|drifter|" in d["niche"]:
            continue
        d["fam"], d["w"] = family_of(d["niche"]), weight_of(d["niche"], weights)
        d["s"] = stats(d["genome"], consts, parts)
        d["net"] = (d.get("earned", 0) + d.get("bounty", 0) - d.get("spent", 0) - UPKEEP * d["cost"] * d["age"] / 3600.0) / max(d["cost"], 1)
        lives.append(d)
    return lives, genomes


# --- Models ---

def design_matrix(np, lives, names, weights):
    """Traits z-scored within each weight class (a heavy's speed against heavies), plus weight class,
    faction and zone dummies and pilot skill as controls."""
    X = np.array([[TRAITS[n](d) for n in names] for d in lives], dtype=float)
    for w in weights:
        rows = np.array([d["w"] == w for d in lives])
        if rows.sum() > 1:
            mu, sd = X[rows].mean(0), X[rows].std(0)
            sd[sd < 1e-9] = 1.0
            X[rows] = (X[rows] - mu) / sd
    controls = []
    for key, values in (("w", weights[1:]), ("faction", sorted({d["faction"] for d in lives})[1:]),
                        ("zone", sorted({d["zone"] for d in lives})[1:])):
        for v in values:
            controls.append([float(d[key] == v) for d in lives])
    controls.append([d.get("skill", 0.5) for d in lives])
    C = np.array(controls, dtype=float).T
    return np.hstack([np.ones((len(lives), 1)), X, C])


def ridge(np, X, y, lam=1.0):
    P = np.eye(X.shape[1]) * lam
    P[0, 0] = 0.0
    return np.linalg.solve(X.T @ X + P, X.T @ y)


def fit(lives, weights, seed=0, reps=BOOTSTRAP):
    """Family -> outcome -> {"r2": held-out, "effects": trait -> [per 1 SD, 5%, 95%]}; and family ->
    weight -> trait -> its spread (the SD the effects are per)."""
    import numpy as np
    rng = np.random.default_rng(seed)
    models, spreads = {}, {}
    for fam in FAMILIES:
        ls = [d for d in lives if d["fam"] == fam]
        if len(ls) < 30:
            continue
        names = [n for n in TRAITS if np.std([TRAITS[n](d) for d in ls]) > 1e-9]
        X = design_matrix(np, ls, names, weights)
        groups = collections.defaultdict(list)
        for i, d in enumerate(ls):
            groups[d["genome_id"]].append(i)
        gids = list(groups)
        models[fam] = {}
        for outcome, f in OUTCOMES.items():
            y = np.array([f(d) for d in ls])
            beta = ridge(np, X, y)
            boots = []
            for _ in range(reps):
                idx = [i for g in rng.choice(len(gids), len(gids)) for i in groups[gids[g]]]
                boots.append(ridge(np, X[idx], y[idx]))
            lo, hi = np.percentile(np.array(boots), [5, 95], axis=0)
            order = rng.permutation(len(gids))
            sse = sst = 0.0
            for k in range(5):  # Held out by design: five folds of genomes
                test_g = set(order[k::5].tolist())
                test = [i for j, g in enumerate(gids) if j in test_g for i in groups[g]]
                train = [i for j, g in enumerate(gids) if j not in test_g for i in groups[g]]
                b = ridge(np, X[train], y[train])
                sse += float(((y[test] - X[test] @ b) ** 2).sum())
                sst += float(((y[test] - y[train].mean()) ** 2).sum())
            models[fam][outcome] = {"r2": 1.0 - sse / max(sst, 1e-9),
                                    "effects": {n: [float(beta[1 + i]), float(lo[1 + i]), float(hi[1 + i])] for i, n in enumerate(names)}}
        spreads[fam] = {}
        for w in weights:
            rows = [d for d in ls if d["w"] == w]
            if len(rows) > 2:
                spreads[fam][w] = {n: float(np.std([TRAITS[n](d) for d in rows])) for n in TRAITS}
    return models, spreads


def models_for(log, since, lives, weights, refit=False, say=print):
    """The fitted models, from .dev/out/ while the log has not grown since, else fitted anew."""
    path = out_file(EFFECTS_JSON)
    key = {"log": log, "size": os.path.getsize(log), "since": since}
    if not refit and os.path.exists(path):
        try:
            kept = json.loads(read(path))
            if kept.get("key") == key:
                return kept["models"], kept["spreads"]
        except (OSError, ValueError, KeyError):
            pass
    say("Fitting the trait models on %d lives (a minute or so)..." % len(lives))
    models, spreads = fit(lives, weights)
    with open(path, "w") as handle:
        json.dump({"key": key, "models": models, "spreads": spreads}, handle, indent=1)
    return models, spreads


def standings(lives):
    """Genome id -> (shrunk mean against its faction and family, its standard error, lives) for
    designs with 5+ lives (PresetExporter.ranked's numbers), and archetype -> those designs."""
    by_g = collections.defaultdict(list)
    fam_sum, fam_n = collections.Counter(), collections.Counter()
    for d in lives:
        by_g[d["genome_id"]].append(d)
        fam_sum[(d["faction"], d["fam"])] += d["fitness"]
        fam_n[(d["faction"], d["fam"])] += 1
    out, by_arch = {}, collections.defaultdict(list)
    for gid, ls in by_g.items():
        n = len(ls)
        if n < 5:
            continue
        f = [d["fitness"] for d in ls]
        spread = max(sum(x * x for x in f) - sum(f) ** 2 / n, 0.0)
        var = (spread + PRIOR * PRIOR_SD ** 2) / (max(n - 1, 0) + PRIOR)
        se = math.sqrt(var / (n + PRIOR))
        key = (ls[0]["faction"], ls[0]["fam"])
        mean = sum(f) / (n + PRIOR) - fam_sum[key] / fam_n[key]
        out[gid] = (mean, se, n)
        by_arch["%s_%s" % (ls[-1]["niche"].split("|")[1], ls[-1]["w"])].append(gid)
    return out, by_arch


# --- Sheets ---

def parse(text):
    """The sheets: [{"arch", "name", "line" (its italic one-liner), "base", "tweaks"}] in the doc's order."""
    sheets = []
    for block in re.split(r"^### ", text, flags=re.M)[1:]:
        head = block.splitlines()[0]
        arch, _, name = head.partition(" · ")
        base = re.search(r"\*\*Base:\*\* `(\w+)`", block)
        line = re.search(r"^\*([^*].*)\*$", block, flags=re.M)
        tweaks = re.search(r"\*\*Tweaks:\*\*(.*)", block)
        sheets.append({"arch": arch.strip(), "name": name.strip(), "line": line.group(1).strip() if line else "",
                       "base": base.group(1) if base else None,
                       "tweaks": re.findall(r"`([^`]+)`", tweaks.group(1)) if tweaks else []})
    return sheets


def characters(path=DOC):
    """Archetype -> (its sheet's name, its one-liner): ("Smuggler", "A medium trader that..."); {} without the doc."""
    try:
        return {s["arch"]: (s["name"], s["line"]) for s in parse(read(path)) if s["name"]}
    except OSError:
        return {}


def apply(genome, tweaks, ranges=None):
    """The genome with the tweaks, and what is wrong with them: `gene: from -> to`,
    `share.<name>: from -> to`, `+<kind>_<weight>` / `-<kind>_<weight>` (`+harpoon`). A tweak already
    applied (the value is its `to`) is no problem: a built archetype's genome takes its sheet again."""
    g = copy.deepcopy(genome)
    problems = []
    for item in tweaks:
        m = re.match(r"^(share\.)?(\w+): *([-\d.]+) *-> *([-\d.]+)$", item)
        if m:
            is_share, name, old, new = m.group(1), m.group(2), float(m.group(3)), float(m.group(4))
            where = g["ship"].setdefault("shares", {}) if is_share else g.setdefault("behavior", {})
            have = float(where.get(name, 0.0))
            if abs(have - old) > 0.011 and abs(have - new) > 0.011:
                problems.append("%s is %.2f, not %.2f" % (name, have, old))
            if not is_share and ranges and name in ranges and not ranges[name][0] <= new <= ranges[name][1]:
                problems.append("%s %.2f is outside %s..%s" % (name, new, ranges[name][0], ranges[name][1]))
            where[name] = new
            continue
        m = re.match(r"^([+-])(\w+)_(light|medium|heavy)$", item) or re.match(r"^([+-])(harpoon)()$", item)
        if m:
            sign, kind, weight = m.groups()
            part = {"kind": kind, "type": TYPE_OF.get(weight, 0), "genes": {}}
            group = "tools" if kind in TOOL_KINDS else "modules"
            if sign == "+":
                g[group].append(part)
            else:
                for i, p in enumerate(g[group]):
                    if p and p["kind"] == kind and int(p.get("type", 0)) == part["type"]:
                        g[group][i] = {}
                        break
                else:
                    problems.append("no %s to remove" % item[1:])
            continue
        problems.append("can't read `%s`" % item)
    if "ship" in g:
        total = sum(float(v) for v in g["ship"].get("shares", {}).values())
        if g["ship"].get("shares") and abs(total - 1.0) > 0.005:
            problems.append("hull shares add up to %.3f, not 1" % total)
    return g, problems


class Era:
    """The era's lives, the catalogue and the game's laws: what pricing and building read."""

    def __init__(self, folder=None, say=print):
        self.consts = game_constants()
        self.parts = catalogue()
        self.weights = [w[0] for w in self.consts["PRESET_WEIGHT_CLASSES"]]
        self.number, self.since, self.log = era_info(folder)
        if not self.log:
            raise SystemExit("No evolution life log in %s" % (folder or os.path.join(user_dir(), "evolution", "logs")))
        self.lives, self.genomes = read_lives(self.log, self.since, self.consts, self.parts)
        self.ranges = {k: tuple(v[:2]) for k, v in self.consts["EVO_BEHAVIOR_RANGES"].items()}
        say("Era %d: %d lives since t=%.0f s (%s)" % (self.number, len(self.lives), self.since, os.path.basename(self.log)))

    def base(self, genome_id):
        return self.genomes.get(genome_id)


def price(sheet, era, models, spreads, standing, by_arch):
    """A sheet's line for its Price field, and its problems."""
    d = era.base(sheet["base"]) if sheet["base"] else None
    if d is None:
        return "", ["base %s is not in the log" % sheet["base"]]
    genome, problems = apply(d["genome"], sheet["tweaks"], era.ranges)
    new = dict(d)
    new["genome"] = genome
    new["s"] = stats(genome, era.consts, era.parts)
    new["cost"] = d["cost"] - part_value(d["genome"], era.parts) + part_value(genome, era.parts)
    old = dict(d)
    old["s"] = stats(d["genome"], era.consts, era.parts)
    fam, w = family_of(d["niche"]), weight_of(d["niche"], [(x[0], x[1]) for x in era.consts["PRESET_WEIGHT_CLASSES"]])
    if fam not in models:
        return "no model for %ss (too few lives)" % fam, problems
    out = {}
    for outcome in OUTCOMES:
        total = var = 0.0
        for n, (b, lo, hi) in models[fam][outcome]["effects"].items():
            s = spreads.get(fam, {}).get(w, {}).get(n, 0.0)
            if s < 1e-9:
                continue
            dz = (TRAITS[n](new) - TRAITS[n](old)) / s
            total += b * dz
            var += ((hi - lo) / 2 / 1.645 * dz) ** 2
        out[outcome] = (total, math.sqrt(var))
    f, fs = out["fitness"]
    if models[fam]["fitness"]["r2"] < 0.05:
        text = "tweaks: no reliable effect (design hardly moves this role's fitness)"
    elif abs(f) < 0.02 and fs < 0.03:
        text = "tweaks: about free"
    else:
        text = "tweaks %+.2f fitness (±%.2f), death chance %+.0f pts, earnings %+.2f of cost" % (
            f, 1.645 * fs, 100 * out["dies"][0], out["net"][0])
    if sheet["base"] in standing:
        mean, se, n = standing[sheet["base"]]
        rivals = [standing[g] for g in by_arch.get(sheet["arch"], []) if g in standing]
        best = max(rivals, key=lambda r: r[0] - r[1]) if rivals else (mean, se, n)
        gap = mean - best[0]
        text += "; base ties with its archetype's best" if abs(gap) <= math.sqrt(se ** 2 + best[1] ** 2) else \
            "; base %.2f below its archetype's best" % -gap
        text += " (%d lives)" % n
    changes = []
    for key, label in (("accel", "speed"), ("hull", "hull"), ("cargo", "hold")):
        a, b = old["s"][key], new["s"][key]
        if abs(b - a) > 0.01 * max(a, 1e-6):
            changes.append("%s %+.0f%%" % (label, 100.0 * (b / max(a, 1e-9) - 1)))
    if changes:
        text += "; " + ", ".join(changes)
    return text, problems


def write_prices(text, prices):
    """The doc with each sheet's Price line set (prices: archetype -> line)."""
    blocks = re.split(r"(^### .*$)", text, flags=re.M)
    for i in range(1, len(blocks), 2):
        arch = blocks[i][4:].split(" · ")[0].strip()
        if arch in prices:
            blocks[i + 1] = re.sub(r"^- \*\*Price:\*\*.*$", lambda _m: "- **Price:** " + prices[arch], blocks[i + 1], count=1, flags=re.M)
    return "".join(blocks)


def archetype_names():
    return sorted(os.path.basename(p)[len("agent_archetype_"):-len(".tres")]
                  for p in glob.glob(os.path.join(ARCHETYPES_DIR, "agent_archetype_*.tres")))


# --- Actions ---

def run_price(write=False, refit=False, say=print):
    era = Era(say=say)
    models, spreads = models_for(era.log, era.since, era.lives, era.weights, refit, say)
    for fam in FAMILIES:
        if fam in models:
            say("  %-10s explains %3.0f%% of fitness" % (fam, 100 * max(models[fam]["fitness"]["r2"], 0.0)))
    standing, by_arch = standings(era.lives)
    text = read(DOC)
    prices, bad = {}, 0
    for sheet in parse(text):
        line, problems = price(sheet, era, models, spreads, standing, by_arch)
        if problems:
            bad += 1
            line += " (check: %s)" % "; ".join(problems)
        prices[sheet["arch"]] = line
        say("%-22s %-16s %s" % (sheet["arch"], sheet["name"], line))
    if write:
        with open(DOC, "w") as handle:
            handle.write(write_prices(text, prices))
        say("Prices written to %s" % os.path.relpath(DOC, ROOT))
    return 1 if bad else 0


def run_build(say=print, run=subprocess.call):
    era = Era(say=say)
    known = set(archetype_names())
    standing, _ = standings(era.lives)
    sheets, bad = {}, 0
    for sheet in parse(read(DOC)):
        d = era.base(sheet["base"]) if sheet["base"] else None
        problems = [] if sheet["arch"] in known else ["no archetype %s" % sheet["arch"]]
        if d is None:
            problems.append("base %s is not in the log" % sheet["base"])
        else:
            genome, more = apply(d["genome"], sheet["tweaks"], era.ranges)
            problems += more
        if problems:
            say("%-22s left as it is: %s" % (sheet["arch"], "; ".join(problems)))
            bad += 1
            continue
        mean, se, n = standing.get(sheet["base"], (float(d.get("fitness", 0.0)), 0.0, 1))
        sheets[sheet["arch"]] = {"genome_id": sheet["base"], "genome": genome, "lives": n, "fitness": mean - se, "era": era.number,
                                 "name": sheet["name"]}
    path = out_file(SHEETS_JSON)
    with open(path, "w") as handle:
        json.dump(sheets, handle, indent=1)
    env = environment()
    for script, args in (("tools/build_presets.gd", ["--", "--json=" + path]), ("tools/refit_archetypes.gd", []),
                         ("tools/classify_presets.gd", [])):
        say("Running %s..." % script)
        code = run(godot_script(script, *args), cwd=ROOT, env=env)
        if code != 0:
            say("%s failed (exit %d); the steps after it did not run" % (script, code))
            return code
    return 1 if bad else 0


def main(argv):
    action = argv[0] if argv else ""
    options = dict(arg.split("=", 1) for arg in argv[1:] if "=" in arg)
    yes = lambda key: str(options.get(key, "no")).lower() in ("yes", "y", "true", "1")
    if action == "price":
        return run_price(write=yes("write"), refit=yes("refit"))
    if action == "build":
        return run_build()
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
