# PROJECT: GDTLancer
# MODULE: card_area.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2; TRUTH_EXPLORATION-PILLARS.md §3
# LOG_REF: 2026-07-26 01:57:00

extends Control
class_name CardArea

signal card_selected(card)

var cards: Array = []
var selected_cards: Array = []

var container: HBoxContainer = null

func _ready() -> void:
	container = get_node_or_null("ScrollContainer/HBoxContainer") as HBoxContainer

func set_cards(p_cards: Array) -> void:
	cards = p_cards
	render_cards()

func add_card(card: Resource) -> void:
	if card != null:
		cards.append(card)
		render_cards()

func clear_cards() -> void:
	cards.clear()
	selected_cards.clear()
	render_cards()

func render_cards() -> void:
	if container == null:
		return
		
	# Clear existing children
	for child in container.get_children():
		child.queue_free()
		
	for card in cards:
		if card == null:
			continue
		var card_ui = load("res://scenes/ui/board/components/card_ui.tscn").instance()
		card_ui.set_card(card)
		card_ui.set_selected(selected_cards.has(card))
		card_ui.connect("card_pressed", self, "_on_card_pressed")
		container.add_child(card_ui)

func _on_card_pressed(card: Resource) -> void:
	if selected_cards.has(card):
		selected_cards.erase(card)
	else:
		selected_cards.append(card)
	render_cards()
	emit_signal("card_selected", card)
