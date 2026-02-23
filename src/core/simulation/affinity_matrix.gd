#
# PROJECT: GDTLancer
# MODULE: affinity_matrix.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_2
# LOG_REF: 2026-02-23
#

extends Reference
class_name AffinityMatrix

## Qualitative tag vocabulary and affinity scoring for the simulation.
## Pure read-only functions. No GameState mutation. No side effects.


# =========================================================================
# Tag vocabulary (single source of truth)
# =========================================================================

const SECTOR_ECONOMY_TAGS: Dictionary = {
	"RAW_MATERIALS": ["RAW_RICH", "RAW_ADEQUATE", "RAW_POOR"],
	"MANUFACTURED": ["MANUFACTURED_RICH", "MANUFACTURED_ADEQUATE", "MANUFACTURED_POOR"],
	"CURRENCY": ["CURRENCY_RICH", "CURRENCY_ADEQUATE", "CURRENCY_POOR"],
}

const SECTOR_SECURITY_TAGS: Array = ["SECURE", "CONTESTED", "LAWLESS"]
const SECTOR_ENVIRONMENT_TAGS: Array = ["MILD", "HARSH", "EXTREME"]
const SECTOR_SPECIAL_TAGS: Array = [
	"STATION", "FRONTIER", "HAS_SALVAGE", "DISABLED",
	"HOSTILE_INFESTED", "HOSTILE_THREATENED",
]

const AGENT_CONDITION_TAGS: Array = ["HEALTHY", "DAMAGED", "DESTROYED"]
const AGENT_WEALTH_TAGS: Array = ["WEALTHY", "COMFORTABLE", "BROKE"]
const AGENT_CARGO_TAGS: Array = ["LOADED", "EMPTY"]

const ROLE_TAGS: Dictionary = {
	"trader": "TRADER",
	"prospector": "PROSPECTOR",
	"military": "MILITARY",
	"hauler": "HAULER",
	"pirate": "PIRATE",
	"explorer": "EXPLORER",
	"idle": "IDLE",
}

const PERSONALITY_TAG_RULES: Array = [
	["greed", ">", 0.6, "GREEDY"],
	["aggression", ">", 0.5, "AGGRESSIVE"],
	["risk_tolerance", "<", 0.3, "COWARD"],
	["risk_tolerance", ">", 0.7, "BOLD"],
	["loyalty", ">", 0.6, "LOYAL"],
]

const DYNAMIC_AGENT_TAGS: Array = ["DESPERATE", "SCAVENGER"]


# =========================================================================
# Affinity matrix: [actor_tag, target_tag] -> score
# =========================================================================

# GDScript does not support Array keys in Dictionary literals, so we use
# a helper string key "actor_tag:target_tag" for O(1) lookup.
const AFFINITY_MATRIX: Dictionary = {
	# Pirate preferences
	"PIRATE:TRADER": 0.9,
	"PIRATE:HAULER": 0.8,
	"PIRATE:WEALTHY": 1.0,
	"PIRATE:LOADED": 1.2,
	"PIRATE:COMFORTABLE": 0.4,
	"PIRATE:DAMAGED": 0.9,
	"PIRATE:MILITARY": -1.2,
	"PIRATE:SECURE": -0.9,
	"PIRATE:LAWLESS": 1.0,
	"PIRATE:STATION": 0.3,
	"PIRATE:CURRENCY_RICH": 1.0,

	# Trader preferences
	"TRADER:STATION": 0.8,
	"TRADER:SECURE": 0.7,
	"TRADER:LAWLESS": -0.9,
	"TRADER:HOSTILE_INFESTED": -1.2,
	"TRADER:CURRENCY_RICH": 1.0,
	"TRADER:MANUFACTURED_RICH": 0.6,

	# Hauler preferences
	"HAULER:RAW_RICH": 0.9,
	"HAULER:MANUFACTURED_POOR": 0.8,
	"HAULER:STATION": 0.6,
	"HAULER:LAWLESS": -0.8,

	# Prospector / scavenger
	"PROSPECTOR:FRONTIER": 1.0,
	"PROSPECTOR:RAW_RICH": 1.2,
	"PROSPECTOR:HAS_SALVAGE": 1.1,
	"SCAVENGER:HAS_SALVAGE": 1.5,
	"SCAVENGER:EXTREME": -0.7,

	# Military behavior
	"MILITARY:HOSTILE_INFESTED": 1.5,
	"MILITARY:HOSTILE_THREATENED": 1.2,
	"MILITARY:LAWLESS": 1.0,
	"MILITARY:PIRATE": 1.4,
	"MILITARY:SECURE": -0.3,

	# Explorer behavior
	"EXPLORER:FRONTIER": 1.5,
	"EXPLORER:MILD": 0.4,
	"EXPLORER:EXTREME": -0.6,

	# Personality and condition interactions
	"AGGRESSIVE:DAMAGED": 1.1,
	"AGGRESSIVE:DESTROYED": -0.2,
	"AGGRESSIVE:LOADED": 0.5,
	"GREEDY:WEALTHY": 0.9,
	"GREEDY:LOADED": 0.6,
	"GREEDY:CURRENCY_RICH": 0.8,
	"BOLD:CONTESTED": 0.3,
	"BOLD:HARSH": 0.2,
	"COWARD:HOSTILE_INFESTED": -1.5,
	"COWARD:LAWLESS": -1.2,
	"COWARD:HARSH": -0.4,
	"LOYAL:MILITARY": 0.3,

	# Recovery / survival
	"DESPERATE:STATION": 1.5,
	"DESPERATE:SECURE": 0.8,
	"DAMAGED:STATION": 0.7,
	"BROKE:STATION": 0.6,
	"EMPTY:RAW_RICH": 0.6,
}


