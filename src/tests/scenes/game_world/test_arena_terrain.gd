# Tests for the arenas' terrain: each zone's rock field (Constants ARENA_ZONES, ARENA_ROCK_FIELDS) is
# built the same every time and keeps clear of the beacon and the stations.

extends GutTest

const ArenaScript = preload("res://src/scenes/game_world/arena/arena.gd")


func _rocks(arena: Node, zone_id: String) -> Array:
	var rocks: Array = []
	for child in arena.get_children():
		if child.name.begins_with("Rock_%s_" % zone_id):
			rocks.append(child)
	return rocks


func test_each_zone_has_its_terrain_clear_of_beacon_and_stations():
	var arena = ArenaScript.new()
	add_child_autofree(arena)
	for zone in Constants.ARENA_ZONES:
		var rocks: Array = _rocks(arena, zone.id)
		var wanted: int = int(Constants.ARENA_ROCK_FIELDS[zone.terrain])
		assert_true(rocks.size() >= floor(wanted * 0.8) and rocks.size() <= wanted, "%s: about %d rocks (%d)" % [zone.id, wanted, rocks.size()])
		var built: Dictionary = arena.get_zone(zone.id)
		for rock in rocks:
			assert_true(rock.is_in_group("asteroid"), "A rock")
			assert_gt(rock.transform.origin.distance_to(built.beacon.transform.origin), Constants.ARENA_ROCK_CLEARANCE, "Clear of the beacon")
			for faction in built.stations:
				for station in built.stations[faction]:
					assert_gt(rock.transform.origin.distance_to(station.transform.origin), Constants.ARENA_ROCK_CLEARANCE, "and of the stations")


func test_the_same_field_every_time():
	var first = ArenaScript.new()
	add_child_autofree(first)
	var second = ArenaScript.new()
	add_child_autofree(second)
	var a: Array = _rocks(first, "4v4")
	var b: Array = _rocks(second, "4v4")
	assert_eq(a.size(), b.size())
	for i in range(min(a.size(), b.size())):
		assert_eq(a[i].transform, b[i].transform, "Rock %d where it was" % i)
