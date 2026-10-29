# Tests for Genome: random genomes and mutants stay lawful and fit their ships; niches and builds.

extends GutTest

const Genome = preload("res://src/core/evolution/genome.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")


func after_each():
	TemplateDatabase.evolved = {}


func _assert_lawful(genome: Dictionary) -> void:
	var size: float = float(genome.ship["size"])
	assert_between(size, Constants.LAW_SHIP_SIZE_MIN, Constants.LAW_SHIP_SIZE_MAX)
	var counts: Array = ShipLaws.slot_counts(size, float(genome.ship.get("tool_share", -1.0)))
	assert_eq(genome.tools.size(), counts[0], "One part (or none) per hardpoint")
	assert_eq(genome.modules.size(), counts[1], "One part (or none) per bay")
	for part in genome.tools:
		if not part.empty() and part.kind == "laser":
			assert_true(part.genes.mass <= Genome.slot_mass_limit(genome), "The laser fits the hardpoints")
		elif not part.empty() and part.kind == "missile":
			assert_true(ShipLaws.missile_stats(part.genes).mass <= Genome.slot_mass_limit(genome) + 0.01, "The rack fits the hardpoints: %s %.1f" % [part.genes, Genome.slot_mass_limit(genome)])
		elif not part.empty() and part.kind == "cannon":
			assert_true(ShipLaws.cannon_stats(part.genes).mass <= Genome.slot_mass_limit(genome) + 0.01, "The cannon fits the hardpoints")
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


func test_saved_capacitors_become_power_cells():
	var genome: Dictionary = Genome.random_genome()
	genome.modules = [{"kind": "capacitor", "type": 2, "genes": {"mass": 200.0}}, {}]
	assert_true(Genome.retire_parts(genome))
	assert_eq(genome.modules[0].kind, "power_cell")
	assert_eq(genome.modules[0].genes.mass, 200.0, "The same mass")
	assert_false(Genome.retire_parts(genome), "Nothing left to retire")


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


func test_lances_are_lawful_parts_with_their_own_niche():
	var part: Dictionary = Genome.random_part("lance")
	assert_true(part.genes.has("nail_mass") and part.genes.has("count"))
	var genome: Dictionary = Genome.random_genome()
	for i in range(genome.tools.size()):
		genome.tools[i] = {}
	genome.modules[0] = part
	assert_eq(Genome.niche(genome).split("|")[1], "lancer")
	genome.tools[0] = Genome.random_part("laser")
	assert_eq(Genome.niche(genome).split("|")[1], "lance-fighter")
	var template = TemplateDatabase.get_template(Genome.ensure_part_template(part))
	assert_true(template is ModuleTemplate and not template.lance.empty())
	assert_eq(template.lance.count, int(round(part.genes.count)))
	genome.modules = [part, part.duplicate(true)]
	var twins := 0
	for _i in range(20):
		var lances := 0
		for module in Genome.mutate(genome, false).modules:
			lances += 1 if not module.empty() and module.kind == "lance" else 0
		twins += 1 if lances == 2 else 0
	assert_gt(twins, 0, "A second launcher is kept (a ship may carry several)")


func test_missiles_and_cannons_are_lawful_weapons_on_their_own_branches():
	var genome: Dictionary = Genome.random_genome()
	for i in range(genome.tools.size()):
		genome.tools[i] = {}
	for i in range(genome.modules.size()):
		genome.modules[i] = {}
	genome.tools[0] = Genome.random_part("missile", Genome.slot_mass_limit(genome))
	assert_eq(Genome.niche(genome).split("|")[1], "missile-fighter")
	var rack = TemplateDatabase.get_template(Genome.ensure_part_template(genome.tools[0]))
	assert_true(rack is UtilityToolTemplate and rack.tool_type == "missile" and rack.ammo == int(round(genome.tools[0].genes.count)))
	genome.tools[0] = Genome.random_part("cannon", Genome.slot_mass_limit(genome))
	assert_eq(Genome.niche(genome).split("|")[1], "cannon-fighter")
	var gun = TemplateDatabase.get_template(Genome.ensure_part_template(genome.tools[0]))
	assert_true(gun is UtilityToolTemplate and gun.tool_type == "cannon" and gun.ammo > 0 and gun.projectile_speed > 0.0)
	assert_gt(Genome.cost(genome), ShipLaws.ship_stats(genome.ship).base_value, "Priced with its rounds")
	var heavy: Dictionary = {"kind": "missile", "type": 3, "genes": {"round_mass": 900.0, "count": 16.0}}
	Genome._clamp_part(heavy, 799.0)
	assert_true(ShipLaws.missile_stats(heavy.genes).mass <= 799.0 + 0.01, "Cut down to the hardpoint: fewer, lighter missiles")

	var big_gun: Dictionary = {"kind": "cannon", "type": 3, "genes": Constants.PART_TYPE_SEEDS.cannon[3].duplicate()}
	Genome._clamp_part(big_gun, 799.0)
	assert_true(ShipLaws.cannon_stats(big_gun.genes).mass <= 799.0 + 0.01, "A heavy cannon cut down to a small hardpoint")
	assert_gt(big_gun.genes.count, 20.0, "keeps a useful magazine")


func test_mutation_can_shift_slots_between_hardpoints_and_bays():
	seed(7)
	var genome: Dictionary = Genome.random_genome()
	genome.ship["size"] = 4.0
	genome.ship["tool_share"] = 0.0
	var child: Dictionary = Genome.mutate(genome, false)
	var counts: Array = ShipLaws.slot_counts(float(child.ship["size"]), float(child.ship.tool_share))
	assert_eq(child.tools.size(), counts[0], "Hardpoints follow the gene")
	assert_eq(child.modules.size(), counts[1], "and so do the bays")
	assert_true(child.tools.size() >= 1 and child.modules.size() >= 1, "One of each kept")
	var seen_shares := {}
	for i in range(200):
		var mutant: Dictionary = Genome.mutate(genome, false)
		if mutant.ship.has("tool_share"):
			seen_shares[int(round(float(mutant.ship.tool_share) * 10.0))] = true
	assert_gt(seen_shares.size(), 1, "The split varies")


func test_extra_harpoons_are_rare():
	seed(3)
	var first := 0
	var extra := 0
	for i in range(2000):
		if Genome._random_tool_kind(0) == "harpoon":
			first += 1
		if Genome._random_tool_kind(1) == "harpoon":
			extra += 1
	assert_almost_eq(first / 2000.0, Constants.EVO_HARPOON_CHANCE, 0.03, "A first harpoon now and then")
	assert_almost_eq(extra / 2000.0, Constants.EVO_EXTRA_HARPOON_CHANCE, 0.02, "a second one seldom")