# =========================================================================
# Core scoring
# =========================================================================

## Computes the total affinity score between an actor's tags and a target's tags.
## Sums all matching (actor_tag, target_tag) pair scores from the AFFINITY_MATRIX.
func compute_affinity(actor_tags: Array, target_tags: Array) -> float:
	var score: float = 0.0
	for actor_tag in actor_tags:
		for target_tag in target_tags:
			var key: String = actor_tag + ":" + target_tag
			if AFFINITY_MATRIX.has(key):
				score += AFFINITY_MATRIX[key]
	return score


# =========================================================================
# Tag derivation
# =========================================================================

## Builds full tag list for an agent from character data, agent state, and cargo status.
func derive_agent_tags(character_data: Dictionary, agent_state: Dictionary, has_cargo: bool = false) -> Array:
	var tags: Array = []

	# Role tag
	var role: String = agent_state.get("agent_role", "idle")
	tags.append(ROLE_TAGS.get(role, "IDLE"))

	# Personality tags from character traits
	var traits: Dictionary = character_data.get("personality_traits", {})
	for rule in PERSONALITY_TAG_RULES:
		var trait_name: String = rule[0]
		var op: String = rule[1]
		var threshold: float = rule[2]
		var tag: String = rule[3]
		var value: float = traits.get(trait_name, 0.5)
		if op == ">" and value > threshold:
			tags.append(tag)
		elif op == "<" and value < threshold:
			tags.append(tag)

	# Condition, wealth, cargo tags
	var condition_tag: String = str(agent_state.get("condition_tag", "HEALTHY")).to_upper()
	var wealth_tag: String = str(agent_state.get("wealth_tag", "COMFORTABLE")).to_upper()
	var cargo_tag: String = str(agent_state.get("cargo_tag", "LOADED" if has_cargo else "EMPTY")).to_upper()

	if not (condition_tag in AGENT_CONDITION_TAGS):
		condition_tag = "HEALTHY"
	if not (wealth_tag in AGENT_WEALTH_TAGS):
		wealth_tag = "COMFORTABLE"
	if not (cargo_tag in AGENT_CARGO_TAGS):
		cargo_tag = "LOADED" if has_cargo else "EMPTY"

	tags.append(condition_tag)
	tags.append(wealth_tag)
	tags.append(cargo_tag)

	if has_cargo and cargo_tag == "EMPTY":
		tags.append("LOADED")

	# Dynamic tags
	var dynamic_tags: Array = agent_state.get("dynamic_tags", [])
	for dtag in DYNAMIC_AGENT_TAGS:
		if dtag in dynamic_tags:
			tags.append(dtag)

	# Derived dynamic tags
	if condition_tag == "DAMAGED" and wealth_tag == "BROKE":
		tags.append("DESPERATE")

	if role == "prospector":
		tags.append("SCAVENGER")

	return _unique(tags)


