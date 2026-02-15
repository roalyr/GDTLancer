"""
GDTLancer Template Data.
Hardcoded data that mirrors the .tres registry files in database/registry/.
Replaces TemplateDatabase autoload from Godot.

PROJECT: GDTLancer
MODULE: database/registry/template_data.py
STATUS: Level 2 - Implementation
TRUTH_LINK: database/registry/*.tres
"""

# =========================================================================
# === LOCATIONS ===========================================================
# =========================================================================

LOCATIONS = {
    "station_alpha": {
        "location_name": "Station Alpha - Mining Hub",
        "location_type": "station",
        "connections": ["station_beta", "station_gamma", "station_delta"],
        "sector_type": "hub",
        "radiation_level": 0.05,
        "thermal_background_k": 280.0,
        "gravity_well_penalty": 1.2,
        "mineral_density": 20.0,
        "propellant_sources": 10.3,
        "station_power_output": 150.0,
        "stockpile_capacity": 1500,
        "market_inventory": {
            "commodity_ore":     {"buy_price": 8,  "sell_price": 6,  "quantity": 200},
            "commodity_food":    {"buy_price": 30, "sell_price": 25, "quantity": 40},
            "commodity_tech":    {"buy_price": 80, "sell_price": 65, "quantity": 15},
            "commodity_fuel":    {"buy_price": 25, "sell_price": 20, "quantity": 100},
            "commodity_specie":  {"buy_price": 1,  "sell_price": 1,  "quantity": 200},
        },
        "available_services": ["trade", "contracts", "repair"],
        "controlling_faction_id": "faction_miners",
        "danger_level": 1,
    },
    "station_beta": {
        "location_name": "Station Beta - Trade Post",
        "location_type": "station",
        "connections": ["station_alpha", "station_delta"],
        "sector_type": "hub",
        "radiation_level": 0.01,
        "thermal_background_k": 310.0,
        "gravity_well_penalty": 1.0,
        "mineral_density": 0.3,
        "propellant_sources": 0.8,
        "station_power_output": 120.0,
        "stockpile_capacity": 1200,
        "market_inventory": {
            "commodity_ore":     {"buy_price": 15, "sell_price": 12, "quantity": 30},
            "commodity_food":    {"buy_price": 22, "sell_price": 18, "quantity": 80},
            "commodity_tech":    {"buy_price": 70, "sell_price": 55, "quantity": 50},
            "commodity_fuel":    {"buy_price": 30, "sell_price": 25, "quantity": 60},
            "commodity_luxury":  {"buy_price": 90, "sell_price": 75, "quantity": 20},
            "commodity_specie":  {"buy_price": 1,  "sell_price": 1,  "quantity": 200},
        },
        "available_services": ["trade", "contracts"],
        "controlling_faction_id": "faction_traders",
        "danger_level": 2,
    },
    "station_gamma": {
        "location_name": "Freeport Gamma",
        "location_type": "station",
        "connections": ["station_alpha", "station_delta"],
        "sector_type": "frontier",
        "radiation_level": 0.15,
        "thermal_background_k": 250.0,
        "gravity_well_penalty": 1.5,
        "mineral_density": 0.8,
        "propellant_sources": 1.2,
        "station_power_output": 80.0,
        "stockpile_capacity": 800,
        "market_inventory": {
            "commodity_ore":     {"buy_price": 12, "sell_price": 10, "quantity": 80},
            "commodity_food":    {"buy_price": 25, "sell_price": 20, "quantity": 60},
            "commodity_tech":    {"buy_price": 55, "sell_price": 45, "quantity": 30},
            "commodity_fuel":    {"buy_price": 20, "sell_price": 15, "quantity": 150},
            "commodity_luxury":  {"buy_price": 120, "sell_price": 100, "quantity": 10},
            "commodity_specie":  {"buy_price": 1,  "sell_price": 1,  "quantity": 200},
        },
        "available_services": ["trade", "contracts", "black_market"],
        "controlling_faction_id": "faction_independents",
        "danger_level": 4,
    },
    "station_delta": {
        "location_name": "Outpost Delta - Military Garrison",
        "location_type": "station",
        "connections": ["station_beta", "station_gamma", "station_alpha"],
        "sector_type": "hub",
        "radiation_level": 0.02,
        "thermal_background_k": 295.0,
        "gravity_well_penalty": 1.1,
        "mineral_density": 5.0,
        "propellant_sources": 15.0,
        "station_power_output": 200.0,
        "stockpile_capacity": 1000,
        "market_inventory": {
            "commodity_ore":     {"buy_price": 18, "sell_price": 14, "quantity": 50},
            "commodity_food":    {"buy_price": 20, "sell_price": 16, "quantity": 100},
            "commodity_tech":    {"buy_price": 60, "sell_price": 50, "quantity": 80},
            "commodity_fuel":    {"buy_price": 15, "sell_price": 12, "quantity": 120},
            "commodity_specie":  {"buy_price": 1,  "sell_price": 1,  "quantity": 200},
        },
        "available_services": ["trade", "repair", "contracts"],
        "controlling_faction_id": "faction_military",
        "danger_level": 1,
    },
    "station_epsilon": {
        "location_name": "Epsilon Refinery Complex",
        "location_type": "station",
        "connections": ["station_alpha", "station_beta", "station_gamma"],
        "sector_type": "hub",
        "radiation_level": 0.08,
        "thermal_background_k": 340.0,
        "gravity_well_penalty": 0.9,
        "mineral_density": 12.0,
        "propellant_sources": 6.0,
        "station_power_output": 180.0,
        "stockpile_capacity": 1300,
        "market_inventory": {
            "commodity_ore":     {"buy_price": 10, "sell_price":  8, "quantity": 120},
            "commodity_food":    {"buy_price": 28, "sell_price": 22, "quantity":  50},
            "commodity_tech":    {"buy_price": 75, "sell_price": 60, "quantity":  25},
            "commodity_fuel":    {"buy_price": 22, "sell_price": 18, "quantity":  90},
            "commodity_luxury":  {"buy_price": 100, "sell_price": 85, "quantity": 15},
            "commodity_specie":  {"buy_price": 1,  "sell_price": 1,  "quantity": 200},
        },
        "available_services": ["trade", "repair", "contracts"],
        "controlling_faction_id": "faction_miners",
        "danger_level": 2,
    },
}


