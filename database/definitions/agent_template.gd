# AgentTemplate: who controls an agent and which ship it flies.

extends Template
class_name AgentTemplate 

export var agent_type: String = "npc" # Defines whether it is controlled by AI or player.
export var ship_template_id: String = "" # ShipTemplate flown by this agent; the player's comes from GameState.
