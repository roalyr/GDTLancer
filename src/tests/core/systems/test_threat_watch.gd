# Tests for ThreatWatch: notices once per ship, and the level the music follows.

extends GutTest

const ThreatWatch = preload("res://src/core/systems/threat_watch.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")

var watch: Node = null
var player: RigidBody = null
var heard: Array = []


func before_each():
	heard = []
	watch = ThreatWatch.new()
	add_child_autofree(watch)
	watch.set_process(false)
	player = AgentScript.new()
	player.agent_type = "player"
	player.faction = "player"
	add_child_autofree(player)
	for name in ["hostile_detected", "hostile_aware", "threat_level_changed"]:
		EventBus.connect(name, self, "_heard", [name])


func after_each():
	for name in ["hostile_detected", "hostile_aware", "threat_level_changed"]:
		EventBus.disconnect(name, self, "_heard")


func _heard(what, name) -> void:
	heard.append([name, what])


func test_seen_then_aware_then_calm_again():
	var raider = AgentScript.new()
	raider.faction = "raiders"
	add_child_autofree(raider)
	raider.global_transform.origin = Vector3(0, 0, -500)
	watch.check(player, [raider])
	var names: Array = []
	for entry in heard:
		names.append(entry[0])
	assert_has(names, "hostile_detected")
	if raider.detects(player):
		assert_has(names, "hostile_aware")
		assert_eq(watch.level, "combat")
	heard.clear()
	watch.check(player, [raider])
	assert_eq(heard.size(), 0, "Said once, not every look")
	watch._combat_until = -INF
	watch.check(player, [])
	assert_eq(watch.level, "calm")
