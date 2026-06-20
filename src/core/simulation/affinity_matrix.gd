# PROJECT: GDTLancer
# MODULE: affinity_matrix.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: affinity_matrix.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6.4; TACTICAL_TODO.md TASK_4
# LOG_REF: 2026-05-23 23:11:32
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
const SECTOR_LEGALITY_TAGS: Array = ["LEGAL_LAWFUL", "LEGAL_TOLERATED", "LEGAL_ILLICIT"]
const SECTOR_SPECIAL_TAGS: Array = [
	"STATION", "FRONTIER", "HAS_SALVAGE", "DISABLED",
	"HOSTILE_INFESTED", "HOSTILE_THREATENED",
	"CONTRACT_DEMAND_RAW", "CONTRACT_DEMAND_MANUFACTURED", "CONTRACT_DEMAND_CURRENCY",
	"RELIEF_NEEDED", "TRADE_LANE_ACTIVE",
]

const AGENT_CONDITION_TAGS: Array = ["HEALTHY", "DAMAGED", "DESTROYED"]
const AGENT_WEALTH_TAGS: Array = ["WEALTHY", "COMFORTABLE", "BROKE"]
const AGENT_CARGO_TAGS: Array = ["LOADED", "EMPTY"]
const CARGO_PROVENANCE_TAGS: Array = ["CARGO_CONTRACT", "CARGO_MARKET", "CARGO_EXTRACTED", "CARGO_SALVAGE"]
const CARGO_LEGALITY_TAGS: Array = ["CARGO_PROTECTED", "CARGO_LAWFUL", "CARGO_TOLERATED", "CARGO_ILLICIT"]
const AGENT_CONTEXT_TAGS: Array = ["HAS_CONTRACT_CLAIM"]
const FACTION_TAG_PREFIX: String = "FACTION_"
const UNALIGNED_FACTION_TAG: String = "FACTION_UNALIGNED"

