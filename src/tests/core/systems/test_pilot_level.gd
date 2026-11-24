# Tests for PilotLevel: levels rolled no lower than the hull allows, the hull caps, misreading by
# judgement, an NPC misjudging a fight by it, levels on lives in play (none in evolution's runs),
# the pips, the top strip's tag and level, and the interaction window's PILOT tab. FactionRoster:
# pilots first, then families, then the hull the level flies; the mix of archetypes that makes.

extends GutTest

const PilotLevel = preload("res://src/core/systems/pilot_level.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")
const AIScript = preload("res://src/modules/piloting/ship_controller_ai.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const Marker = preload("res://src/core/ui/main_hud/target_marker.gd")
const Zone = preload("res://src/core/ui/main_hud/awareness_zone.gd")
const FactionRoster = preload("res://src/core/systems/faction_roster.gd")


func after_each():
	GlobalRefs.player_agent_body = null
	GameState.reset_state()


func _ship(position: Vector3, faction: String, hull: float, agent_type: String = "npc") -> RigidBody:
	var body = AgentScript.new()
	var ship = ShipTemplate.new()
	ship.signature = 1500.0
	ship.base_value = 1000
	ship.ship_model_name = "Fighter Mk I-light"
	body.ship_template = ship
	body.agent_type = agent_type
	body.wallet = 1e6
	add_child_autofree(body)
	body.global_transform.origin = position
	body.faction = faction
	body.hull_max = hull
	body.hull = hull
	var laser = UtilityToolTemplate.new()
	laser.damage = 6.0
	laser.cycle_time = 1.0
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	body.add_child(tools)
	tools.set_tools([laser])
	if agent_type == "npc":
		var ai = AIScript.new()
		ai.name = Constants.AI_CONTROLLER_NODE_NAME
		body.add_child(ai)
		ai._current_state = AIScript.AIState.PATROL
	return body


func test_hull_weight_caps_the_level():
	assert_eq(PilotLevel.least_for_weight("light"), 0)
	assert_eq(PilotLevel.least_for_weight("superheavy"), 3)
	assert_true(PilotLevel.may_fly(0, "light"), "A rookie flies light hulls")
	assert_false(PilotLevel.may_fly(0, "medium"), "but no heavier")
	assert_true(PilotLevel.may_fly(1, "medium"))
	assert_false(PilotLevel.may_fly(2, "superheavy"), "A veteran flies up to heavies")
	assert_true(PilotLevel.may_fly(3, "superheavy"), "An ace flies anything")
	for _i in range(50):
		assert_true(PilotLevel.roll(2) >= 2, "Rolled no lower than its hull allows")
	var seen := {}
	for _i in range(400):
		seen[PilotLevel.roll()] = true
	assert_eq(seen.size(), Constants.PILOT_LEVELS.size(), "Every level comes up")


func test_better_pilots_decide_faster_and_judge_better():
	for level in range(Constants.PILOT_LEVELS.size() - 1):
		assert_lt(PilotLevel.skill_for(level), PilotLevel.skill_for(level + 1) + 1e-6)
		assert_lt(PilotLevel.judgement_for(level), PilotLevel.judgement_for(level + 1))
	assert_eq(PilotLevel.judgement_for(-1), 1.0, "No level: always right")


func test_misreads_are_weaker_or_stronger_by_the_set_factor():
	assert_eq(PilotLevel.misread_factor(1.0), 1.0)
	var weaker := false
	var stronger := false
	for _i in range(100):
		var factor: float = PilotLevel.misread_factor(0.0)
		if factor > 1.0:
			stronger = true
			assert_true(factor >= Constants.PILOT_MISREAD_FACTOR[0] - 1e-4 and factor <= Constants.PILOT_MISREAD_FACTOR[1] + 1e-4)
		else:
			weaker = true
			assert_true(1.0 / factor >= Constants.PILOT_MISREAD_FACTOR[0] - 1e-4 and 1.0 / factor <= Constants.PILOT_MISREAD_FACTOR[1] + 1e-4)
	assert_true(weaker and stronger, "Either way")


func test_a_misjudging_pilot_reads_an_opponent_wrong_for_a_while():
	var hunter = _ship(Vector3.ZERO, "violet", 50.0)
	var prey = _ship(Vector3(0, 0, -800), "verdant", 50.0)
	var ai = hunter.get_node(Constants.AI_CONTROLLER_NODE_NAME)
	var right: float = ai.desire_against(prey)
	ai.judgement = 0.0  # Always misreads
	var wrong: float = ai.desire_against(prey)
	assert_ne(wrong, right, "Misread: weaker or stronger than it is")
	assert_eq(ai.desire_against(prey), wrong, "The same read until PILOT_MISREAD_TIME is up")
	ai._reads[prey.get_instance_id()][1] = Evolution.game_time - 1.0
	ai.judgement = 1.0
	assert_almost_eq(ai.desire_against(prey), right, 1e-4, "Read again (and a sure pilot reads right)")


func test_lives_in_play_fly_a_hull_their_level_allows():
	Evolution.new_run()
	Evolution.frozen = true
	var records: Array = []
	for _i in range(12):
		records.append(Evolution.begin_life("raiders", "arena_raiders_haven"))
	Evolution.frozen = false
	for record in records:
		if record.empty():
			continue
		assert_true(record.has("level"), "A pilot level")
		var weight: String = Evolution.niche_weight(Evolution.Genome.niche(Evolution.genomes[record.genome_id].genome))
		assert_true(PilotLevel.may_fly(int(record.level), weight), "%s flies %s" % [PilotLevel.name_of(record.level), weight])
		var span: Array = Constants.PILOT_LEVEL_SKILL[record.level]
		assert_true(record.skill >= span[0] and record.skill <= span[1], "Its skill by its level")
		Evolution._end_life(record.uid, true, "")
	Evolution.new_run()


func test_a_hostiles_mark_shows_its_level_as_pips():
	var marker = Marker.new()
	add_child_autofree(marker)
	marker.set_mark("ship", true, false, 2)
	assert_eq(marker.level, 2, "Three pips: a veteran")
	marker.set_mark("ship", true, false)
	assert_eq(marker.level, -1, "None by default")


func test_the_strip_tags_the_faction_and_names_the_level():
	var player = _ship(Vector3.ZERO, "player", 100.0, "player")
	GlobalRefs.player_agent_body = player
	var raider = _ship(Vector3(0, 0, -1500), "raiders", 50.0)
	raider.pilot_level = 3
	var tag: String = PilotLevel.faction_tag(raider)
	assert_eq(tag, "[%s]" % raider.get_faction_name().to_upper())
	assert_eq(Zone.name_text(raider, "Raider"), tag + " RAIDER")
	assert_eq(Zone.threat_text(player, raider), Zone.threat_word(player, raider) + " · ACE")
	raider.pilot_level = -1
	assert_eq(Zone.threat_text(player, raider), Zone.threat_word(player, raider), "No level: the word alone")


func test_the_window_has_a_pilot_tab_of_public_facts():
	var player = _ship(Vector3.ZERO, "player", 100.0, "player")
	GlobalRefs.player_agent_body = player
	var raider = _ship(Vector3(0, 0, 900), "raiders", 50.0)
	raider.pilot_level = 1
	raider.bounties = {"verdant": 120.0}
	var window = load("res://scenes/ui/menus/interaction_window.tscn").instance()
	add_child_autofree(window)
	window.open(raider)
	assert_eq(window.tab, "pilot", "Nothing to ask of a hostile: opens on its pilot")
	var pilot = window.get_node("Center/Panel/Overflow/Layout/Pilot")
	assert_true(pilot.visible)
	assert_eq(pilot.get_node("Value_LEVEL").text, "REGULAR")
	assert_string_contains(pilot.get_node("Value_WANTED_BY").text, "120 WP")
	assert_eq(pilot.get_node("Value_FLIES_FOR").text, raider.get_faction_name().to_upper())
	for row in PilotLevel.public_record(player, raider):
		assert_false(str(row[0]) in ["WALLET", "SKILL", "JUDGEMENT"], "Nothing private")
	window.show_tab("ask")
	assert_false(pilot.visible)
	assert_true(window.get_node("Center/Panel/Overflow/Layout/Options").visible)
	window.close()


func test_pilots_come_first_and_their_level_picks_the_hull():
	var spec := {"pilot_shares": {"rookie": 1.0}, "archetype_shares": {"fighter_light": 1.0, "fighter_medium": 1.0, "fighter_heavy": 1.0, "fighter_superheavy": 1.0}}
	for _i in range(20):
		var picked: Dictionary = FactionRoster.pick(spec)
		assert_eq(picked.name, "fighter_light", "A rookie flies light")
		assert_eq(picked.level, 0)
	spec.pilot_shares = {"ace": 1.0}
	var heavy := 0
	for _i in range(200):
		var picked: Dictionary = FactionRoster.pick(spec)
		assert_eq(picked.level, 3, "An ace stays an ace")
		heavy += int(picked.name == "fighter_superheavy")
	assert_true(heavy > 100 and heavy < 180, "Mostly its own class (%d of 200)" % heavy)
	assert_eq_deep(FactionRoster.pick({"pilot_shares": {"ace": 1.0}, "archetype_shares": {}}), {})


func test_the_mix_follows_the_shares():
	var shares := {}
	for weight in ["light", "medium", "heavy", "superheavy"]:
		shares["fighter_" + weight] = 3.0
		shares["trader_" + weight] = 1.0
	var mix: Dictionary = FactionRoster.mix({"pilot_shares": {"rookie": 1.0, "regular": 1.0}, "archetype_shares": shares})
	var total := 0.0
	for name in mix:
		total += mix[name]
	assert_almost_eq(total, 1.0, 1e-4, "Shares of every spawn")
	assert_almost_eq(mix.fighter_light, 0.75 * (0.5 + 0.5 * (1.0 - Constants.PILOT_OWN_CLASS_SHARE)), 1e-4)
	assert_almost_eq(mix.fighter_medium, 0.75 * 0.5 * Constants.PILOT_OWN_CLASS_SHARE, 1e-4)
	assert_false(mix.has("fighter_heavy"), "No veterans: no heavies")
	assert_true(FactionRoster.flies({"archetype_shares": {"trader_superheavy": 1.0}}, "trader_superheavy"), "Default pilot shares include aces")
	for faction in TemplateDatabase.factions:
		assert_false(FactionRoster.mix(TemplateDatabase.factions[faction]).empty(), "%s flies something" % faction)


func test_archetypes_are_picked_one_by_one():
	var spec := {"pilot_shares": {"ace": 1.0}, "archetype_shares": {"fighter_light": 1.0, "fighter_superheavy": 0.0, "trader_medium": 3.0}}
	var mix: Dictionary = FactionRoster.mix(spec)
	assert_false(mix.has("fighter_superheavy"), "A share of 0: never flown")
	assert_false(mix.has("fighter_medium"), "Not listed: never flown")
	assert_almost_eq(mix.trader_medium, 0.75, 1e-4, "By share where the level's odds are alike (both lighter than an ace's own class)")
	for _i in range(20):
		assert_true(FactionRoster.pick(spec).name in ["fighter_light", "trader_medium"])


func test_a_pilot_too_green_for_every_archetype_is_raised_to_the_lightest():
	var spec := {"pilot_shares": {"rookie": 1.0}, "archetype_shares": {"raider_heavy": 1.0, "raider_superheavy": 1.0}}
	for _i in range(20):
		var picked: Dictionary = FactionRoster.pick(spec)
		assert_eq(picked.name, "raider_heavy", "The lightest it lists")
		assert_eq(picked.level, 2, "Its pilot raised to fly it")


func test_a_preferred_family_narrows_the_roll():
	var spec := {"pilot_shares": {"rookie": 1.0}, "archetype_shares": {"fighter_light": 1.0, "trader_light": 1.0}}
	for _i in range(20):
		assert_eq(FactionRoster.pick(spec, "trader", 1.0).name, "trader_light")
		assert_eq(FactionRoster.pick(spec, "prospector", 1.0).name, "prospector_light", "A family it lists none of: all that family's alike")


func test_family_shares_spread_alike_over_weights_give_the_old_mix():
	var shares := {}
	for weight in ["light", "medium", "heavy", "superheavy"]:
		shares["fighter_" + weight] = 0.35
		shares["trader_" + weight] = 0.15
	var levels: Array = FactionRoster.pilot_shares({})
	var mix: Dictionary = FactionRoster.mix({"archetype_shares": shares})
	for family in [["fighter", 0.7], ["trader", 0.3]]:
		for weight in range(4):
			var expected := 0.0
			for level in range(levels.size()):
				expected += family[1] * levels[level] * float(FactionRoster.weight_odds(level)[weight])
			assert_almost_eq(float(mix.get("%s_%s" % [family[0], Constants.PRESET_WEIGHT_CLASSES[weight][0]], 0.0)), expected, 1e-4)
