# PROJECT: GDTLancer
# MODULE: card_collection_panel.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-08-17 04:00:00

extends Control

var AssetCardClass = load("res://src/core/cards/asset_card.gd")
var CardUIScene = load("res://scenes/ui/board/components/card_ui.tscn")

var inventory_container: VBoxContainer

func _ready():
	inventory_container = get_node_or_null("ScrollContainer/VBoxContainer")

func display_collection(cards: Array):
	if inventory_container == null:
		return
		
	# Clear old
	for child in inventory_container.get_children():
		child.queue_free()
		
	var type_labels = ["MODULE", "FIELD", "POSSESSION", "CONSUMABLE"]
	var categorized = {
		AssetCardClass.CardType.MODULE: [],
		AssetCardClass.CardType.FIELD: [],
		AssetCardClass.CardType.POSSESSION: [],
		AssetCardClass.CardType.CONSUMABLE: []
	}
	
	for card in cards:
		if card is AssetCardClass:
			categorized[card.card_type].append(card)
			
	for c_type in categorized.keys():
		if categorized[c_type].size() > 0:
			var header = Label.new()
			header.text = "-- " + type_labels[c_type] + " CARDS --"
			header.add_color_override("font_color", Color(0.7, 0.7, 0.7))
			inventory_container.add_child(header)
			
			var grid = GridContainer.new()
			grid.columns = 3
			grid.set("custom_constants/hseparation", 10)
			grid.set("custom_constants/vseparation", 10)
			inventory_container.add_child(grid)
			
			for card in categorized[c_type]:
				var card_ui = CardUIScene.instance()
				grid.add_child(card_ui)
				if card_ui.has_method("setup_from_card"):
					card_ui.setup_from_card(card)
