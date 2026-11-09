# Tests for PresetExporter: parts left off as junk, designs measured against their faction's family.

extends GutTest

const PresetExporter = preload("res://src/core/evolution/preset_exporter.gd")
const Genome = preload("res://src/core/evolution/genome.gd")


func test_bays_without_their_weapon_are_junk():
	var genome := {"tools": [{"kind": "laser", "type": 1, "genes": {}}], "modules": []}
	assert_true(PresetExporter.is_junk({"kind": "magazine"}, genome), "A shell bay with no cannon")
	assert_true(PresetExporter.is_junk({"kind": "rack"}, genome), "A missile bay with no rack")
	genome.tools.append({"kind": "cannon", "type": 1, "genes": {}})
	assert_false(PresetExporter.is_junk({"kind": "magazine"}, genome), "Fed: kept")
	assert_false(PresetExporter.is_junk({"kind": "plating"}, genome))


func test_designs_are_measured_against_their_factions_family():
	var genome: Dictionary = Genome.seed_genome(Constants.EVO_FACTION_SEEDS[2])
	var family: String = Genome.family(Genome.niche(genome))
	var genomes := {
		"A": {"genome": genome, "faction": "xenohive", "lives": 10, "fitness_sum": 5.0},
		"B": {"genome": genome, "faction": "xenohive", "lives": 10, "fitness_sum": 3.0},
		"C": {"genome": genome, "faction": "verdant", "lives": 4, "fitness_sum": -2.0},
	}
	var base: Dictionary = PresetExporter.baselines(genomes)
	assert_almost_eq(float(base["xenohive|" + family]), 0.4, 0.001)
	assert_almost_eq(float(base["verdant|" + family]), -0.5, 0.001)
