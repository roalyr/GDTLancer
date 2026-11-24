"""
What each archetype's character costs: its hand tweaks (database/characters/, CharacterSheet: genes,
hull shares, parts over an evolved base genome) priced by trait models fitted to the era's lives.

    python3 tools/devtool/characters.py price [refit=yes]

The era's lives (era.json's era, from its start time in the newest life log) give, for each ship
family, a ridge model of fitness, death and earnings on the traits a player feels (speed, toughness,
firepower, reach, cargo...) and the pilot genes, with a bootstrap by design for its intervals and a
held-out R2 for how much it explains. The models are kept in .dev/out/ until the log grows (refit=yes
fits them again). Each character is read through Godot (the bridge); its tweaks are priced against its
base's last life in the log, and how its base ranks against the archetype's other designs. The prices
go to .dev/out/character_prices.json, which the Archetypes tab shows. Needs numpy.
"""

import ast
import collections
import copy
import glob
import json
import math
import os
import re
import sys

if __package__ in (None, ""):  # Run as a file: tools/devtool/characters.py
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    __package__ = "devtool"

from . import constants  # noqa: E402
from .tasks import ROOT, out_file, user_dir  # noqa: E402

PARTS_DIR = os.path.join(ROOT, "database", "presets", "parts")
ARCHETYPES_DIR = os.path.join(ROOT, "database", "presets", "archetypes")
EFFECTS_JSON = "character_models.json"  # In .dev/out/: the fitted models, with the log they came from
PRICES_JSON = "character_prices.json"  # In .dev/out/: archetype -> its price line (the Archetypes tab)
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


# --- Characters ---

def part_of(template_id):
    """CharacterSheet.part_of: a catalogue id as a genome part ({} if it is none)."""
    if template_id == "preset_harpoon":
        return {"kind": "harpoon", "type": 0, "genes": {}}
    m = re.match(r"^preset_(\w+)_(light|medium|heavy)$", template_id)
    return {"kind": m.group(1), "type": TYPE_OF[m.group(2)], "genes": {}} if m else {}


def genome_of(sheet):
    """CharacterSheet.genome: the base genome with the sheet's genes, shares and parts."""
    g = copy.deepcopy(sheet.get("base_genome") or {})
    if not g:
        return g
    g.setdefault("behavior", {}).update({k: float(v) for k, v in (sheet.get("genes") or {}).items()})
    g["ship"].setdefault("shares", {}).update({k: float(v) for k, v in (sheet.get("shares") or {}).items()})
    for template_id in sheet.get("remove_parts") or []:
        for group in ("tools", "modules"):
            index = next((i for i, p in enumerate(g.get(group, [])) if p and part_id(p) == template_id), None)
            if index is not None:
                g[group][index] = {}
                break
    for template_id in sheet.get("add_parts") or []:
        part = part_of(template_id)
        if part:
            g.setdefault("tools" if part["kind"] in TOOL_KINDS else "modules", []).append(part)
    return g


def tweaked(sheet):
    return any(sheet.get(key) for key in ("genes", "shares", "add_parts", "remove_parts"))


def archetype_names():
    return sorted(os.path.basename(p)[len("agent_archetype_"):-len(".tres")]
                  for p in glob.glob(os.path.join(ARCHETYPES_DIR, "agent_archetype_*.tres")))


def read_sheets(bridge):
    """Archetype -> its character's values (the bridge's read), for those that have one."""
    out = {}
    for name in archetype_names():
        path = "res://database/characters/character_%s.tres" % name
        if os.path.exists(os.path.join(ROOT, path[len("res://"):])):
            out[name] = bridge.call("read", path=path)["values"]
    return out


def design_number(origin):
    """The genome number in a base_origin ("trader_medium_21949i2 (era 68)" -> "21949i2"), "" if none."""
    m = re.search(r"_(\d+i\d+)\b", origin or "")
    return m.group(1) if m else ""