const ROLE_TAGS: Dictionary = {
	"trader": "TRADER",
	"prospector": "PROSPECTOR",
	"patrol": "PATROL",
	"hauler": "HAULER",
	"pirate": "PIRATE",
	"surveyor": "SURVEYOR",
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
	"PIRATE:PATROL": -1.2,
	"PIRATE:SECURE": -0.9,
	"PIRATE:LAWLESS": 1.0,
	"PIRATE:LEGAL_LAWFUL": -0.6,
	"PIRATE:LEGAL_ILLICIT": 0.4,
	"PIRATE:STATION": 0.3,
	"PIRATE:CARGO_PROTECTED": 0.8,
	"PIRATE:CARGO_MARKET": 0.3,
	"PIRATE:CURRENCY_RICH": 1.0,

	# Trader preferences
	"TRADER:STATION": 0.8,
	"TRADER:SECURE": 0.7,
	"TRADER:LAWLESS": -0.9,
	"TRADER:LEGAL_LAWFUL": 0.4,
	"TRADER:LEGAL_ILLICIT": -0.8,
	"TRADER:HOSTILE_INFESTED": -1.2,
	"TRADER:CARGO_MARKET": 0.3,
	"TRADER:CARGO_ILLICIT": -0.7,
	"TRADER:CARGO_PROTECTED": -0.2,
	"TRADER:CURRENCY_RICH": 1.0,
	"TRADER:MANUFACTURED_RICH": 0.6,
	"TRADER:CONTRACT_DEMAND_CURRENCY": 1.1,
	"TRADER:CONTRACT_DEMAND_MANUFACTURED": 0.9,
	"TRADER:CONTRACT_DEMAND_RAW": 0.4,
	"TRADER:RELIEF_NEEDED": 0.7,

	# Hauler preferences
	"HAULER:RAW_RICH": 0.9,
	"HAULER:MANUFACTURED_POOR": 0.8,
	"HAULER:STATION": 0.6,
	"HAULER:LAWLESS": -0.8,
	"HAULER:LEGAL_LAWFUL": 0.3,
	"HAULER:CARGO_EXTRACTED": 0.4,
	"HAULER:CARGO_PROTECTED": 0.5,
	"HAULER:CONTRACT_DEMAND_RAW": 1.1,
	"HAULER:CONTRACT_DEMAND_MANUFACTURED": 0.8,
	"HAULER:CONTRACT_DEMAND_CURRENCY": 0.3,
	"HAULER:RELIEF_NEEDED": 0.6,

	# Prospector / scavenger
	"PROSPECTOR:FRONTIER": 1.0,
	"PROSPECTOR:RAW_RICH": 1.2,
	"PROSPECTOR:HAS_SALVAGE": 1.1,
	"SCAVENGER:HAS_SALVAGE": 1.5,
	"SCAVENGER:EXTREME": -0.7,

	# Patrol behavior
	"PATROL:HOSTILE_INFESTED": 1.5,
	"PATROL:HOSTILE_THREATENED": 1.2,
	"PATROL:LAWLESS": 1.0,
	"PATROL:LEGAL_ILLICIT": 0.8,
	"PATROL:CARGO_ILLICIT": 0.9,
	"PATROL:CARGO_PROTECTED": 0.2,
	"PATROL:PIRATE": 1.4,
	"PATROL:SECURE": -0.3,

	# Surveyor behavior
	"SURVEYOR:FRONTIER": 1.5,
	"SURVEYOR:MILD": 0.4,
	"SURVEYOR:EXTREME": -0.6,

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
	"LOYAL:PATROL": 0.3,

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
			var actor_label: String = str(actor_tag)
			var target_label: String = str(target_tag)
			var key: String = actor_label + ":" + target_label
			if AFFINITY_MATRIX.has(key):
				score += AFFINITY_MATRIX[key]
			score += _dynamic_affinity_bonus(actor_label, target_label)
	return score


# =========================================================================
# Tag derivation
# =========================================================================

## Builds full tag list for an agent from character data, agent state, and cargo status.
func derive_agent_tags(character_data: Dictionary, agent_state: Dictionary, has_cargo: bool = false) -> Array:
	var tags: Array = []

	# Role tag
	var role: String = str(agent_state.get("agent_role", "idle"))
	tags.append(ROLE_TAGS.get(role, "IDLE"))
	tags.append(build_faction_tag(str(character_data.get("faction_id", agent_state.get("faction_id", "")))))

	var current_sector_tags: Array = Array(agent_state.get("current_sector_tags", []))
	var sector_legality_tag: String = derive_sector_legality_tag(current_sector_tags)
	var explicit_sector_legality_tag: String = _normalize_tag_candidate(
		agent_state.get("sector_legality_tag", ""),
		"LEGAL_",
		SECTOR_LEGALITY_TAGS
	)
	if explicit_sector_legality_tag != "":
		sector_legality_tag = explicit_sector_legality_tag

	var agent_legality_tag: String = _derive_agent_legality_tag(role, agent_state, sector_legality_tag)
	if agent_legality_tag != "":
		tags.append(agent_legality_tag)

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

	var cargo_provenance_tag: String = _derive_cargo_provenance_tag(agent_state, role, cargo_tag, has_cargo)
	if cargo_provenance_tag != "":
		tags.append(cargo_provenance_tag)
		var cargo_legality_tag: String = _derive_cargo_legality_tag(
			agent_state,
			role,
			sector_legality_tag,
			cargo_provenance_tag
		)
		if cargo_legality_tag != "":
			tags.append(cargo_legality_tag)

	for context_tag in AGENT_CONTEXT_TAGS:
		if context_tag == "HAS_CONTRACT_CLAIM" and bool(agent_state.get("has_active_contract_claim", false)):
			tags.append(context_tag)

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

	# Faction / legality context
	_erase_tags_with_prefix(tags_set, FACTION_TAG_PREFIX)
	tags_set[build_faction_tag(str(dominion.get("controlling_faction_id", "")))] = true
	for legality_tag in SECTOR_LEGALITY_TAGS:
		tags_set.erase(legality_tag)
	tags_set[_security_to_legality_tag(security_tag)] = true

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


func build_faction_tag(faction_id: String) -> String:
	var normalized_suffix: String = _normalize_faction_suffix(faction_id)
	if normalized_suffix == "":
		return UNALIGNED_FACTION_TAG
	return "%s%s" % [FACTION_TAG_PREFIX, normalized_suffix]


func derive_sector_legality_tag(sector_tags: Array) -> String:
	for legality_tag in SECTOR_LEGALITY_TAGS:
		if legality_tag in sector_tags:
			return legality_tag
	if "SECURE" in sector_tags:
		return "LEGAL_LAWFUL"
	if "LAWLESS" in sector_tags:
		return "LEGAL_ILLICIT"
	return "LEGAL_TOLERATED"


func derive_sector_faction_tag(sector_tags: Array) -> String:
	for tag in sector_tags:
		var label: String = str(tag)
		if label.begins_with(FACTION_TAG_PREFIX):
			return label
	return UNALIGNED_FACTION_TAG


# =========================================================================
# Helpers
# =========================================================================

func _dynamic_affinity_bonus(actor_tag: String, target_tag: String) -> float:
	if actor_tag.begins_with(FACTION_TAG_PREFIX) and target_tag.begins_with(FACTION_TAG_PREFIX):
		if actor_tag == target_tag and actor_tag != UNALIGNED_FACTION_TAG:
			return 0.35
		if actor_tag != UNALIGNED_FACTION_TAG and target_tag != UNALIGNED_FACTION_TAG:
			return -0.1
		return 0.0

	if actor_tag.begins_with("LEGAL_") and target_tag.begins_with("LEGAL_"):
		if actor_tag == target_tag:
			return 0.1 if actor_tag == "LEGAL_ILLICIT" else 0.2
		if actor_tag == "LEGAL_LAWFUL" and target_tag == "LEGAL_ILLICIT":
			return -0.6
		if actor_tag == "LEGAL_ILLICIT" and target_tag == "LEGAL_LAWFUL":
			return -0.45
		return -0.15

	return 0.0


func _derive_agent_legality_tag(role: String, agent_state: Dictionary, sector_legality_tag: String) -> String:
	var explicit_legality_tag: String = _normalize_tag_candidate(
		agent_state.get("legality_tag", ""),
		"LEGAL_",
		SECTOR_LEGALITY_TAGS
	)
	if explicit_legality_tag != "":
		return explicit_legality_tag
	if role == "pirate":
		return "LEGAL_ILLICIT"
	if role == "patrol":
		return "LEGAL_LAWFUL"
	if bool(agent_state.get("has_active_contract_claim", false)):
		return "LEGAL_LAWFUL"
	if role in ["trader", "hauler"] and sector_legality_tag == "LEGAL_ILLICIT":
		return "LEGAL_TOLERATED"
	if sector_legality_tag != "":
		return sector_legality_tag
	return "LEGAL_TOLERATED"


func _derive_cargo_provenance_tag(agent_state: Dictionary, role: String, cargo_tag: String, has_cargo: bool) -> String:
	if cargo_tag != "LOADED" and not has_cargo:
		return ""
	var explicit_provenance_tag: String = _normalize_tag_candidate(
		agent_state.get("cargo_provenance_tag", ""),
		"CARGO_",
		CARGO_PROVENANCE_TAGS
	)
	if explicit_provenance_tag != "":
		return explicit_provenance_tag
	if str(agent_state.get("contract_cargo_tag", "")) != "" or bool(agent_state.get("has_active_contract_claim", false)):
		return "CARGO_CONTRACT"
	match role:
		"pirate":
			return "CARGO_SALVAGE"
		"hauler", "prospector":
			return "CARGO_EXTRACTED"
		"trader":
			return "CARGO_MARKET"
	return "CARGO_MARKET"


func _derive_cargo_legality_tag(agent_state: Dictionary, role: String, sector_legality_tag: String, cargo_provenance_tag: String) -> String:
	if cargo_provenance_tag == "":
		return ""
	var explicit_cargo_legality_tag: String = _normalize_tag_candidate(
		agent_state.get("cargo_legality_tag", ""),
		"CARGO_",
		CARGO_LEGALITY_TAGS
	)
	if explicit_cargo_legality_tag != "":
		return explicit_cargo_legality_tag
	if cargo_provenance_tag == "CARGO_CONTRACT":
		return "CARGO_PROTECTED"
	if role == "pirate":
		return "CARGO_ILLICIT"
	match sector_legality_tag:
		"LEGAL_LAWFUL":
			return "CARGO_LAWFUL"
		"LEGAL_ILLICIT":
			return "CARGO_ILLICIT"
	return "CARGO_TOLERATED"


func _normalize_tag_candidate(raw_value, prefix: String, allowed_tags: Array) -> String:
	var normalized: String = str(raw_value).strip_edges().to_upper()
	if normalized == "":
		return ""
	if normalized in allowed_tags:
		return normalized
	var prefixed: String = "%s%s" % [prefix, normalized]
	if prefixed in allowed_tags:
		return prefixed
	return ""


func _normalize_faction_suffix(raw_faction_id) -> String:
	var faction_id: String = str(raw_faction_id).strip_edges().to_lower()
	if faction_id == "" or faction_id == "faction_default":
		return ""
	if faction_id.begins_with("faction_"):
		faction_id = faction_id.substr(8, faction_id.length() - 8)
	faction_id = faction_id.replace("-", "_").replace(" ", "_").to_upper()
	return faction_id


func _security_to_legality_tag(security_tag: String) -> String:
	match security_tag:
		"SECURE":
			return "LEGAL_LAWFUL"
		"LAWLESS":
			return "LEGAL_ILLICIT"
	return "LEGAL_TOLERATED"


func _erase_tags_with_prefix(tags_set: Dictionary, prefix: String) -> void:
	var keys: Array = tags_set.keys()
	for key in keys:
		var label: String = str(key)
		if label.begins_with(prefix):
			tags_set.erase(key)

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