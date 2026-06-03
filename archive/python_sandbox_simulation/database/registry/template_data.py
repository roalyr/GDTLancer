#
# PROJECT: GDTLancer
# MODULE: template_data.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_6
# LOG_REF: 2026-02-21 (TASK_5)
#

"""Tag-based template registry for qualitative simulation mode."""

# -------------------------------------------------------------------------
# Locations
# -------------------------------------------------------------------------
# STARTING TOPOLOGY (5 sectors, 5 edges, avg degree = 2.0)
#
#   beta ---- alpha
#     \       /
#      delta ---- gamma ---- epsilon
#
# Core triangle: alpha(colony), beta(colony), delta(colony)
# Frontier tail:  delta -> gamma(frontier) -> epsilon(outpost)
# All connections are bidirectional.
# Degrees: alpha=2, beta=2, gamma=2, delta=3, epsilon=1
# -------------------------------------------------------------------------
LOCATIONS = {
    "station_alpha": {
        "location_name": "Station Alpha - Mining Hub",
        "location_type": "station",
        "connections": ["station_beta", "station_delta"],
        "sector_type": "colony",
        "available_services": ["trade", "contracts", "repair"],
        "controlling_faction_id": "faction_miners",
        "initial_sector_tags": [
            "STATION",
            "SECURE",
            "MILD",
            "RAW_RICH",
            "MANUFACTURED_ADEQUATE",
            "CURRENCY_ADEQUATE",
        ],
    },
    "station_beta": {
        "location_name": "Station Beta - Trade Post",
        "location_type": "station",
        "connections": ["station_alpha", "station_delta"],
        "sector_type": "colony",
        "available_services": ["trade", "contracts"],
        "controlling_faction_id": "faction_traders",
        "initial_sector_tags": [
            "STATION",
            "SECURE",
            "MILD",
            "RAW_POOR",
            "MANUFACTURED_RICH",
            "CURRENCY_RICH",
        ],
    },
    "station_gamma": {
        "location_name": "Freeport Gamma",
        "location_type": "station",
        "connections": ["station_delta", "station_epsilon"],
        "sector_type": "frontier",
        "available_services": ["trade", "contracts", "black_market"],
        "controlling_faction_id": "faction_independents",
        "initial_sector_tags": [
            "FRONTIER",
            "LAWLESS",
            "HARSH",
            "RAW_ADEQUATE",
            "MANUFACTURED_POOR",
            "CURRENCY_ADEQUATE",
            "HOSTILE_THREATENED",
        ],
    },
    "station_delta": {
        "location_name": "Outpost Delta - Military Garrison",
        "location_type": "station",
        "connections": ["station_beta", "station_gamma", "station_alpha"],
        "sector_type": "colony",
        "available_services": ["trade", "repair", "contracts"],
        "controlling_faction_id": "faction_military",
        "initial_sector_tags": [
            "STATION",
            "SECURE",
            "MILD",
            "RAW_ADEQUATE",
            "MANUFACTURED_RICH",
            "CURRENCY_ADEQUATE",
        ],
    },
    "station_epsilon": {
        "location_name": "Epsilon Refinery Complex",
        "location_type": "station",
        "connections": ["station_gamma"],
        "sector_type": "outpost",
        "available_services": ["trade", "repair", "contracts"],
        "controlling_faction_id": "faction_miners",
        "initial_sector_tags": [
            "STATION",
            "CONTESTED",
            "HARSH",
            "RAW_RICH",
            "MANUFACTURED_ADEQUATE",
            "CURRENCY_ADEQUATE",
        ],
    },
}


# -------------------------------------------------------------------------
# Factions
# -------------------------------------------------------------------------
FACTIONS = {
    "faction_miners": {
        "display_name": "Miners Guild",
        "description": "A collective of independent miners and ore processors.",
        "default_standing": 0,
    },
    "faction_traders": {
        "display_name": "Trade Alliance",
        "description": "The dominant commercial entity in the sector.",
        "default_standing": 0,
    },
    "faction_independents": {
        "display_name": "Independent Captains",
        "description": "Unaffiliated pilots operating on their own terms.",
        "default_standing": 0,
    },
    "faction_military": {
        "display_name": "Military Corps",
        "description": "A disciplined military force maintaining order.",
        "default_standing": 0,
    },
    "faction_pirates": {
        "display_name": "Pirate Syndicate",
        "description": "Opportunistic raiders who thrive in chaos and lawless sectors.",
        "default_standing": -50,
    },
}


