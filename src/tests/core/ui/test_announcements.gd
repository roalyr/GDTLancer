# Tests for Announcements: fading HUD labels that stack up from an anchor, newest at the bottom,
# at most ANNOUNCE_MAX, a repeat starting over instead of stacking.

extends GutTest

const Announcements = preload("res://src/core/ui/main_hud/announcements.gd")

var board: Control = null


func before_each():
	board = Announcements.new()
	add_child_autofree(board)
	board.rect_size = Vector2(1280, 720)


func _texts() -> Array:
	var texts: Array = []
	for entry in board._entries:
		texts.append(entry.label.text)
	return texts


func test_new_ones_push_older_ones_up():
	board.announce("first")
	var slot: float = board._entries[0].panel.rect_position.y
	board.announce("second", "warning")
	assert_eq(_texts(), ["second", "first"], "Newest first")
	assert_almost_eq(board._entries[0].panel.rect_position.y, slot, 0.5, "The new one takes the slot")
	board._process(1.0)
	assert_lt(board._entries[1].panel.rect_position.y, slot - board._entries[0].panel.rect_size.y + 0.5, "The older one slid up above it")


func test_at_most_a_few_and_repeats_start_over():
	for i in range(Constants.ANNOUNCE_MAX + 2):
		board.announce("message %d" % i)
	assert_eq(board._entries.size(), Constants.ANNOUNCE_MAX, "The oldest dropped")
	assert_eq(board._entries[Constants.ANNOUNCE_MAX - 1].label.text, "message 2")
	board._process(1.0)
	board.announce("message 2", "danger")
	assert_eq(board._entries.size(), Constants.ANNOUNCE_MAX, "A repeat does not stack")
	assert_eq(board._entries[0].label.text, "message 2", "it comes back to the bottom")
	assert_eq(board._entries[0].age, 0.0, "and starts over")
	assert_eq(board._entries[0].label.get_color("font_color"), Constants.ANNOUNCE_COLORS.danger)


func test_fades_then_goes():
	board.announce("brief")
	board._process(Constants.ANNOUNCE_HOLD + Constants.ANNOUNCE_FADE * 0.5)
	assert_almost_eq(board._entries[0].panel.modulate.a, 0.5, 0.05, "Half faded")
	board._process(Constants.ANNOUNCE_FADE)
	assert_true(board._entries.empty(), "Gone")
