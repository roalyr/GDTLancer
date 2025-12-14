# File: autoload/NarrativeOutcomes.gd
# Autoload Singleton: NarrativeOutcomes
# Purpose: Centralized narrative outcome lookup tables for Narrative Actions.
# Version: 1.0

extends Node

# Outcome structure per action_type + tier
# Returns: {description: String, effects: Dictionary}
# effects keys: "add_quirk", "wp_cost", "wp_gain", "fp_gain", "reputation_change"

const OUTCOMES: Dictionary = {
	"contract_complete": {
		"CritSuccess": {
			"description": "Flawless delivery - client impressed.",
			"effects": {"wp_gain": 5, "reputation_change": 1}
		},
		"SwC": {
			"description": "Delivery complete with minor issues.",
			"effects": {}
		},
		"Failure": {
			"description": "Cargo damaged in transit.",
			"effects": {"wp_cost": 10, "add_quirk": "reputation_tarnished"}
		}
	},

	"dock_arrival": {
		"CritSuccess": {
			"description": "Perfect approach and docking. Your handling inspires confidence.",
			"effects": {"fp_gain": 1, "reputation_change": 1}
		},
		"SwC": {
			"description": "Docking successful, but you scrape the hull on the way in.",
			"effects": {"add_quirk": "scratched_hull"}
		},
		"Failure": {
			"description": "Rough landing. Repairs and paperwork cost you.",
			"effects": {"wp_cost": 2, "add_quirk": "jammed_landing_gear"}
		}
	},

	"trade_finalize": {
		"CritSuccess": {
			"description": "You spot a favorable clause and close the deal above market.",
			"effects": {"wp_gain": 2}
		},
		"SwC": {
			"description": "Deal goes through, but the station broker takes a cut.",
			"effects": {"wp_cost": 1}
		},
		"Failure": {
			"description": "You misread the market and take a loss finalizing the trade.",
			"effects": {"wp_cost": 3}
		}
	}
}


func get_outcome(action_type: String, tier_name: String) -> Dictionary:
	var normalized_tier = _normalize_tier_name(tier_name)
	var action_table = OUTCOMES.get(action_type, null)
	if action_table == null:
		return {"description": "No outcome defined.", "effects": {}}
	var outcome = action_table.get(normalized_tier, null)
	if outcome == null:
		return {"description": "No outcome defined.", "effects": {}}
	# Return a deep copy so callers can safely modify.
	return outcome.duplicate(true)


func get_available_action_types() -> Array:
	var keys = OUTCOMES.keys()
	keys.sort()
	return keys


func _normalize_tier_name(tier_name: String) -> String:
	# Supports both CoreMechanicsAPI keys (result_tier) and display strings (tier_name).
	match tier_name:
		"CritSuccess", "Critical Success":
			return "CritSuccess"
		"SwC", "Success with Complication":
			return "SwC"
		"Failure":
			return "Failure"
		_:
			# Best-effort: pass through; may already be correct.
			return tier_name
