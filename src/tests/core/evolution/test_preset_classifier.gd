# Tests for PresetClassifier: role, weight class, temperament and traits of a preset, for picking
# archetypes when building factions.

extends GutTest

const PresetClassifier = preload("res://src/core/evolution/preset_classifier.gd")


func test_default_genes_are_measured_with_no_traits():
	assert_eq(PresetClassifier.temperament({}), "measured")
	assert_eq(PresetClassifier.traits({}), [], "Where evolution started says nothing")


func test_a_pilot_that_starts_keeps_up_and_chases_fights_is_aggressive():
	var genes := {"engage": 0.3, "disengage": 0.1, "pursuit": 3.0, "mercy": 0.0, "caution": 0.0}
	assert_eq(PresetClassifier.temperament(genes), "aggressive")
	var words: Array = PresetClassifier.traits(genes)
	for word in ["quick to fight", "stubborn", "relentless", "ruthless", "bold"]:
		assert_has(words, word)
	assert_eq(PresetClassifier.temperament({"engage": 4.0, "retreat_hull": 0.8, "caution": 1.0}), "cautious", "Picky, runs early, wary")


func test_a_preset_is_classified_by_its_fit_and_hull():
	var ship = ShipTemplate.new()
	ship.law_genes = {"size": 4.0}
	var result: Dictionary = PresetClassifier.classify(ship, {}, "lance-raider")
	assert_eq(result.role, "lance-raider")
	assert_eq(result.family, "lance")
	assert_eq(result.weight_class, "heavy")
	assert_eq(result.archetype, "lance-raider heavy")
