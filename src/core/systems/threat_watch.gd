# ThreatWatch: how dangerous the player's situation is, for the sound and music (and anything else
# that cues the player). Every THREAT_WATCH_INTERVAL s it looks at the hostile ships the player's
# sensors see (ThreatRing.threats: within THREAT_RANGE, Agent.is_enemy_of) and says on EventBus:
#   hostile_detected(ship): a hostile has come onto the sensors (once per ship per THREAT_NOTICE_COOLDOWN s);
#   hostile_aware(ship):    a seen hostile has detected the player (Agent.detects, as NPCs go by), likewise;
#   threat_level_changed(level): "calm" (no hostile seen), "danger" (hostiles seen, none sees the
#     player) or "combat" (one sees it, or it took damage within THREAT_COMBAT_HOLD s); combat holds
#     THREAT_COMBAT_HOLD s after the last of that, so the music does not flutter.
# It is the player's side of what NPCs read off their own sensors (player/NPC parity): the facts
# as cues, not numbers. The main HUD runs one.

extends Node

const ThreatRing = preload("res://src/core/ui/main_hud/threat_ring.gd")

var level: String = "calm"
var _seen: Dictionary = {}  # Ship instance id -> true while on the sensors
var _aware: Dictionary = {}  # Ship instance id -> true while it sees the player
var _noticed: Dictionary = {}  # "seen:id" / "aware:id" -> OS ticks (ms) it was last announced
var _left: float = 0.0
var _combat_until: float = -INF  # OS ticks (s)


func _ready() -> void:
	EventBus.connect("agent_damaged", self, "_on_agent_damaged")


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = Constants.THREAT_WATCH_INTERVAL
	check(GlobalRefs.player_agent_body, get_tree().get_nodes_in_group("agent_body"))


# One look: notices for ships newly seen or newly aware, then the level.
func check(player, bodies: Array) -> void:
	var seen := {}
	var aware := {}
	var now: float = OS.get_ticks_msec() / 1000.0
	if is_instance_valid(player) and not player.get("is_docked") and not player.get("is_wreck"):
		for ship in ThreatRing.threats(player, bodies):
			var id: int = ship.get_instance_id()
			seen[id] = true
			if not _seen.has(id) and _notice("seen:%d" % id, now):
				EventBus.emit_signal("hostile_detected", ship)
			if ship.has_method("detects") and ship.detects(player):
				aware[id] = true
				_combat_until = now + Constants.THREAT_COMBAT_HOLD
				if not _aware.has(id) and _notice("aware:%d" % id, now):
					EventBus.emit_signal("hostile_aware", ship)
	_seen = seen
	_aware = aware
	var next: String = "combat" if now < _combat_until else ("danger" if not seen.empty() else "calm")
	if next != level:
		level = next
		EventBus.emit_signal("threat_level_changed", level)


func _notice(key: String, now: float) -> bool:
	if now - float(_noticed.get(key, -INF)) < Constants.THREAT_NOTICE_COOLDOWN:
		return false
	_noticed[key] = now
	return true


func _on_agent_damaged(body, _amount, source) -> void:
	if body == GlobalRefs.player_agent_body and is_instance_valid(source) and source != body:
		_combat_until = OS.get_ticks_msec() / 1000.0 + Constants.THREAT_COMBAT_HOLD
