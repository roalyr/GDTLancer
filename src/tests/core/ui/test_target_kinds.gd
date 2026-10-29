# Tests for TargetKinds: ships and stations coloured by side to the player, not faction; the rest
# by kind.

extends GutTest

const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")
const DockableStationScript = preload("res://src/scenes/game_world/station/dockable_station.gd")


func after_each():
	GameState.reset_state()


func _station(faction: String) -> Node:
	var station = StaticBody.new()
	station.set_script(load("res://src/scenes/game_world/station/faction_station.gd"))
	station.faction = faction
	return station


func test_stations_by_side():
	var verdant = _station("verdant")
	var hive = _station("xenohive")
	assert_eq(TargetKinds.kind_of(verdant), "other", "Not in the tree yet: no groups")
	assert_eq(TargetKinds.side_of(verdant, null), "neutral", "Neutral standing: blue")
	GameState.player_standing["verdant"] = 1.0
	assert_eq(TargetKinds.side_of(verdant, null), "allied", "Friendly standing: green")
	GameState.player_standing["verdant"] = -1.0
	assert_eq(TargetKinds.side_of(verdant, null), "hostile", "Hostile standing: red")
	assert_eq(TargetKinds.side_of(hive, null), "hostile", "The hive takes anyone near it for an enemy")
	assert_eq(TargetKinds.side_color("allied"), Constants.COLOR_UI_TARGET_ALLIED)
	verdant.free()
	hive.free()


func test_kinds_get_their_own_colours():
	var beacon := Spatial.new()
	beacon.add_to_group("beacon")
	var planet := Spatial.new()
	planet.add_to_group("celestial")
	assert_eq(TargetKinds.color_of(beacon, null), Constants.COLOR_UI_BEACON)
	assert_eq(TargetKinds.color_of(planet, null), Constants.COLOR_UI_BODY)
	beacon.free()
	planet.free()
