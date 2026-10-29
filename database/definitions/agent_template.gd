# AgentTemplate: who controls an agent and which ship it flies.

extends Template
class_name AgentTemplate 

export var agent_type: String = "npc" # Defines whether it is controlled by AI or player.
export var ship_template_id: String = "" # ShipTemplate flown by this agent; the player's comes from GameState.
export var faction: String = ""  # Constants.FACTIONS id; decides who it is at war with
export var skill: float = 0.5  # 0 novice .. 1 veteran: how quickly an NPC makes up its mind (see Constants AI block)
export var behavior: Dictionary = {}  # Behaviour genes (Constants EVO_BEHAVIOR_RANGES); empty: the defaults
# A preset's classification (PresetClassifier), for picking archetypes when building factions; empty
# for hand-made agents.
export var role: String = ""  # "lance-raider", "prospector", ...
export var family: String = ""  # "lance", "fighter", "raider", "prospector", "scavenger"
export var weight_class: String = ""  # "light", "medium", "heavy"
export var archetype: String = ""  # Role and weight class
export var temperament: String = ""  # "aggressive", "measured", "cautious"
export var traits: Array = []  # Stand-out genes in words ("relentless", "loner", ...)
export var lives: int = 0  # Arena lives the design flew when exported (0: unknown)
export var fitness: float = 0.0  # Its mean fitness then (Evolution.shrunk_fitness)
