# PROJECT: GDTLancer
# MODULE: test_asset_card_corpus.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_EXPLORATION-PILLARS.md §3, §9
# LOG_REF: 2026-07-26 03:30:00

extends "res://addons/gut/test.gd"

const AssetCardClass = preload("res://src/core/cards/asset_card.gd")
const AssetSystemClass = preload("res://src/core/systems/asset_system.gd")

var asset_sys: Node

func before_each():
	asset_sys = AssetSystemClass.new()
	asset_sys._ready()

func after_each():
	if asset_sys != null:
		asset_sys.free()
		asset_sys = null

func test_load_card_corpus():
	var count = asset_sys.registered_cards.size()
	assert_true(count >= 10, "Corpus should contain at least 10 asset cards")

func test_trade_off_validation_on_modification_cards():
	var mod_cards = asset_sys.get_cards_by_tag("modification")
	assert_true(mod_cards.size() > 0, "Should have modification cards registered")
	
	for card in mod_cards:
		assert_true(card.is_modification_card(), "Card " + card.card_id + " should identify as modification card")
		assert_true(card.validate_trade_offs(), "Modification card " + card.card_id + " must pass trade-off validation (Pillar 9)")

func test_invalid_modification_card_fails_validation():
	var bad_card = AssetCardClass.new("bad_mod", "Bad Mod", ["modification"], ["some_verb"], {}, "No trade-offs")
	assert_true(bad_card.is_modification_card())
	assert_false(bad_card.validate_trade_offs(), "Modification card with no trade-offs must fail validation")

func test_query_by_tag_and_verb():
	var traversal_cards = asset_sys.get_cards_by_tag("traversal")
	assert_true(traversal_cards.size() >= 3)
	
	var pass_cards = asset_sys.get_cards_by_verb("enter_outer_margin")
	assert_eq(pass_cards.size(), 1)
	assert_eq(pass_cards[0].card_id, "nav_pass_outer_margin")
