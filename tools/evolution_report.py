#!/usr/bin/env python3
"""Summarises an evolution run's life log (user://evolution_logs/run_<id>.jsonl, one JSON per finished life).

    python3 tools/evolution_report.py [log.jsonl] [--last-hours H]

Without a path, reads the newest log in the Godot user folder. Prints, per faction:
  - fitness over time (mean per simulated half hour), so you can see whether it still climbs;
  - niches by mean fitness, with lives, kill/death and the most-flown genome in each (preset candidates);
  - who kills whom by role and size (rock-paper-scissors shows up here), part usage, and ship sizes.
"""
import glob
import json
import os
import statistics
import sys
from collections import Counter, defaultdict

USER_DIRS = [
    "~/.local/share/godot/app_userdata/*/evolution_logs/",
    "~/Library/Application Support/Godot/app_userdata/*/evolution_logs/",
    "~/AppData/Roaming/Godot/app_userdata/*/evolution_logs/",
]


def newest_log():
    paths = []
    for pattern in USER_DIRS:
        paths += glob.glob(os.path.expanduser(pattern) + "run_*.jsonl")
    return max(paths, key=os.path.getmtime) if paths else None


def part_label(part):
    if not part:
        return "-"
    if part["kind"] == "harpoon":
        return "harpoon"
    return "%s %s" % (part["kind"], {1: "I", 2: "II", 3: "III"}.get(int(part["type"]), "?"))


def describe(genome):
    ship = genome["ship"]
    tools = " ".join(part_label(p) + ("(%.0fkg %.1fE)" % (p["genes"]["mass"], p["genes"]["energy"]) if p and p["kind"] == "laser" else "") for p in genome["tools"])
    mods = " ".join(part_label(p) + (("(%dx%.0fkg)" % (p["genes"]["count"], p["genes"]["nail_mass"]) if p["kind"] == "lance" else "(%.0fkg)" % p["genes"]["mass"]) if p and p["kind"] != "harpoon" else "") for p in genome["modules"])
    b = genome.get("behavior", {})
    return "Phoenix %s s=%.2f | %s | %s | eng %.2f dis %.2f rng %.2f ret %.2f pur %.2f mer %.2f rf %.2f" % (
        {1: "I", 2: "II", 3: "III"}.get(int(ship["type"]), "?"), ship["size"], tools, mods or "-",
        b.get("engage", 1), b.get("disengage", 0.8), b.get("range", 1), b.get("retreat_hull", 0),
        b.get("pursuit", 1), b.get("mercy", 0), b.get("return_fire", 1))


def main():
    args = sys.argv[1:]
    last_hours = None
    if "--last-hours" in args:
        i = args.index("--last-hours")
        last_hours = float(args[i + 1])
        del args[i:i + 2]
    path = args[0] if args else newest_log()
    if not path:
        sys.exit("No log found; pass its path.")
    lives = [json.loads(line) for line in open(path) if line.strip()]
    if last_hours is not None and lives:
        end = max(l["t"] for l in lives)
        lives = [l for l in lives if l["t"] >= end - last_hours * 3600]
    print("Log %s: %d lives, %.2f simulated hours" % (path, len(lives), max((l["t"] for l in lives), default=0) / 3600))
    by_uid = {l["uid"]: l for l in lives}
    for faction in sorted({l["faction"] for l in lives}):
        own = [l for l in lives if l["faction"] == faction]
        print("\n==== %s: %d lives, %d deaths, %d retired ====" % (faction.upper(), len(own), sum(l["died"] for l in own), sum(not l["died"] for l in own)))
        buckets = defaultdict(list)
        for l in own:
            buckets[int(l["t"] // 1800)].append(l["fitness"])
        print("Fitness by half hour: " + "  ".join("%.1fh %+.2f" % ((k + 1) / 2, statistics.mean(v)) for k, v in sorted(buckets.items())))
        niches = defaultdict(list)
        for l in own:
            niches[l["niche"]].append(l)
        print("\nNiches (mean fitness, lives, kills/death, top genome):")
        ranked = sorted(niches.items(), key=lambda kv: -statistics.mean(x["fitness"] for x in kv[1]))
        for niche, group in ranked[:15]:
            genomes = Counter(x["genome_id"] for x in group)
            top_id, top_n = genomes.most_common(1)[0]
            top = [x for x in group if x["genome_id"] == top_id]
            kills = sum(x["kills"] for x in group)
            deaths = sum(x["died"] for x in group)
            print("  %-24s %+.2f  n=%-4d k/d %.2f  | %s x%d fit %+.2f: %s" % (
                niche, statistics.mean(x["fitness"] for x in group), len(group), kills / max(deaths, 1),
                top_id, top_n, statistics.mean(x["fitness"] for x in top), describe(top[-1]["genome"])))
        parts = Counter()
        for l in own:
            for p in l["genome"]["tools"] + l["genome"]["modules"]:
                parts[part_label(p)] += 1
        print("\nParts flown: " + ", ".join("%s %d" % kv for kv in parts.most_common()))
        events = Counter()
        for l in own:
            events.update(l.get("events", {}))
        print("Events: " + ", ".join("%s %d" % kv for kv in sorted(events.items())) + " (fled: broke off or ran; escaped: docked while running)")
        genes = defaultdict(list)
        for l in own:
            for gene, value in l["genome"].get("behavior", {}).items():
                genes[gene].append(value)
        print("Behaviour genes (median, quartiles): " + ", ".join("%s %.2f (%.2f-%.2f)" % (g, statistics.median(v), *statistics.quantiles(v, n=4)[0::2]) for g, v in sorted(genes.items()) if len(v) > 3))
        sizes = [l["genome"]["ship"]["size"] for l in own]
        print("Ship size: median %.2f, quartiles %.2f-%.2f" % (statistics.median(sizes), *statistics.quantiles(sizes, n=4)[0::2]) if len(sizes) > 3 else "")
    print("\n==== Who kills whom (killer role|size -> victim role|size) ====")
    matrix = Counter()
    for l in lives:
        killer = by_uid.get(l.get("killer", ""))
        if l["died"] and killer:
            k = killer["niche"].split("|")
            v = l["niche"].split("|")
            matrix[("%s %s" % (k[1], k[0]), "%s %s" % (v[1], v[0]))] += 1
    for (k, v), n in matrix.most_common(20):
        print("  %-22s -> %-22s %d" % (k, v, n))


if __name__ == "__main__":
    main()
