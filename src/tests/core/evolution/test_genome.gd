# Tests for Genome: random genomes and mutants stay lawful and fit their ships; niches and builds.

extends GutTest

const PartCatalog = preload("res://src/core/systems/part_catalog.gd")

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
	var slot: int = Genome.SLOT_SIZES.find(Genome.slot_size(genome))
	for part in genome.tools + genome.modules:
		if not part.empty():
			assert_true(Genome.SLOT_SIZES.find(PartCatalog.mount_size(part.kind, int(part.type), part.genes)) <= slot,
				"The %s fits the %s slots" % [part.kind, Genome.slot_size(genome)])
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
	assert_eq_deep(genome.modules[0].genes, PartCatalog.genes("power_cell", 2))  # The catalogue's power cell of that weight
	assert_false(Genome.retire_parts(genome), "Nothing left to retire")


func test_parts_are_the_catalogues_and_only_their_weight_varies():
	var genome: Dictionary = Genome.random_genome()
	for _i in range(40):
		genome = Genome.mutate(genome, true)
		for part in genome.tools + genome.modules:
			if part.empty() or part.kind == "harpoon":
				continue
			assert_eq_deep(part.genes, PartCatalog.genes(part.kind, int(part.type)))
			assert_eq(Genome.part_template_id(part), "preset_%s_%s" % [part.kind, PartCatalog.weight_name(int(part.type))])
	var evolved: Dictionary = {"ship": genome.ship, "tools": [{"kind": "laser", "type": 3, "genes": {"mass": 612.0, "energy": 14.2}}], "modules": [{"kind": "plating", "type": 1, "genes": {"mass": 777.0}}]}
	assert_true(Genome.retire_parts(evolved), "An older era's own genes give way")
	assert_eq_deep(evolved.modules[0].genes, PartCatalog.genes("plating", 1))


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
	genome.ship["size"] = 2.5  # Bays for both
	genome.ship["tool_share"] = 0.0  # As many bays as the hull has: a random share could leave one
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
	genome.tools[0] = Genome.random_part("missile", Genome.slot_size(genome))
	assert_eq(Genome.niche(genome).split("|")[1], "missile-fighter")
	var rack = TemplateDatabase.get_template(Genome.ensure_part_template(genome.tools[0]))
	assert_true(rack is UtilityToolTemplate and rack.tool_type == "missile" and rack.ammo == int(round(genome.tools[0].genes.count)))
	genome.tools[0] = Genome.random_part("cannon", Genome.slot_size(genome))
	assert_eq(Genome.niche(genome).split("|")[1], "cannon-fighter")
	var gun = TemplateDatabase.get_template(Genome.ensure_part_template(genome.tools[0]))
	assert_true(gun is UtilityToolTemplate and gun.tool_type == "cannon" and gun.ammo > 0 and gun.projectile_speed > 0.0)
	assert_gt(Genome.cost(genome), ShipLaws.ship_stats(genome.ship).base_value, "Priced with its rounds")
	var heavy: Dictionary = Genome._fitted({"kind": "missile", "type": 3, "genes": {}}, "medium")
	assert_eq(int(heavy.type), 2, "Too big for a medium hardpoint: the medium rack")
	var big_gun: Dictionary = Genome._fitted({"kind": "cannon", "type": 3, "genes": {}}, "small")
	assert_eq(int(big_gun.type), 1, "The light cannon on a small hardpoint")
	assert_eq_deep(big_gun.genes, PartCatalog.genes("cannon", 1))
	assert_eq(int(Genome._fitted({"kind": "cannon", "type": 3, "genes": {}}, "large").type), 3, "A large hardpoint takes the heavy one")
	assert_eq(int(Genome._fitted({"kind": "plating", "type": 3, "genes": {}}, "small").type), 1, "Modules too: a small bay takes light plating")


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