# -------------------------------------------------------------------------
# Characters
# -------------------------------------------------------------------------
CHARACTERS = {
    "character_default": {
        "character_name": "Unnamed",
        "faction_id": "faction_default",
        "personality_traits": {},
        "description": "",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_vera": {
        "character_name": "Vera",
        "faction_id": "faction_traders",
        "personality_traits": {"risk_tolerance": 0.2, "greed": 0.5},
        "description": "Merchant captain, cautious.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "WEALTHY",
    },
    "character_ada": {
        "character_name": "Ada",
        "faction_id": "faction_independents",
        "personality_traits": {"risk_tolerance": 0.5, "aggression": 0.1},
        "description": "Salvager, resourceful.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_juno": {
        "character_name": "Juno",
        "faction_id": "faction_miners",
        "personality_traits": {"risk_tolerance": 0.8, "greed": 0.7},
        "description": "Young prospector, ambitious.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "BROKE",
    },
    "character_kai": {
        "character_name": "Kai",
        "faction_id": "faction_miners",
        "personality_traits": {"risk_tolerance": 0.3, "loyalty": 0.8},
        "description": "Veteran miner, pragmatic.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_milo": {
        "character_name": "Milo",
        "faction_id": "faction_traders",
        "personality_traits": {"greed": 0.7, "aggression": 0.2},
        "description": "Cargo hauler, opportunistic.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_rex": {
        "character_name": "Rex",
        "faction_id": "faction_independents",
        "personality_traits": {"risk_tolerance": 0.9, "loyalty": 0.2},
        "description": "Freelancer pilot, risky.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "BROKE",
    },
    "character_siv": {
        "character_name": "Siv",
        "faction_id": "faction_military",
        "personality_traits": {"risk_tolerance": 0.4, "loyalty": 0.9, "greed": 0.6},
        "description": "Military supply officer, disciplined.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_zara": {
        "character_name": "Zara",
        "faction_id": "faction_miners",
        "personality_traits": {"risk_tolerance": 0.7, "greed": 0.4},
        "description": "Survey specialist, maps deposits.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_nyx": {
        "character_name": "Nyx",
        "faction_id": "faction_military",
        "personality_traits": {"risk_tolerance": 0.3, "loyalty": 0.8, "aggression": 0.4},
        "description": "Patrol officer, keeps order.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_orin": {
        "character_name": "Orin",
        "faction_id": "faction_traders",
        "personality_traits": {"risk_tolerance": 0.2, "greed": 0.3, "loyalty": 0.6},
        "description": "Bulk cargo hauler, reliable.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_crow": {
        "character_name": "Crow",
        "faction_id": "faction_pirates",
        "personality_traits": {"risk_tolerance": 0.9, "greed": 0.8, "aggression": 0.7},
        "description": "Ruthless raider, exploits disruption.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_vex": {
        "character_name": "Vex",
        "faction_id": "faction_pirates",
        "personality_traits": {"risk_tolerance": 0.8, "greed": 0.9, "aggression": 0.5},
        "description": "Cunning smuggler turned pirate.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_nova": {
        "character_name": "Nova",
        "faction_id": "faction_independents",
        "personality_traits": {"risk_tolerance": 0.9, "loyalty": 0.3},
        "description": "Deep-space explorer, restless.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
}


# -------------------------------------------------------------------------
# Agents
# -------------------------------------------------------------------------
AGENTS = {
    "agent_player_default": {
        "agent_type": "player",
        "is_persistent": False,
        "home_location_id": "",
        "character_template_id": "",
        "agent_role": "idle",
        "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"],
    },
    "persistent_vera": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_beta", "character_template_id": "character_vera", "agent_role": "trader", "initial_tags": ["HEALTHY", "WEALTHY", "LOADED"]},
    "persistent_milo": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_beta", "character_template_id": "character_milo", "agent_role": "trader", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_juno": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_alpha", "character_template_id": "character_juno", "agent_role": "prospector", "initial_tags": ["HEALTHY", "BROKE", "EMPTY"]},
    "persistent_zara": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_epsilon", "character_template_id": "character_zara", "agent_role": "prospector", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
    "persistent_siv": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_delta", "character_template_id": "character_siv", "agent_role": "military", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
    "persistent_nyx": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_delta", "character_template_id": "character_nyx", "agent_role": "military", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
    "persistent_kai": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_alpha", "character_template_id": "character_kai", "agent_role": "hauler", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_orin": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_epsilon", "character_template_id": "character_orin", "agent_role": "hauler", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_ada": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_ada", "agent_role": "trader", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
    "persistent_rex": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_rex", "agent_role": "hauler", "initial_tags": ["HEALTHY", "BROKE", "EMPTY"]},
    "persistent_crow": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_crow", "agent_role": "pirate", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_vex": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_vex", "agent_role": "pirate", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_nova": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_nova", "agent_role": "explorer", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
}
