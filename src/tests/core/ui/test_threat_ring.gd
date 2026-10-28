# Tests for ThreatRing: which ships it shows and which way their arrows point.

extends GutTest

const ThreatRing = preload("res://src/core/ui/main_hud/threat_ring.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")


func before_each():
	GameState.reset_state()


func after_each():
	GameState.reset_state()


func _ship(faction: String, at: Vector3, agent_type: String = "npc") -> Node:
	var body = AgentScript.new()
	body.agent_type = agent_type
	body.faction = faction
	body.translation = at
	add_child_autofree(body)
	return body


func test_it_shows_hostile_ships_in_range_only():
	var player = _ship("player", Vector3.ZERO, "player")
	var raider = _ship("raiders", Vector3(0, 0, 1000))  # Bare hulls: 1500 m signature, sensors 1
	var friend = _ship("verdant", Vector3(0, 0, 800))
	var unseen = _ship("raiders", Vector3(0, 0, 3000))
	var docked = _ship("raiders", Vector3(0, 0, 500))
	docked.is_docked = true
	var shown: Array = ThreatRing.threats(player, [player, raider, friend, unseen, docked])
	assert_eq(shown, [raider], "Hostile, detected, undocked")


func test_arrows_point_the_way_to_turn():
	var camera := Transform.IDENTITY  # Looking down -Z, up +Y
	assert_eq(ThreatRing.screen_direction(camera, Vector3(100, 0, 50)), Vector2(1, 0), "Behind and to the right: right")
	assert_eq(ThreatRing.screen_direction(camera, Vector3(0, 100, 50)), Vector2(0, -1), "Above: up the screen")
	assert_eq(ThreatRing.screen_direction(camera, Vector3(0, 0, 100)), Vector2(0, 1), "Dead astern: down")


class SeerStub extends Spatial:
	var sees: bool = true
	func detects(_other) -> bool:
		return sees


func test_an_arrow_is_dim_while_the_hostile_has_not_seen_the_player():
	var ship = SeerStub.new()
	add_child_autofree(ship)
	var bright: Color = ThreatRing.arrow_colour(ship, null, 1.0)
	assert_eq(bright, Constants.THREAT_COLOR, "Near, and it sees the player: full red")
	ship.sees = false
	var dim: Color = ThreatRing.arrow_colour(ship, null, 1.0)
	assert_almost_eq(dim.r, Constants.THREAT_COLOR.r * Constants.UI_UNAWARE_DIM, 0.001)
	assert_almost_eq(dim.a, Constants.UI_UNAWARE_ALPHA, 0.001)
