# Tests for UiScale: the theme's lettering, buttons and LAYOUT subtrees take the factor, and going
# back to 1.0 puts every size back as it was.

extends GutTest

const MainTheme = preload("res://assets/themes/main_theme.tres")


func after_each():
	UiScale.set_factor(1.0)
	Settings.reset_to_defaults()


func test_theme_fonts_scale_and_come_back():
	var small: DynamicFont = MainTheme.get_font("font", "SmallLabel")
	var large: DynamicFont = MainTheme.get_font("font", "TitleLabel")
	var sizes := [small.size, large.size, MainTheme.default_font.size]
	UiScale.set_factor(1.5)
	assert_eq([small.size, large.size, MainTheme.default_font.size], [int(round(sizes[0] * 1.5)), int(round(sizes[1] * 1.5)), int(round(sizes[2] * 1.5))])
	UiScale.set_factor(0.5)
	assert_eq([small.size, large.size, MainTheme.default_font.size], [int(round(sizes[0] * 0.5)), int(round(sizes[1] * 0.5)), int(round(sizes[2] * 0.5))], "and down")
	UiScale.set_factor(3.0)
	assert_eq(UiScale.factor, Constants.UI_SCALE_MAX, "Held to the steps' range")
	UiScale.set_factor(0.1)
	assert_eq(UiScale.factor, Constants.UI_SCALE_MIN)
	UiScale.set_factor(1.0)
	assert_eq([small.size, large.size, MainTheme.default_font.size], sizes)


func test_the_option_sets_the_factor():
	Settings.set_option("ui_scale", 1.5)
	assert_eq(UiScale.factor, 1.5)


func test_buttons_grow_from_their_anchor_and_in_containers():
	var root := Control.new()
	add_child_autofree(root)
	var corner := Button.new()  # Anchored to the top right: grows to the left and down
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.margin_left = -100.0
	corner.margin_bottom = 50.0
	root.add_child(corner)
	var box := VBoxContainer.new()
	root.add_child(box)
	var listed := Button.new()
	listed.rect_min_size = Vector2(0, 64)
	box.add_child(listed)
	var label := Label.new()  # Not a button, not in a layout: left alone
	label.margin_left = 30.0
	root.add_child(label)
	yield(get_tree(), "idle_frame")
	UiScale.set_factor(1.5)
	assert_eq([corner.margin_left, corner.margin_right, corner.margin_top, corner.margin_bottom], [-150.0, 0.0, 0.0, 75.0])
	assert_eq(listed.rect_min_size, Vector2(0, 96))
	assert_eq(label.margin_left, 30.0)
	UiScale.set_factor(1.0)
	assert_eq([corner.margin_left, corner.margin_bottom, listed.rect_min_size.y], [-100.0, 50.0, 64.0])


func test_a_layout_scales_as_one_about_its_anchors():
	var layout := Control.new()
	layout.set_meta(UiScale.LAYOUT, true)
	layout.anchor_right = 1.0
	layout.anchor_bottom = 1.0
	layout.margin_left = 20.0
	var zone := Control.new()  # Anchored to the bottom centre
	zone.anchor_left = 0.5
	zone.anchor_right = 0.5
	zone.anchor_top = 1.0
	zone.anchor_bottom = 1.0
	zone.margin_left = -200.0
	zone.margin_right = 200.0
	zone.margin_top = -100.0
	layout.add_child(zone)
	var row := HBoxContainer.new()
	row.add_constant_override("separation", 10)
	zone.add_child(row)
	var picture := TextureButton.new()  # Drawn at its texture's size: made to stretch it
	picture.texture_normal = preload("res://Icon.png")
	row.add_child(picture)
	add_child_autofree(layout)
	yield(get_tree(), "idle_frame")
	var icon_size: Vector2 = picture.texture_normal.get_size()
	assert_true(picture.expand, "it stretches its texture")
	assert_eq(picture.rect_min_size, icon_size)
	UiScale.set_factor(1.25)  # Under what any test window's width holds (layout_factor_for)
	assert_eq(UiScale.layout_factor, 1.25)
	assert_eq(layout.margin_left, 25.0)
	assert_eq([zone.margin_left, zone.margin_right, zone.margin_top, zone.margin_bottom], [-250.0, 250.0, -125.0, 0.0])
	assert_eq(row.get_constant("separation"), 13)
	assert_eq(picture.rect_min_size, icon_size * 1.25)
	assert_eq(UiScale.base_of(zone, "margin_top"), -100.0)
	UiScale.set_factor(1.0)
	assert_eq([layout.margin_left, zone.margin_left, zone.margin_top, row.get_constant("separation")], [20.0, -200.0, -100.0, 10])


