# AssetSystem: ship template lookup for the player and NPCs.

extends Node
class_name AssetSystem


func _ready():
	GlobalRefs.set_asset_system(self)


func get_ship_template(ship_template_id: String) -> ShipTemplate:
	if ship_template_id == "":
		return null
	if TemplateDatabase.assets_ships.has(ship_template_id):
		return TemplateDatabase.assets_ships[ship_template_id]
	var evolved = TemplateDatabase.evolved.get(ship_template_id)
	return evolved if evolved is ShipTemplate else null


func get_player_ship_template() -> ShipTemplate:
	return get_ship_template(GameState.player_ship_template_id)