# =========================================================================
# === FACTIONS ============================================================
# =========================================================================

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


# =========================================================================
# === CHARACTERS ==========================================================
# =========================================================================

CHARACTERS = {
    "character_default": {
        "character_name": "Unnamed",
        "faction_id": "faction_default",
        "credits": 10000,
        "skills": {"piloting": 2, "combat": 1, "trading": 3},
        "age": 30,
        "reputation": 0,
        "personality_traits": {},
        "description": "",
    },
    "character_vera": {
        "character_name": "Vera",
        "faction_id": "faction_traders",
        "credits": 5000,
        "skills": {"piloting": 3, "combat": 1, "trading": 5},
        "age": 40,
        "reputation": 60,
        "personality_traits": {"risk_tolerance": 0.2, "greed": 0.5},
        "description": "Merchant captain, cautious.",
    },
    "character_ada": {
        "character_name": "Ada",
        "faction_id": "faction_independents",
        "credits": 1200,
        "skills": {"piloting": 3, "combat": 2, "trading": 2},
        "age": 32,
        "reputation": 40,
        "personality_traits": {"risk_tolerance": 0.5, "aggression": 0.1},
        "description": "Salvager, resourceful.",
    },
    "character_juno": {
        "character_name": "Juno",
        "faction_id": "faction_miners",
        "credits": 500,
        "skills": {"piloting": 2, "combat": 1, "trading": 1},
        "age": 22,
        "reputation": 10,
        "personality_traits": {"risk_tolerance": 0.8, "greed": 0.7},
        "description": "Young prospector, ambitious.",
    },
    "character_kai": {
        "character_name": "Kai",
        "faction_id": "faction_miners",
        "credits": 1500,
        "skills": {"piloting": 4, "combat": 2, "trading": 1},
        "age": 45,
        "reputation": 50,
        "personality_traits": {"risk_tolerance": 0.3, "loyalty": 0.8},
        "description": "Veteran miner, pragmatic.",
    },
    "character_milo": {
        "character_name": "Milo",
        "faction_id": "faction_traders",
        "credits": 2000,
        "skills": {"piloting": 3, "combat": 2, "trading": 3},
        "age": 35,
        "reputation": 30,
        "personality_traits": {"greed": 0.7, "aggression": 0.2},
        "description": "Cargo hauler, opportunistic.",
    },
    "character_rex": {
        "character_name": "Rex",
        "faction_id": "faction_independents",
        "credits": 800,
        "skills": {"piloting": 5, "combat": 4, "trading": 1},
        "age": 28,
        "reputation": 20,
        "personality_traits": {"risk_tolerance": 0.9, "loyalty": 0.2},
        "description": "Freelancer pilot, risky.",
    },
    "character_siv": {
        "character_name": "Siv",
        "faction_id": "faction_military",
        "credits": 3000,
        "skills": {"piloting": 4, "combat": 5, "trading": 2},
        "age": 38,
        "reputation": 70,
        "personality_traits": {"risk_tolerance": 0.4, "loyalty": 0.9, "greed": 0.6},
        "description": "Military supply officer, disciplined.",
    },
    "character_zara": {
        "character_name": "Zara",
        "faction_id": "faction_miners",
        "credits": 900,
        "skills": {"piloting": 3, "combat": 1, "trading": 2},
        "age": 29,
        "reputation": 25,
        "personality_traits": {"risk_tolerance": 0.7, "greed": 0.4},
        "description": "Survey specialist, maps deposits.",
    },
    "character_nyx": {
        "character_name": "Nyx",
        "faction_id": "faction_military",
        "credits": 2500,
        "skills": {"piloting": 5, "combat": 4, "trading": 1},
        "age": 34,
        "reputation": 55,
        "personality_traits": {"risk_tolerance": 0.3, "loyalty": 0.8, "aggression": 0.4},
        "description": "Patrol officer, keeps order.",
    },
    "character_orin": {
        "character_name": "Orin",
        "faction_id": "faction_traders",
        "credits": 1800,
        "skills": {"piloting": 4, "combat": 1, "trading": 4},
        "age": 42,
        "reputation": 45,
        "personality_traits": {"risk_tolerance": 0.2, "greed": 0.3, "loyalty": 0.6},
        "description": "Bulk cargo hauler, reliable.",
    },
    "character_crow": {
        "character_name": "Crow",
        "faction_id": "faction_pirates",
        "credits": 2200,
        "skills": {"piloting": 4, "combat": 4, "trading": 2},
        "age": 36,
        "reputation": -30,
        "personality_traits": {"risk_tolerance": 0.9, "greed": 0.8, "aggression": 0.7},
        "description": "Ruthless raider, exploits disruption.",
    },
    "character_vex": {
        "character_name": "Vex",
        "faction_id": "faction_pirates",
        "credits": 1600,
        "skills": {"piloting": 5, "combat": 3, "trading": 3},
        "age": 27,
        "reputation": -20,
        "personality_traits": {"risk_tolerance": 0.8, "greed": 0.9, "aggression": 0.5},
        "description": "Cunning smuggler turned pirate.",
    },
    "character_nova": {
        "character_name": "Nova",
        "faction_id": "faction_independents",
        "credits": 2000,
        "skills": {"piloting": 5, "combat": 2, "trading": 2},
        "age": 31,
        "reputation": 35,
        "personality_traits": {"risk_tolerance": 0.9, "loyalty": 0.3},
        "description": "Deep-space explorer, restless.",
    },
}


