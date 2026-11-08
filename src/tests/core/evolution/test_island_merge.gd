# Tests for IslandMerge: island runs from one base save made one again.

extends GutTest

const IslandMerge = preload("res://src/core/evolution/island_merge.gd")


func _entry(lives: int, total: float) -> Dictionary:
	return {"genome": {}, "faction": "verdant", "parent": "", "born": 0.0, "lives": lives, "fitness_sum": total,
		"fitness_sq": total * total / max(lives, 1), "kills": lives, "deaths": 0, "earned": 10 * lives}


func _base() -> Dictionary:
	return {"run_id": "20261108_000000", "game_time": 100.0, "next_genome": 10,
		"totals": {"births": 5, "deaths": 2, "retired": 3},
		"pools": {"verdant": {"cells": {"s+0.0|fighter|mid": "V1"}, "lives": 5}},
		"genomes": {"V1": _entry(4, 2.0)}}


func test_records_add_up_and_new_genomes_join():
	var one: Dictionary = _base().duplicate(true)
	one.run_id = "20261108_000000_i1"
	one.genomes.V1 = _entry(6, 3.0)  # Two more lives here
	one.genomes["V10i1"] = _entry(3, 3.0)
	one.pools.verdant.cells["s+1.0|raider|-"] = "V10i1"
	one.pools.verdant.lives = 10
	one.totals = {"births": 10, "deaths": 4, "retired": 6}
	one.next_genome = 12
	one.game_time = 200.0
	var two: Dictionary = _base().duplicate(true)
	two.genomes.V1 = _entry(7, 2.5)  # Three more lives here
	two.genomes["V10i2"] = _entry(8, 8.0)
	two.pools.verdant.cells["s+1.0|raider|-"] = "V10i2"
	two.pools.verdant.lives = 8
	two.totals = {"births": 8, "deaths": 3, "retired": 5}
	two.next_genome = 15
	var merged: Dictionary = IslandMerge.merge(_base(), [one, two])
	assert_eq(merged.run_id, "20261108_000000", "The era's run, not an island's")
	assert_eq(int(merged.genomes.V1.lives), 9, "4 + 2 + 3")
	assert_almost_eq(float(merged.genomes.V1.fitness_sum), 3.5, 0.0001, "2 + 1 + 0.5")
	var sq: float = _entry(4, 2.0).fitness_sq
	assert_almost_eq(float(merged.genomes.V1.fitness_sq), sq + (_entry(6, 3.0).fitness_sq - sq) + (_entry(7, 2.5).fitness_sq - sq), 0.0001)
	assert_eq(int(merged.genomes.V1.earned), 90)
	assert_true(merged.genomes.has("V10i1") and merged.genomes.has("V10i2"), "Both islands' new genomes")
	assert_eq(int(merged.genomes.V10i2.lives), 8, "A new genome's record as its island has it")
	assert_eq(merged.pools.verdant.cells["s+1.0|raider|-"], "V10i2", "The fitter of the two takes the niche")
	assert_eq(merged.pools.verdant.cells["s+0.0|fighter|mid"], "V1")
	assert_eq(int(merged.pools.verdant.lives), 5 + 5 + 3)
	assert_eq(int(merged.totals.deaths), 2 + 2 + 1)
	assert_eq(int(merged.totals.retired), 3 + 3 + 2)
	assert_eq(int(merged.next_genome), 15, "Ids go on past every island's")
	assert_eq(float(merged.game_time), 200.0, "The world is the first island's")


func test_one_island_is_its_own_save():
	var one: Dictionary = _base().duplicate(true)
	one.genomes.V1 = _entry(6, 3.0)
	var merged: Dictionary = IslandMerge.merge(_base(), [one])
	assert_eq(int(merged.genomes.V1.lives), 6)
	assert_almost_eq(float(merged.genomes.V1.fitness_sum), 3.0, 0.0001)


func test_an_island_names_its_genomes_apart():
	var was: int = Evolution.island
	Evolution.island = 2
	var genome_id: String = Evolution._add_genome(Evolution.Genome.random_genome(), "verdant", "")
	Evolution.island = was
	assert_true(genome_id.ends_with("i2"), genome_id)
	Evolution.genomes.erase(genome_id)
