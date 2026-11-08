# IslandMerge: several evolution runs side by side ("islands", tools/evolution_sim.gd --island), each
# from the same save (the base), made one again (tools/merge_islands.gd, tools/devtool/islands.py).
# A genome's record is additive: what each island added to it since the base (lives, fitness and its
# squares, kills, deaths, earned) is summed onto the base's, so a design flown on two islands counts
# both. Genomes an island made are new (their ids end "i<island>": none clash). Each niche keeps the
# fittest of the islands' bests by the merged records (PresetExporter.ranked). Totals and pool lives
# add up the same way; the world (game time, the ships to fly again) is the first island's.

extends Reference

const PresetExporter = preload("res://src/core/evolution/preset_exporter.gd")
const RECORD_KEYS = ["lives", "kills", "deaths", "earned"]
const RECORD_FLOATS = ["fitness_sum", "fitness_sq"]


# `base`: the evolution data (a save's "evolution") the islands started from; `islands`: theirs after.
static func merge(base: Dictionary, islands: Array) -> Dictionary:
	if islands.empty():
		return base.duplicate(true)
	var merged: Dictionary = islands[0].duplicate(true)
	merged.run_id = base.get("run_id", merged.get("run_id", ""))
	var base_genomes: Dictionary = base.get("genomes", {})
	var genomes := {}
	for island in islands:
		for genome_id in island.get("genomes", {}):
			var entry: Dictionary = island.genomes[genome_id]
			if not genomes.has(genome_id):
				genomes[genome_id] = base_genomes[genome_id].duplicate(true) if base_genomes.has(genome_id) else _zeroed(entry)
			var start: Dictionary = base_genomes.get(genome_id, {})
			for key in RECORD_KEYS:
				genomes[genome_id][key] = int(genomes[genome_id].get(key, 0)) + int(entry.get(key, 0)) - int(start.get(key, 0))
			for key in RECORD_FLOATS:
				genomes[genome_id][key] = float(genomes[genome_id].get(key, 0.0)) + float(entry.get(key, 0.0)) - float(start.get(key, 0.0))
	merged.genomes = genomes
	var pools := {}
	for island in islands:
		for faction in island.get("pools", {}):
			var pool: Dictionary = island.pools[faction]
			if not pools.has(faction):
				pools[faction] = {"cells": {}, "lives": int(base.get("pools", {}).get(faction, {}).get("lives", 0))}
			pools[faction].lives += int(pool.get("lives", 0)) - int(base.get("pools", {}).get(faction, {}).get("lives", 0))
			for niche in pool.get("cells", {}):
				var candidate: String = str(pool.cells[niche])
				if not genomes.has(candidate):
					continue
				var held: String = str(pools[faction].cells.get(niche, ""))
				if held == "" or PresetExporter.ranked(genomes[candidate]) > PresetExporter.ranked(genomes[held]):
					pools[faction].cells[niche] = candidate
	merged.pools = pools
	var totals := {}
	for key in base.get("totals", {}):
		totals[key] = int(base.totals[key])
	for island in islands:
		for key in island.get("totals", {}):
			totals[key] = int(totals.get(key, 0)) + int(island.totals[key]) - int(base.get("totals", {}).get(key, 0))
	merged.totals = totals
	var next_genome: int = int(base.get("next_genome", 0))
	for island in islands:
		next_genome = int(max(next_genome, int(island.get("next_genome", 0))))
	merged.next_genome = next_genome
	return merged


static func _zeroed(entry: Dictionary) -> Dictionary:
	var fresh: Dictionary = entry.duplicate(true)
	for key in RECORD_KEYS:
		fresh[key] = 0
	for key in RECORD_FLOATS:
		fresh[key] = 0.0
	return fresh
