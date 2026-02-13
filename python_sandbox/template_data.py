"""
GDTLancer Template Data.
Hardcoded data that mirrors the .tres registry files in database/registry/.
Replaces TemplateDatabase autoload from Godot.
"""

# =========================================================================
# === LOCATIONS ===========================================================
# =========================================================================

LOCATIONS = {
    "station_alpha": {
        "location_name": "Station Alpha - Mining Hub",
        "location_type": "station",
        "connections": ["station_beta", "station_gamma"],
        "sector_type": "hub",
        "radiation_level": 0.05,
        "thermal_background_k": 280.0,
        "gravity_well_penalty": 1.2,
        "mineral_density": 2.0,
        "propellant_sources": 0.3,
        "station_power_output": 150.0,
        "stockpile_capacity": 1500,
        "market_inventory": {
            "commodity_ore":    {"buy_price": 8,  "sell_price": 6,  "quantity": 200},
            "commodity_food":   {"buy_price": 30, "sell_price": 25, "quantity": 40},
            "commodity_tech":   {"buy_price": 80, "sell_price": 65, "quantity": 15},
            "commodity_fuel":   {"buy_price": 25, "sell_price": 20, "quantity": 100},
        },
        "available_services": ["trade", "contracts", "repair"],
        "controlling_faction_id": "faction_miners",
        "danger_level": 1,
    },
    "station_beta": {
        "location_name": "Station Beta - Trade Post",
        "location_type": "station",
        "connections": ["station_alpha", "station_gamma"],
        "sector_type": "hub",
        "radiation_level": 0.01,
        "thermal_background_k": 310.0,
        "gravity_well_penalty": 1.0,
        "mineral_density": 0.3,
        "propellant_sources": 0.8,
        "station_power_output": 120.0,
        "stockpile_capacity": 1200,
        "market_inventory": {
            "commodity_ore":    {"buy_price": 15, "sell_price": 12, "quantity": 30},
            "commodity_food":   {"buy_price": 22, "sell_price": 18, "quantity": 80},
            "commodity_tech":   {"buy_price": 70, "sell_price": 55, "quantity": 50},
            "commodity_fuel":   {"buy_price": 30, "sell_price": 25, "quantity": 60},
            "commodity_luxury": {"buy_price": 90, "sell_price": 75, "quantity": 20},
        },
        "available_services": ["trade", "contracts"],
        "controlling_faction_id": "faction_traders",
        "danger_level": 2,
    },
    "station_gamma": {
        "location_name": "Freeport Gamma",
        "location_type": "station",
        "connections": ["station_alpha", "station_beta"],
        "sector_type": "frontier",
        "radiation_level": 0.15,
        "thermal_background_k": 250.0,
        "gravity_well_penalty": 1.5,
        "mineral_density": 0.8,
        "propellant_sources": 1.2,
        "station_power_output": 80.0,
        "stockpile_capacity": 800,
        "market_inventory": {
            "commodity_ore":    {"buy_price": 12, "sell_price": 10, "quantity": 80},
            "commodity_food":   {"buy_price": 25, "sell_price": 20, "quantity": 60},
            "commodity_tech":   {"buy_price": 55, "sell_price": 45, "quantity": 30},
            "commodity_fuel":   {"buy_price": 20, "sell_price": 15, "quantity": 150},
            "commodity_luxury": {"buy_price": 120, "sell_price": 100, "quantity": 10},
        },
        "available_services": ["trade", "contracts", "black_market"],
        "controlling_faction_id": "faction_independents",
        "danger_level": 4,
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
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_vera": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_beta",
        "character_template_id": "character_vera",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_ada": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_ada",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_juno": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_alpha",
        "character_template_id": "character_juno",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_kai": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_alpha",
        "character_template_id": "character_kai",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_milo": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_beta",
        "character_template_id": "character_milo",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_rex": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_rex",
        "respawn_timeout_seconds": 300.0,
    },
}
