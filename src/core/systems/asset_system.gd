# AssetSystem: ship template lookup for the player and NPCs.

extends Node
class_name AssetSystem


func _ready():
	GlobalRefs.set_asset_system(self)


func get_ship_template(ship_template_id: String) -> ShipTemplate:
	if ship_template_id == "":
		return null
	return TemplateDatabase.assets_ships.get(ship_template_id)


func get_player_ship_template() -> ShipTemplate:
	return get_ship_template(GameState.player_ship_template_id)
