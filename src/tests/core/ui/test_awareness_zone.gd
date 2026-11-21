# Tests for the HUD's top strip (AwarenessZone): what it counts and shows.

extends GutTest

const ZoneScene = preload("res://scenes/ui/hud/awareness_zone.tscn")
const Zone = preload("res://src/core/ui/main_hud/awareness_zone.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")


func after_each():
	GlobalRefs.player_agent_body = null


func test_it_shows_the_target_and_own_state():
	var player = AgentScript.new()
	player.agent_type = "player"
	player.faction = "player"
	add_child_autofree(player)
	player.hull_max = 100.0
	player.hull = 50.0
	player.power_max = 10.0
	player.power = 10.0
	player.cargo_capacity = 20
	player.cargo = {Constants.FUEL_COMMODITY: 4, "commodity_ore": 6}
	GlobalRefs.player_agent_body = player
	var raider = AgentScript.new()
	raider.faction = "raiders"
	add_child_autofree(raider)
	raider.hull_max = 100.0
	raider.hull = 25.0
	raider.global_transform.origin = Vector3(0, 0, -1500)
	var zone = ZoneScene.instance()
	add_child_autofree(zone)
	zone.target = raider
	zone.target_name = "Raider"
	for line in ["one", "two", "three"]:
		zone.add_radio_line(line)
	zone.refresh()
	assert_true(zone.visible)
	assert_eq(zone.get_node("Layout/TargetRow/Name").text, "[%s] RAIDER" % raider.get_faction_name().to_upper(), "Its faction's tag first")
	assert_eq(zone.get_node("Layout/TargetRow/Distance").text, "1500")
	assert_almost_eq(zone.get_node("Layout/TargetRow/Hull").value, 0.25, 0.01, "Its hull")
	assert_almost_eq(zone.get_node("Layout/Bars/Hull").value, 0.5, 0.01, "Own hull")
	assert_almost_eq(zone.get_node("Layout/Bars/Cargo").lead, 0.2, 0.01, "The hold: fuel first")
	assert_almost_eq(zone.get_node("Layout/Bars/Cargo").value, 0.3, 0.01, "then the rest of it")
	assert_eq(zone.get_node("Layout/Radio").text, "two\\nthree".c_unescape(), "The last lines only")
	assert_eq(zone.get_node("Layout/TargetRow/Threat").text, Zone.threat_word(player, raider), "How a fight would go")
	var seen: Array = Zone.ships_seen(player, [player, raider])
	assert_eq(seen[0], int(player.detects(raider)))
	zone._process(Constants.HUD_RADIO_FADE + 0.1)
	assert_eq(zone.get_node("Layout/Radio").text, "", "Radio lines fade out")


func test_the_bracket_leaves_the_name_to_the_strip():
	var bracket = load("res://scenes/ui/hud/projected_target_bracket.tscn").instance()
	add_child_autofree(bracket)
	var station = Spatial.new()
	add_child_autofree(station)
	bracket.configure_target(station, "Elace Exchange")
	bracket.set_selected_state(true)
	assert_eq(bracket.get_node("InfoPanel/InfoLabel").text, "Elace Exchange", "No strip: named under the bracket")
	var zone = ZoneScene.instance()
	add_child_autofree(zone)
	bracket._sync_label()
	assert_eq(bracket.get_node("InfoPanel/InfoLabel").text, "", "The strip names it")
	zone.suppressed = true
	bracket._sync_label()
	assert_eq(bracket.get_node("InfoPanel/InfoLabel").text, "Elace Exchange", "Back while the strip is hidden")


func test_a_jump_route_shows_where_it_goes():
	var player = AgentScript.new()
	player.agent_type = "player"
	add_child_autofree(player)
	player.hull_max = 100.0
	player.hull = 100.0
	GlobalRefs.player_agent_body = player
	var route = load("res://src/core/targeting/route_target.gd").new().configure("sector_elace", "sector_vidr", "Vidr", Vector3.UP)
	var zone = ZoneScene.instance()
	add_child_autofree(zone)
	zone.target = route
	zone.refresh()
	assert_eq(zone.get_node("Layout/TargetRow/Name").text, "JUMP TO VIDR")
	assert_eq(zone.get_node("Layout/TargetRow/Distance").text, "", "Nothing to measure")
	assert_eq(zone.get_node("Layout/TargetRow").modulate.a, 1.0, "Shown")


class Names:
	var name := "Rock chunk (3)"
	func of(_target) -> String:
		return name


func test_the_targets_name_follows_it():
	var player = AgentScript.new()
	player.agent_type = "player"
	add_child_autofree(player)
	player.hull_max = 100.0
	player.hull = 100.0
	GlobalRefs.player_agent_body = player
	var chunk = Spatial.new()
	add_child_autofree(chunk)
	var names = Names.new()
	var zone = ZoneScene.instance()
	add_child_autofree(zone)
	zone.name_source = funcref(names, "of")
	zone.target = chunk
	zone.target_name = names.name
	zone.refresh()
	assert_eq(zone.get_node("Layout/TargetRow/Name").text, "ROCK CHUNK (3)")
	names.name = "Ore chunk (3)"  # Bared
	zone.refresh()
	assert_eq(zone.get_node("Layout/TargetRow/Name").text, "ORE CHUNK (3)", "Without picking it again")


# The own hull bar flashes red as the hull falls, cooling back to white; a rise or another bar does not.
func test_the_hull_bar_flashes_red_on_a_hit_and_cools_back():
	var zone = ZoneScene.instance()
	add_child_autofree(zone)
	var hull = zone.get_node("Layout/Bars/Hull")
	var energy = zone.get_node("Layout/Bars/Energy")
	assert_true(hull.flash_on_drop)
	assert_false(energy.flash_on_drop, "Only the hull")
	hull.set_value(1.0)
	assert_eq(hull.fill_color(), hull.color, "White at rest")
	hull.set_value(0.8)
	assert_true(hull.fill_color().is_equal_approx(hull.flash_color), "Red the moment it falls")
	hull._process(Constants.HUD_BAR_FLASH_TIME * 0.5)
	var mid: Color = hull.fill_color()
	assert_true(mid.g > hull.flash_color.g and mid.g < hull.color.g, "Cooling")
	hull._process(Constants.HUD_BAR_FLASH_TIME)
	assert_true(hull.fill_color().is_equal_approx(hull.color), "White again")
	assert_false(hull.is_processing())
	hull.set_value(0.9)
	assert_eq(hull.flash, 0.0, "A repair does not flash")
	energy.set_value(0.5)
	assert_eq(energy.flash, 0.0)
