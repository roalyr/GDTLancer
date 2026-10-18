# AgentTemplate: who controls an agent and which ship it flies.

extends Template
class_name AgentTemplate 

export var agent_type: String = "npc" # Defines whether it is controlled by AI or player.
export var ship_template_id: String = "" # ShipTemplate flown by this agent; the player's comes from GameState.
export var faction: String = ""  # Constants.FACTIONS id; decides who it is at war with
export var skill: float = 0.5  # 0 novice .. 1 veteran: how quickly an NPC makes up its mind (see Constants AI block)
