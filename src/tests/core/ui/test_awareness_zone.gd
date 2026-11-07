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
	assert_eq(zone.get_node("Layout/TargetRow/Name").text, "RAIDER")
	assert_eq(zone.get_node("Layout/TargetRow/Distance").text, "1500")
	assert_almost_eq(zone.get_node("Layout/TargetRow/Hull").value, 0.25, 0.01, "Its hull")
	assert_almost_eq(zone.get_node("Layout/Bars/Hull").value, 0.5, 0.01, "Own hull")
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