class Era:
    """The era's lives, the catalogue and the game's laws."""

    def __init__(self, folder=None, say=print):
        self.consts = game_constants()
        self.parts = catalogue()
        self.weights = [w[0] for w in self.consts["PRESET_WEIGHT_CLASSES"]]
        self.number, self.since, self.log = era_info(folder)
        if not self.log:
            raise SystemExit("No evolution life log in %s" % (folder or os.path.join(user_dir(), "evolution", "logs")))
        self.lives, self.genomes = read_lives(self.log, self.since, self.consts, self.parts)
        say("Era %d: %d lives since t=%.0f s (%s)" % (self.number, len(self.lives), self.since, os.path.basename(self.log)))

    def last_life(self, number):
        """The last life in the log of the genome whose id ends with `number` (any faction's prefix)."""
        if not number:
            return None
        found = [d for gid, d in self.genomes.items() if gid.endswith(number)]
        return max(found, key=lambda d: d.get("t", 0.0)) if found else None


def price(arch, sheet, era, models, spreads, standing, by_arch):
    """A character's price line: what its tweaks do to fitness, death and earnings, where its base
    stands against the archetype's other designs, and what the tweaks do to speed, hull and hold."""
    if not tweaked(sheet):
        text = "no tweaks"
    else:
        text = ""
    d = era.last_life(design_number(sheet.get("base_origin")))
    if d is None:
        return (text + "; " if text else "") + "its base (%s) flew no lives in this log" % sheet.get("base_origin")
    base = sheet.get("base_genome") or d["genome"]
    old = dict(d, genome=base, s=stats(base, era.consts, era.parts))
    old["cost"] = d["cost"] - part_value(d["genome"], era.parts) + part_value(base, era.parts)
    genome = genome_of(sheet)
    new = dict(old, genome=genome, s=stats(genome, era.consts, era.parts))
    new["cost"] = old["cost"] - part_value(base, era.parts) + part_value(genome, era.parts)
    fam, w = arch.rsplit("_", 1)
    if text == "":
        if fam not in models:
            text = "no model for %ss (too few lives)" % fam
        elif models[fam]["fitness"]["r2"] < 0.05:
            text = "tweaks: no reliable effect (design hardly moves this role's fitness)"
        else:
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
            text = "tweaks: about free" if abs(f) < 0.02 and fs < 0.03 else \
                "tweaks %+.2f fitness (±%.2f), death chance %+.0f pts, earnings %+.2f of cost" % (f, 1.645 * fs, 100 * out["dies"][0], out["net"][0])
    gid = d["genome_id"]
    if gid in standing:
        mean, se, n = standing[gid]
        rivals = [standing[g] for g in by_arch.get(arch, []) if g in standing]
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
    return text + ("; " + ", ".join(changes) if changes else "")


def prices():
    """Archetype -> its last price line ({} before the first pricing)."""
    try:
        return json.loads(read(out_file(PRICES_JSON))).get("prices", {})
    except (OSError, ValueError):
        return {}


# --- Actions ---

def run_price(refit=False, say=print, bridge_factory=None):
    era = Era(say=say)
    models, spreads = models_for(era.log, era.since, era.lives, era.weights, refit, say)
    for fam in FAMILIES:
        if fam in models:
            say("  %-10s explains %3.0f%% of fitness" % (fam, 100 * max(models[fam]["fitness"]["r2"], 0.0)))
    standing, by_arch = standings(era.lives)
    if bridge_factory is None:
        from .bridge import Bridge
        bridge_factory = Bridge
    bridge = bridge_factory()
    try:
        sheets = read_sheets(bridge)
    finally:
        bridge.close()
    lines = {}
    for arch in archetype_names():
        if arch not in sheets:
            lines[arch] = "no character"
        else:
            lines[arch] = price(arch, sheets[arch], era, models, spreads, standing, by_arch)
        say("%-22s %-16s %s" % (arch, (sheets.get(arch) or {}).get("display_name", ""), lines[arch]))
    with open(out_file(PRICES_JSON), "w") as handle:
        json.dump({"era": era.number, "log": os.path.basename(era.log), "prices": lines}, handle, indent=1)
    say("Kept in %s (the Archetypes tab shows them)" % os.path.relpath(out_file(PRICES_JSON), ROOT))
    return 0


def main(argv):
    action = argv[0] if argv else ""
    options = dict(arg.split("=", 1) for arg in argv[1:] if "=" in arg)
    if action == "price":
        return run_price(refit=str(options.get("refit", "no")).lower() in ("yes", "y", "true", "1"))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