# =========================================================================
# === AGENTS ==============================================================
# =========================================================================

AGENTS = {
    "agent_player_default": {
        "agent_type": "player",
        "is_persistent": False,
        "home_location_id": "",
        "character_template_id": "",
        "agent_role": "idle",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Traders (buy low, sell high) ---
    "persistent_vera": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_beta",
        "character_template_id": "character_vera",
        "agent_role": "trader",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_milo": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_beta",
        "character_template_id": "character_milo",
        "agent_role": "trader",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Prospectors (explore, discover hidden resources) ---
    "persistent_juno": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_alpha",
        "character_template_id": "character_juno",
        "agent_role": "prospector",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_zara": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_epsilon",
        "character_template_id": "character_zara",
        "agent_role": "prospector",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Military (patrol, suppress piracy, boost security) ---
    "persistent_siv": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_delta",
        "character_template_id": "character_siv",
        "agent_role": "military",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_nyx": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_delta",
        "character_template_id": "character_nyx",
        "agent_role": "military",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Haulers (move goods to balance stockpiles) ---
    "persistent_kai": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_alpha",
        "character_template_id": "character_kai",
        "agent_role": "hauler",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_orin": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_epsilon",
        "character_template_id": "character_orin",
        "agent_role": "hauler",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Freelancers (trade + salvage, flexible) ---
    "persistent_ada": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_ada",
        "agent_role": "trader",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_rex": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_rex",
        "agent_role": "hauler",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Pirates (raid cargo, exploit disruption) ---
    "persistent_crow": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_crow",
        "agent_role": "pirate",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_vex": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_vex",
        "agent_role": "pirate",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Explorers (discover new sectors from frontiers) ---
    "persistent_nova": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_nova",
        "agent_role": "explorer",
        "respawn_timeout_seconds": 300.0,
    },
}