func test_down_scales_shrink_buttons_and_layouts_alike():
	var layout := Control.new()
	layout.set_meta(UiScale.LAYOUT, true)
	var zone := Control.new()
	zone.anchor_left = 0.5
	zone.anchor_right = 0.5
	zone.margin_left = -200.0
	zone.margin_right = 200.0
	layout.add_child(zone)
	add_child_autofree(layout)
	var root := Control.new()
	add_child_autofree(root)
	var close := Button.new()
	close.rect_min_size = Vector2(160, 64)
	root.add_child(close)
	yield(get_tree(), "idle_frame")
	UiScale.set_factor(0.5)
	assert_eq(UiScale.layout_factor, 0.5)
	assert_eq([zone.margin_left, zone.margin_right], [-100.0, 100.0], "The HUD's layout")
	assert_eq(close.rect_min_size, Vector2(80, 32), "and a window's button")


func test_skipped_subtrees_are_left_alone():
	var holder := Control.new()
	holder.set_meta(UiScale.SKIP, true)
	var button := Button.new()
	button.rect_min_size = Vector2(150, 150)
	holder.add_child(button)
	add_child_autofree(holder)
	yield(get_tree(), "idle_frame")
	UiScale.set_factor(1.5)
	assert_eq(button.rect_min_size, Vector2(150, 150))


func test_a_layout_is_held_to_the_screens_width():
	assert_eq(UiScale.layout_factor_for(1.25, 1920.0), 1.25, "Fits: the factor")
	assert_almost_eq(UiScale.layout_factor_for(2.0, 1920.0), 1920.0 / Constants.HUD_SCALE_WIDTH, 0.001, "Held to the width")
	assert_eq(UiScale.layout_factor_for(0.5, 1000.0), 0.5, "Never above the factor: down for large monitors")
	assert_eq(UiScale.layout_factor_for(1.5, 1000.0), 1.0, "Nor held below 1.0")


func test_phones_start_at_a_scale_from_their_screen():
	assert_eq(UiScale.auto_factor(768.0, 130.6), 1.0, "The 12 inch 1366x768 the UI is drawn for")
	assert_eq(UiScale.auto_factor(1080.0, 400.0), Constants.UI_SCALE_AUTO_MAX, "A 6 inch 1080p phone: as large as it may start")
	assert_eq(UiScale.auto_factor(1200.0, 220.0), 1.0, "A 10 inch tablet: about as tall as the laptop")
	assert_eq(UiScale.auto_factor(1080.0, 250.0), 1.3, "to the nearest step")


func test_across_only_and_own_factors():
	var layout := Control.new()
	layout.set_meta(UiScale.LAYOUT, true)
	var slider := Control.new()
	slider.set_meta(UiScale.AXES, "x")
	slider.margin_right = 100.0
	slider.margin_top = -250.0
	slider.margin_bottom = 250.0
	layout.add_child(slider)
	var row := Control.new()
	row.margin_right = 100.0
	row.margin_bottom = 50.0
	var inner := Button.new()
	inner.margin_right = 10.0
	row.add_child(inner)
	layout.add_child(row)
	add_child_autofree(layout)
	yield(get_tree(), "idle_frame")
	UiScale.set_factor(1.5)
	var held: float = UiScale.layout_factor
	assert_almost_eq(slider.margin_right, 100.0 * held, 0.01, "Across only")
	assert_eq([slider.margin_top, slider.margin_bottom], [-250.0, 250.0], "its length kept")
	UiScale.set_subtree_factor(row, 0.5)
	assert_eq([row.margin_right, inner.margin_right], [50.0, 5.0], "Its own factor, and under it")
	UiScale.set_subtree_factor(row, 0.0)
	assert_almost_eq(row.margin_right, 100.0 * held, 0.01, "Back to the layout's")
	UiScale.set_factor(0.5)
	assert_eq([slider.margin_right, slider.margin_top, slider.margin_bottom], [50.0, -125.0, 125.0], "Across only grows, but shrinks both ways")