## Rebuilds sector tags from topology, disabled state, security, environment, economy, hostile consistency.
func derive_sector_tags(sector_id: String, state) -> Array:
	var existing: Array = Array(state.sector_tags.get(sector_id, []))
	var tags_set: Dictionary = {}
	for tag in existing:
		tags_set[tag] = true

	var topology: Dictionary = state.world_topology.get(sector_id, {})
	var hazards: Dictionary = state.world_hazards.get(sector_id, {})
	var dominion: Dictionary = state.grid_dominion.get(sector_id, {})
	var disabled_until: int = state.sector_disabled_until.get(sector_id, 0)
	var tick: int = state.sim_tick_count

	# Station / Frontier
	if topology.get("sector_type", "") == "frontier":
		tags_set["FRONTIER"] = true
	else:
		tags_set["STATION"] = true

	# Disabled
	if disabled_until > 0 and tick < disabled_until:
		tags_set["DISABLED"] = true

	# Security
	var security_tag: String = _pick_security_tag(tags_set, dominion)
	for sec_tag in SECTOR_SECURITY_TAGS:
		tags_set.erase(sec_tag)
	tags_set[security_tag] = true

	# Environment
	var env_tag: String = _pick_environment_tag(hazards, tags_set)
	for e_tag in SECTOR_ENVIRONMENT_TAGS:
		tags_set.erase(e_tag)
	tags_set[env_tag] = true

	# Economy
	var all_economy_tags: Dictionary = {}
	for category in SECTOR_ECONOMY_TAGS:
		for etag in SECTOR_ECONOMY_TAGS[category]:
			all_economy_tags[etag] = true
	var economy_tags: Array = _pick_economy_tags(tags_set)
	for old_etag in all_economy_tags:
		tags_set.erase(old_etag)
	for new_etag in economy_tags:
		tags_set[new_etag] = true

	# Hostile consistency
	var hostile: bool = tags_set.has("HOSTILE_INFESTED") or tags_set.has("HOSTILE_THREATENED")
	if hostile and security_tag == "SECURE":
		tags_set.erase("HOSTILE_INFESTED")
		tags_set["HOSTILE_THREATENED"] = true

	# Legacy tag migration
	if tags_set.has("HAS_WRECKS"):
		tags_set.erase("HAS_WRECKS")
		tags_set["HAS_SALVAGE"] = true

	return _unique(tags_set.keys())


# =========================================================================
# Helpers
# =========================================================================

func _pick_security_tag(existing: Dictionary, dominion: Dictionary) -> String:
	for label in SECTOR_SECURITY_TAGS:
		if existing.has(label):
			return label

	var security_level = dominion.get("security_level")
	if security_level != null and (security_level is float or security_level is int):
		if security_level >= 0.65:
			return "SECURE"
		if security_level <= 0.35:
			return "LAWLESS"
	return "CONTESTED"


func _pick_environment_tag(hazards: Dictionary, existing: Dictionary) -> String:
	for label in SECTOR_ENVIRONMENT_TAGS:
		if existing.has(label):
			return label

	if hazards is Dictionary:
		var radiation: float = float(hazards.get("radiation_level", 0.0))
		var thermal: float = abs(float(hazards.get("thermal_background_k", 0.0)))
		var severity: float = radiation + (thermal / 1000.0)
		if severity > 0.35:
			return "EXTREME"
		if severity > 0.12:
			return "HARSH"
	return "MILD"


func _pick_economy_tags(existing: Dictionary) -> Array:
	var tags: Array = []
	for category in SECTOR_ECONOMY_TAGS:
		var options: Array = SECTOR_ECONOMY_TAGS[category]
		var found: bool = false
		for option in options:
			if existing.has(option):
				tags.append(option)
				found = true
				break
		if not found:
			if category == "RAW_MATERIALS":
				tags.append("RAW_ADEQUATE")
			elif category == "MANUFACTURED":
				tags.append("MANUFACTURED_ADEQUATE")
			else:
				tags.append("CURRENCY_ADEQUATE")
	return tags


func _unique(values: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for value in values:
		if not seen.has(value):
			seen[value] = true
			result.append(value)
	return result
