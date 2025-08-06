# File: core/resource/agent_template.gd
# Resource Definition for Agent.
# Version: 2.0 - Reworked Agent to be a more abstract entity.
# Only needed for in-game simulation, not related to character or ship directly.

extends Template
class_name AgentTemplate 

export var agent_type: String = "npc" # Defines whether it is controlled by AI or player.
var agent_uid: int = 0 # Assigned dynamically by agent spawner to link characters, ships, assets to specific agent in space.
