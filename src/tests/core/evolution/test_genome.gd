# Tests for Genome: random genomes and mutants stay lawful and fit their ships; niches and builds.

extends GutTest

const Genome = preload("res://src/core/evolution/genome.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")


func after_each():
	TemplateDatabase.evolved = {}


func _assert_lawful(genome: Dictionary) -> void:
	var size: float = float(genome.ship["size"])
	assert_between(size, Constants.LAW_SHIP_SIZE_MIN, Constants.LAW_SHIP_SIZE_MAX)
	assert_eq(genome.tools.size(), ShipLaws.tool_slot_count(size), "One part (or none) per hardpoint")
	assert_eq(genome.modules.size(), ShipLaws.module_slot_count(size), "One part (or none) per bay")
	for part in genome.tools:
		if not part.empty() and part.kind == "laser":
			assert_true(part.genes.mass <= Genome.slot_mass_limit(genome), "The laser fits the hardpoints")
	for gene in genome.behavior:
		var bounds: Array = Constants.EVO_BEHAVIOR_RANGES[gene]
		assert_between(float(genome.behavior[gene]), float(bounds[0]), float(bounds[1]))


func test_random_genomes_and_their_mutants_are_lawful():
	seed(7)
	for _i in range(30):
		var genome: Dictionary = Genome.random_genome()
		_assert_lawful(genome)
		for _j in range(10):
			genome = Genome.mutate(genome, true)
			_assert_lawful(genome)


func test_mutation_leaves_the_parent_alone():
	var genome: Dictionary = Genome.random_genome()
	var before: String = to_json(genome)
	Genome.mutate(genome, true)
	assert_eq(to_json(genome), before)


func test_behavior_stays_fixed_until_switched_on():
	var genome: Dictionary = Genome.random_genome()
	for _i in range(50):
		genome = Genome.mutate(genome, false)
	assert_eq_deep(genome.behavior, Genome.default_behavior())


func test_niche_reads_size_role_and_range():
	var genome := {
		"ship": {"type": 2, "size": 1.0, "shares": Constants.LAW_SHIP_SHARES.duplicate()},
		"tools": [{"kind": "laser", "type": 2, "genes": {"mass": 300.0, "energy": 5.0}}, {"kind": "harpoon", "type": 0, "genes": {}}],
		"modules": [{}, {}],
		"behavior": Genome.default_behavior(),
	}
	assert_eq(Genome.niche(genome), "s+0.0|raider|mid")
	genome.tools[0] = {}
	assert_eq(Genome.niche(genome), "s+0.0|scavenger|-")


func test_build_registers_ship_and_parts_and_prices_them():
	var genome: Dictionary = Genome.random_genome()
	var built: Dictionary = Genome.build(genome, "T1", "verdant")
	var ship = TemplateDatabase.get_template(built.ship_template_id)
	assert_true(ship is ShipTemplate)
	assert_eq(built.fit.tools.size(), genome.tools.size())
	var total: float = ship.base_value
	for template_id in built.fit.tools + built.fit.modules:
		if template_id != "":
			assert_not_null(TemplateDatabase.get_template(template_id), template_id)
			total += TemplateDatabase.get_template(template_id).base_value
	assert_almost_eq(Genome.cost(genome), total, 1.0)
	assert_false(TemplateDatabase.assets_ships.has(built.ship_template_id), "Evolved ships are not sold at stations")
