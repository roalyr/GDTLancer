--- Start of ./addons/gut/gui/BottomPanelShortcuts.tscn ---

[gd_scene load_steps=3 format=2]

[ext_resource path="res://addons/gut/gui/ShortcutButton.tscn" type="PackedScene" id=1]
[ext_resource path="res://addons/gut/gui/BottomPanelShortcuts.gd" type="Script" id=2]

[node name="BottomPanelShortcuts" type="WindowDialog"]
visible = true
anchor_right = 0.234
anchor_bottom = 0.328
margin_right = 195.384
margin_bottom = 62.2
rect_min_size = Vector2( 435, 305 )
popup_exclusive = true
window_title = "GUT Shortcuts"
resizable = true
script = ExtResource( 2 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Layout" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 5.0
margin_right = -5.0
margin_bottom = 2.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="TopPad" type="CenterContainer" parent="Layout"]
margin_right = 425.0
margin_bottom = 5.0
rect_min_size = Vector2( 0, 5 )

[node name="Label2" type="Label" parent="Layout"]
margin_top = 9.0
margin_right = 425.0
margin_bottom = 29.0
rect_min_size = Vector2( 0, 20 )
text = "Always Active"
align = 1
valign = 1
autowrap = true

[node name="ColorRect" type="ColorRect" parent="Layout/Label2"]
show_behind_parent = true
anchor_right = 1.0
anchor_bottom = 1.0
color = Color( 0, 0, 0, 0.196078 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="CPanelButton" type="HBoxContainer" parent="Layout"]
margin_top = 33.0
margin_right = 425.0
margin_bottom = 58.0

[node name="Label" type="Label" parent="Layout/CPanelButton"]
margin_right = 138.0
margin_bottom = 25.0
rect_min_size = Vector2( 50, 0 )
size_flags_vertical = 7
text = "Show/Hide GUT Panel"
valign = 1

[node name="ShortcutButton" parent="Layout/CPanelButton" instance=ExtResource( 1 )]
anchor_right = 0.0
anchor_bottom = 0.0
margin_left = 142.0
margin_right = 425.0
margin_bottom = 25.0
size_flags_horizontal = 3

[node name="GutPanelPad" type="CenterContainer" parent="Layout"]
margin_top = 62.0
margin_right = 425.0
margin_bottom = 67.0
rect_min_size = Vector2( 0, 5 )

[node name="Label" type="Label" parent="Layout"]
margin_top = 71.0
margin_right = 425.0
margin_bottom = 91.0
rect_min_size = Vector2( 0, 20 )
text = "Only Active When GUT Panel Shown"
align = 1
valign = 1
autowrap = true

[node name="ColorRect2" type="ColorRect" parent="Layout/Label"]
show_behind_parent = true
anchor_right = 1.0
anchor_bottom = 1.0
color = Color( 0, 0, 0, 0.196078 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="TopPad2" type="CenterContainer" parent="Layout"]
margin_top = 95.0
margin_right = 425.0
margin_bottom = 100.0
rect_min_size = Vector2( 0, 5 )

[node name="CRunAll" type="HBoxContainer" parent="Layout"]
margin_top = 104.0
margin_right = 425.0
margin_bottom = 129.0

[node name="Label" type="Label" parent="Layout/CRunAll"]
margin_right = 50.0
margin_bottom = 25.0
rect_min_size = Vector2( 50, 0 )
size_flags_vertical = 7
text = "Run All"
valign = 1

[node name="ShortcutButton" parent="Layout/CRunAll" instance=ExtResource( 1 )]
anchor_right = 0.0
anchor_bottom = 0.0
margin_left = 54.0
margin_right = 425.0
margin_bottom = 25.0
size_flags_horizontal = 3

[node name="CRunCurrentScript" type="HBoxContainer" parent="Layout"]
margin_top = 133.0
margin_right = 425.0
margin_bottom = 158.0

[node name="Label" type="Label" parent="Layout/CRunCurrentScript"]
margin_right = 115.0
margin_bottom = 25.0
rect_min_size = Vector2( 50, 0 )
size_flags_vertical = 7
text = "Run Current Script"
valign = 1

[node name="ShortcutButton" parent="Layout/CRunCurrentScript" instance=ExtResource( 1 )]
anchor_right = 0.0
anchor_bottom = 0.0
margin_left = 119.0
margin_right = 425.0
margin_bottom = 25.0
size_flags_horizontal = 3

[node name="CRunCurrentInner" type="HBoxContainer" parent="Layout"]
margin_top = 162.0
margin_right = 425.0
margin_bottom = 187.0

[node name="Label" type="Label" parent="Layout/CRunCurrentInner"]
margin_right = 150.0
margin_bottom = 25.0
rect_min_size = Vector2( 50, 0 )
size_flags_vertical = 7
text = "Run Current Inner Class"
valign = 1

[node name="ShortcutButton" parent="Layout/CRunCurrentInner" instance=ExtResource( 1 )]
anchor_right = 0.0
anchor_bottom = 0.0
margin_left = 154.0
margin_right = 425.0
margin_bottom = 25.0
size_flags_horizontal = 3

[node name="CRunCurrentTest" type="HBoxContainer" parent="Layout"]
margin_top = 191.0
margin_right = 425.0
margin_bottom = 216.0

[node name="Label" type="Label" parent="Layout/CRunCurrentTest"]
margin_right = 106.0
margin_bottom = 25.0
rect_min_size = Vector2( 50, 0 )
size_flags_vertical = 7
text = "Run Current Test"
valign = 1

[node name="ShortcutButton" parent="Layout/CRunCurrentTest" instance=ExtResource( 1 )]
anchor_right = 0.0
anchor_bottom = 0.0
margin_left = 110.0
margin_right = 425.0
margin_bottom = 25.0
size_flags_horizontal = 3

[node name="CenterContainer2" type="CenterContainer" parent="Layout"]
margin_top = 220.0
margin_right = 425.0
margin_bottom = 241.0
rect_min_size = Vector2( 0, 5 )
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="ShiftDisclaimer" type="Label" parent="Layout"]
margin_top = 245.0
margin_right = 425.0
margin_bottom = 259.0
text = "\"Shift\" cannot be the only modifier for a shortcut."
align = 2
autowrap = true

[node name="HBoxContainer" type="HBoxContainer" parent="Layout"]
margin_top = 263.0
margin_right = 425.0
margin_bottom = 293.0

[node name="CenterContainer" type="CenterContainer" parent="Layout/HBoxContainer"]
margin_right = 361.0
margin_bottom = 30.0
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="Hide" type="Button" parent="Layout/HBoxContainer"]
margin_left = 365.0
margin_right = 425.0
margin_bottom = 30.0
rect_min_size = Vector2( 60, 30 )
text = "Close"

[node name="BottomPad" type="CenterContainer" parent="Layout"]
margin_top = 297.0
margin_right = 425.0
margin_bottom = 307.0
rect_min_size = Vector2( 0, 10 )
size_flags_horizontal = 3

[connection signal="pressed" from="Layout/HBoxContainer/Hide" to="." method="_on_Hide_pressed"]

--- Start of ./addons/gut/gui/GutBottomPanel.tscn ---

[gd_scene load_steps=11 format=2]

[ext_resource path="res://addons/gut/gui/GutBottomPanel.gd" type="Script" id=1]
[ext_resource path="res://addons/gut/gui/BottomPanelShortcuts.tscn" type="PackedScene" id=2]
[ext_resource path="res://addons/gut/gui/RunAtCursor.tscn" type="PackedScene" id=3]
[ext_resource path="res://addons/gut/gui/play.png" type="Texture" id=4]
[ext_resource path="res://addons/gut/gui/RunResults.tscn" type="PackedScene" id=5]
[ext_resource path="res://addons/gut/gui/OutputText.tscn" type="PackedScene" id=6]

[sub_resource type="InputEventKey" id=8]
control = true
scancode = 49

[sub_resource type="ShortCut" id=9]
shortcut = SubResource( 8 )

[sub_resource type="Image" id=10]
data = {
"data": PoolByteArray( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ),
"format": "LumAlpha8",
"height": 16,
"mipmaps": false,
"width": 16
}

[sub_resource type="ImageTexture" id=2]
flags = 4
flags = 4
image = SubResource( 10 )
size = Vector2( 16, 16 )

[node name="GutBottomPanel" type="Control"]
anchor_left = -0.0025866
anchor_top = -0.00176575
anchor_right = 0.997413
anchor_bottom = 0.998234
margin_left = 2.64868
margin_top = 1.05945
margin_right = 2.64862
margin_bottom = 1.05945
rect_min_size = Vector2( 0, 300 )
script = ExtResource( 1 )

[node name="layout" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="ControlBar" type="HBoxContainer" parent="layout"]
margin_right = 1023.0
margin_bottom = 40.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="RunAll" type="Button" parent="layout/ControlBar"]
margin_right = 150.0
margin_bottom = 40.0
rect_min_size = Vector2( 150, 0 )
hint_tooltip = "Run all test scripts in the suite."
size_flags_vertical = 11
shortcut = SubResource( 9 )
text = "Run All"
icon = ExtResource( 4 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Label" type="Label" parent="layout/ControlBar"]
margin_left = 154.0
margin_top = 13.0
margin_right = 213.0
margin_bottom = 27.0
hint_tooltip = "When a test script is edited, buttons are displayed to
run the opened script or an Inner-Test-Class or a
single test.  The buttons change based on the location
of the cursor in the file.

These buttons will remain active when editing other
items so that you can run tests without having to switch
back to the test script.

You can assign keyboard shortcuts for these buttons
using the \"shortcuts\" button in the GUT panel."
mouse_filter = 1
text = "Current:  "

[node name="RunAtCursor" parent="layout/ControlBar" instance=ExtResource( 3 )]
anchor_right = 0.0
anchor_bottom = 0.0
margin_left = 217.0
margin_right = 548.0
margin_bottom = 40.0
rect_min_size = Vector2( 0, 40 )

[node name="CenterContainer2" type="CenterContainer" parent="layout/ControlBar"]
margin_left = 552.0
margin_right = 883.0
margin_bottom = 40.0
size_flags_horizontal = 3

[node name="Sep1" type="ColorRect" parent="layout/ControlBar"]
margin_left = 887.0
margin_right = 889.0
margin_bottom = 40.0
rect_min_size = Vector2( 2, 0 )

[node name="RunResultsBtn" type="ToolButton" parent="layout/ControlBar"]
margin_left = 893.0
margin_right = 921.0
margin_bottom = 40.0
hint_tooltip = "Show/Hide Results Tree Panel."
toggle_mode = true
pressed = true
icon = SubResource( 2 )

[node name="OutputBtn" type="ToolButton" parent="layout/ControlBar"]
margin_left = 925.0
margin_right = 953.0
margin_bottom = 40.0
hint_tooltip = "Show/Hide Output Panel."
toggle_mode = true
pressed = true
icon = SubResource( 2 )

[node name="Settings" type="ToolButton" parent="layout/ControlBar"]
margin_left = 957.0
margin_right = 985.0
margin_bottom = 40.0
hint_tooltip = "Show/Hide Settings Panel."
toggle_mode = true
icon = SubResource( 2 )

[node name="Sep2" type="ColorRect" parent="layout/ControlBar"]
margin_left = 989.0
margin_right = 991.0
margin_bottom = 40.0
rect_min_size = Vector2( 2, 0 )

[node name="Shortcuts" type="ToolButton" parent="layout/ControlBar"]
margin_left = 995.0
margin_right = 1023.0
margin_bottom = 40.0
hint_tooltip = "Set shortcuts for GUT buttons.  Shortcuts do not work when the GUT panel is not visible."
size_flags_vertical = 11
icon = SubResource( 2 )

[node name="RSplit" type="HSplitContainer" parent="layout"]
margin_top = 44.0
margin_right = 1023.0
margin_bottom = 599.0
size_flags_horizontal = 3
size_flags_vertical = 3
collapsed = true

[node name="sc" type="ScrollContainer" parent="layout/RSplit"]
visible = false
margin_left = 593.0
margin_right = 1093.0
margin_bottom = 555.0
rect_min_size = Vector2( 500, 0 )
mouse_filter = 1
size_flags_vertical = 3

[node name="Settings" type="VBoxContainer" parent="layout/RSplit/sc"]
margin_right = 500.0
margin_bottom = 908.0
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="CResults" type="VBoxContainer" parent="layout/RSplit"]
margin_right = 1023.0
margin_bottom = 555.0
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="ControlBar" type="HBoxContainer" parent="layout/RSplit/CResults"]
margin_right = 1023.0
margin_bottom = 35.0
rect_min_size = Vector2( 0, 35 )

[node name="Light" type="Control" parent="layout/RSplit/CResults/ControlBar"]
visible = false
margin_right = 30.0
margin_bottom = 35.0
rect_min_size = Vector2( 30, 30 )

[node name="Passing" type="HBoxContainer" parent="layout/RSplit/CResults/ControlBar"]
visible = false
margin_left = 34.0
margin_right = 107.0
margin_bottom = 35.0

[node name="Sep" type="ColorRect" parent="layout/RSplit/CResults/ControlBar/Passing"]
margin_right = 2.0
margin_bottom = 35.0
rect_min_size = Vector2( 2, 0 )

[node name="label" type="Label" parent="layout/RSplit/CResults/ControlBar/Passing"]
margin_left = 6.0
margin_top = 10.0
margin_right = 54.0
margin_bottom = 24.0
text = "Passing"

[node name="value" type="Label" parent="layout/RSplit/CResults/ControlBar/Passing"]
margin_left = 58.0
margin_top = 10.0
margin_right = 73.0
margin_bottom = 24.0
text = "---"

[node name="Failing" type="HBoxContainer" parent="layout/RSplit/CResults/ControlBar"]
visible = false
margin_left = 34.0
margin_right = 100.0
margin_bottom = 35.0

[node name="Sep" type="ColorRect" parent="layout/RSplit/CResults/ControlBar/Failing"]
margin_right = 2.0
margin_bottom = 35.0
rect_min_size = Vector2( 2, 0 )

[node name="label" type="Label" parent="layout/RSplit/CResults/ControlBar/Failing"]
margin_left = 6.0
margin_top = 10.0
margin_right = 47.0
margin_bottom = 24.0
text = "Failing"

[node name="value" type="Label" parent="layout/RSplit/CResults/ControlBar/Failing"]
margin_left = 51.0
margin_top = 10.0
margin_right = 66.0
margin_bottom = 24.0
text = "---"

[node name="Pending" type="HBoxContainer" parent="layout/RSplit/CResults/ControlBar"]
visible = false
margin_left = 34.0
margin_right = 110.0
margin_bottom = 35.0

[node name="Sep" type="ColorRect" parent="layout/RSplit/CResults/ControlBar/Pending"]
margin_right = 2.0
margin_bottom = 35.0
rect_min_size = Vector2( 2, 0 )

[node name="label" type="Label" parent="layout/RSplit/CResults/ControlBar/Pending"]
margin_left = 6.0
margin_top = 10.0
margin_right = 57.0
margin_bottom = 24.0
text = "Pending"

[node name="value" type="Label" parent="layout/RSplit/CResults/ControlBar/Pending"]
margin_left = 61.0
margin_top = 10.0
margin_right = 76.0
margin_bottom = 24.0
text = "---"

[node name="Orphans" type="HBoxContainer" parent="layout/RSplit/CResults/ControlBar"]
visible = false
margin_left = 34.0
margin_right = 110.0
margin_bottom = 35.0

[node name="Sep" type="ColorRect" parent="layout/RSplit/CResults/ControlBar/Orphans"]
margin_right = 2.0
margin_bottom = 35.0
rect_min_size = Vector2( 2, 0 )

[node name="label" type="Label" parent="layout/RSplit/CResults/ControlBar/Orphans"]
margin_left = 6.0
margin_top = 10.0
margin_right = 57.0
margin_bottom = 24.0
text = "Orphans"

[node name="value" type="Label" parent="layout/RSplit/CResults/ControlBar/Orphans"]
margin_left = 61.0
margin_top = 10.0
margin_right = 76.0
margin_bottom = 24.0
text = "---"

[node name="Errors" type="HBoxContainer" parent="layout/RSplit/CResults/ControlBar"]
visible = false
margin_left = 34.0
margin_right = 96.0
margin_bottom = 35.0

[node name="Sep" type="ColorRect" parent="layout/RSplit/CResults/ControlBar/Errors"]
margin_right = 2.0
margin_bottom = 35.0
rect_min_size = Vector2( 2, 0 )

[node name="label" type="Label" parent="layout/RSplit/CResults/ControlBar/Errors"]
margin_left = 6.0
margin_top = 10.0
margin_right = 43.0
margin_bottom = 24.0
hint_tooltip = "The number of GUT errors generated.  This does not include engine errors."
text = "Errors"

[node name="value" type="Label" parent="layout/RSplit/CResults/ControlBar/Errors"]
margin_left = 47.0
margin_top = 10.0
margin_right = 62.0
margin_bottom = 24.0
text = "---"

[node name="Warnings" type="HBoxContainer" parent="layout/RSplit/CResults/ControlBar"]
visible = false
margin_left = 34.0
margin_right = 118.0
margin_bottom = 35.0

[node name="Sep" type="ColorRect" parent="layout/RSplit/CResults/ControlBar/Warnings"]
margin_right = 2.0
margin_bottom = 35.0
rect_min_size = Vector2( 2, 0 )

[node name="label" type="Label" parent="layout/RSplit/CResults/ControlBar/Warnings"]
margin_left = 6.0
margin_top = 10.0
margin_right = 65.0
margin_bottom = 24.0
text = "Warnings"
__meta__ = {
"_editor_description_": "The number of GUT Warnings generated.  This does not include engine warnings."
}

[node name="value" type="Label" parent="layout/RSplit/CResults/ControlBar/Warnings"]
margin_left = 69.0
margin_top = 10.0
margin_right = 84.0
margin_bottom = 24.0
text = "---"

[node name="CenterContainer" type="CenterContainer" parent="layout/RSplit/CResults/ControlBar"]
margin_right = 1023.0
margin_bottom = 35.0
size_flags_horizontal = 3

[node name="Tabs" type="HSplitContainer" parent="layout/RSplit/CResults"]
margin_top = 39.0
margin_right = 1023.0
margin_bottom = 555.0
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="RunResults" parent="layout/RSplit/CResults/Tabs" instance=ExtResource( 5 )]
margin_right = 505.0
margin_bottom = 516.0
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="OutputText" parent="layout/RSplit/CResults/Tabs" instance=ExtResource( 6 )]
margin_left = 517.0
margin_right = 1023.0
margin_bottom = 516.0

[node name="BottomPanelShortcuts" parent="." instance=ExtResource( 2 )]
visible = false
anchor_left = -0.000517324
anchor_top = 0.000882874
anchor_right = 0.233483
anchor_bottom = 0.328883
margin_left = 10.0649
margin_top = -173.752
margin_right = 31.6969
margin_bottom = -125.552

[connection signal="pressed" from="layout/ControlBar/RunAll" to="." method="_on_RunAll_pressed"]
[connection signal="run_tests" from="layout/ControlBar/RunAtCursor" to="." method="_on_RunAtCursor_run_tests"]
[connection signal="pressed" from="layout/ControlBar/RunResultsBtn" to="." method="_on_RunResultsBtn_pressed"]
[connection signal="pressed" from="layout/ControlBar/OutputBtn" to="." method="_on_OutputBtn_pressed"]
[connection signal="pressed" from="layout/ControlBar/Settings" to="." method="_on_Settings_pressed"]
[connection signal="pressed" from="layout/ControlBar/Shortcuts" to="." method="_on_Shortcuts_pressed"]
[connection signal="draw" from="layout/RSplit/CResults/ControlBar/Light" to="." method="_on_Light_draw"]
[connection signal="popup_hide" from="BottomPanelShortcuts" to="." method="_on_BottomPanelShortcuts_popup_hide"]

--- Start of ./addons/gut/gui/GutRunner.tscn ---

[gd_scene load_steps=2 format=2]

[ext_resource path="res://addons/gut/gui/GutRunner.gd" type="Script" id=1]

[node name="GutRunner" type="Node2D"]
script = ExtResource( 1 )

[node name="GutLayer" type="CanvasLayer" parent="."]
layer = 128

--- Start of ./addons/gut/gui/OutputText.tscn ---

[gd_scene load_steps=4 format=2]

[ext_resource path="res://addons/gut/gui/OutputText.gd" type="Script" id=1]

[sub_resource type="Image" id=3]
data = {
"data": PoolByteArray( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ),
"format": "LumAlpha8",
"height": 16,
"mipmaps": false,
"width": 16
}

[sub_resource type="ImageTexture" id=2]
flags = 4
flags = 4
image = SubResource( 3 )
size = Vector2( 16, 16 )

[node name="OutputText" type="VBoxContainer"]
margin_right = 862.0
margin_bottom = 523.0
size_flags_horizontal = 3
size_flags_vertical = 3
script = ExtResource( 1 )

[node name="Toolbar" type="HBoxContainer" parent="."]
margin_right = 862.0
margin_bottom = 24.0
size_flags_horizontal = 3

[node name="ShowSearch" type="ToolButton" parent="Toolbar"]
margin_right = 28.0
margin_bottom = 24.0
toggle_mode = true
icon = SubResource( 2 )

[node name="UseColors" type="ToolButton" parent="Toolbar"]
margin_left = 32.0
margin_right = 60.0
margin_bottom = 24.0
hint_tooltip = "Colorize output. 
 It's not the same as everywhere else (long story),
 but it is better than nothing."
toggle_mode = true
pressed = true
icon = SubResource( 2 )

[node name="WordWrap" type="ToolButton" parent="Toolbar"]
margin_left = 64.0
margin_right = 92.0
margin_bottom = 24.0
hint_tooltip = "Word wrap"
toggle_mode = true
icon = SubResource( 2 )

[node name="CenterContainer" type="CenterContainer" parent="Toolbar"]
margin_left = 96.0
margin_right = 743.0
margin_bottom = 24.0
size_flags_horizontal = 3

[node name="CopyButton" type="Button" parent="Toolbar"]
margin_left = 747.0
margin_right = 798.0
margin_bottom = 24.0
hint_tooltip = "Copy to clipboard"
text = " Copy "

[node name="ClearButton" type="Button" parent="Toolbar"]
margin_left = 802.0
margin_right = 862.0
margin_bottom = 24.0
text = "  Clear  "

[node name="Output" type="TextEdit" parent="."]
margin_top = 28.0
margin_right = 862.0
margin_bottom = 523.0
size_flags_horizontal = 3
size_flags_vertical = 3
readonly = true
highlight_current_line = true
syntax_highlighting = true
show_line_numbers = true
smooth_scrolling = true

[node name="Search" type="HBoxContainer" parent="."]
visible = false
margin_top = 499.0
margin_right = 862.0
margin_bottom = 523.0

[node name="SearchTerm" type="LineEdit" parent="Search"]
margin_right = 804.0
margin_bottom = 24.0
size_flags_horizontal = 3

[node name="SearchNext" type="Button" parent="Search"]
margin_left = 808.0
margin_right = 862.0
margin_bottom = 24.0
hint_tooltip = "Find next (enter)"
text = "Next"

[node name="SearchPrev" type="Button" parent="Search"]
margin_left = 808.0
margin_right = 820.0
margin_bottom = 20.0
hint_tooltip = "Find previous (shift + enter)"
text = "Prev"

[connection signal="pressed" from="Toolbar/ShowSearch" to="." method="_on_ShowSearch_pressed"]
[connection signal="pressed" from="Toolbar/UseColors" to="." method="_on_UseColors_pressed"]
[connection signal="pressed" from="Toolbar/WordWrap" to="." method="_on_WordWrap_pressed"]
[connection signal="pressed" from="Toolbar/CopyButton" to="." method="_on_CopyButton_pressed"]
[connection signal="pressed" from="Toolbar/ClearButton" to="." method="_on_ClearButton_pressed"]
[connection signal="focus_entered" from="Search/SearchTerm" to="." method="_on_SearchTerm_focus_entered"]
[connection signal="gui_input" from="Search/SearchTerm" to="." method="_on_SearchTerm_gui_input"]
[connection signal="text_changed" from="Search/SearchTerm" to="." method="_on_SearchTerm_text_changed"]
[connection signal="text_entered" from="Search/SearchTerm" to="." method="_on_SearchTerm_text_entered"]
[connection signal="pressed" from="Search/SearchNext" to="." method="_on_SearchNext_pressed"]
[connection signal="pressed" from="Search/SearchPrev" to="." method="_on_SearchPrev_pressed"]

--- Start of ./addons/gut/gui/RunAtCursor.tscn ---

[gd_scene load_steps=4 format=2]

[ext_resource path="res://addons/gut/gui/RunAtCursor.gd" type="Script" id=1]
[ext_resource path="res://addons/gut/gui/play.png" type="Texture" id=2]
[ext_resource path="res://addons/gut/gui/arrow.png" type="Texture" id=3]

[node name="RunAtCursor" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_right = 1.0
margin_bottom = -527.0
size_flags_horizontal = 3
size_flags_vertical = 3
script = ExtResource( 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="HBox" type="HBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
size_flags_horizontal = 3
size_flags_vertical = 3
__meta__ = {
"_edit_use_anchors_": false
}

[node name="LblNoneSelected" type="Label" parent="HBox"]
margin_top = 29.0
margin_right = 50.0
margin_bottom = 43.0
text = "<None>"

[node name="BtnRunScript" type="Button" parent="HBox"]
visible = false
margin_left = 54.0
margin_right = 140.0
margin_bottom = 73.0
text = "<script>"
icon = ExtResource( 2 )

[node name="Arrow1" type="TextureButton" parent="HBox"]
visible = false
margin_left = 54.0
margin_right = 78.0
margin_bottom = 73.0
rect_min_size = Vector2( 24, 0 )
texture_normal = ExtResource( 3 )
expand = true
stretch_mode = 3

[node name="BtnRunInnerClass" type="Button" parent="HBox"]
visible = false
margin_left = 134.0
margin_right = 243.0
margin_bottom = 73.0
text = "<inner class>"
icon = ExtResource( 2 )

[node name="Arrow2" type="TextureButton" parent="HBox"]
visible = false
margin_left = 54.0
margin_right = 78.0
margin_bottom = 73.0
rect_min_size = Vector2( 24, 0 )
texture_normal = ExtResource( 3 )
expand = true
stretch_mode = 3

[node name="BtnRunMethod" type="Button" parent="HBox"]
visible = false
margin_left = 247.0
margin_right = 337.0
margin_bottom = 73.0
text = "<method>"
icon = ExtResource( 2 )

[connection signal="pressed" from="HBox/BtnRunScript" to="." method="_on_BtnRunScript_pressed"]
[connection signal="pressed" from="HBox/BtnRunInnerClass" to="." method="_on_BtnRunInnerClass_pressed"]
[connection signal="pressed" from="HBox/BtnRunMethod" to="." method="_on_BtnRunMethod_pressed"]

--- Start of ./addons/gut/gui/RunResults.tscn ---

[gd_scene load_steps=4 format=2]

[ext_resource path="res://addons/gut/gui/RunResults.gd" type="Script" id=1]

[sub_resource type="Image" id=3]
data = {
"data": PoolByteArray( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ),
"format": "LumAlpha8",
"height": 16,
"mipmaps": false,
"width": 16
}

[sub_resource type="ImageTexture" id=2]
flags = 4
flags = 4
image = SubResource( 3 )
size = Vector2( 16, 16 )

[node name="RunResults" type="Control"]
margin_right = 595.0
margin_bottom = 459.0
rect_min_size = Vector2( 302, 0 )
script = ExtResource( 1 )

[node name="VBox" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0

[node name="Toolbar" type="HBoxContainer" parent="VBox"]
margin_right = 296.0
margin_bottom = 24.0
size_flags_horizontal = 0

[node name="Expand" type="ToolButton" parent="VBox/Toolbar"]
margin_right = 28.0
margin_bottom = 24.0
hint_tooltip = "Expand selected item and all children."
icon = SubResource( 2 )

[node name="Collapse" type="ToolButton" parent="VBox/Toolbar"]
margin_left = 32.0
margin_right = 60.0
margin_bottom = 24.0
hint_tooltip = "Collapse selected item and all children."
icon = SubResource( 2 )

[node name="Sep" type="ColorRect" parent="VBox/Toolbar"]
margin_left = 64.0
margin_right = 66.0
margin_bottom = 24.0
rect_min_size = Vector2( 2, 0 )

[node name="LblAll" type="Label" parent="VBox/Toolbar"]
margin_left = 70.0
margin_top = 5.0
margin_right = 91.0
margin_bottom = 19.0
text = "All:"
align = 1

[node name="ExpandAll" type="ToolButton" parent="VBox/Toolbar"]
margin_left = 95.0
margin_right = 123.0
margin_bottom = 24.0
hint_tooltip = "Expand All."
icon = SubResource( 2 )

[node name="CollapseAll" type="ToolButton" parent="VBox/Toolbar"]
margin_left = 127.0
margin_right = 155.0
margin_bottom = 24.0
hint_tooltip = "Collapse all."
icon = SubResource( 2 )

[node name="Sep2" type="ColorRect" parent="VBox/Toolbar"]
margin_left = 159.0
margin_right = 161.0
margin_bottom = 24.0
rect_min_size = Vector2( 2, 0 )

[node name="HidePassing" type="CheckBox" parent="VBox/Toolbar"]
margin_left = 165.0
margin_right = 189.0
margin_bottom = 24.0
hint_tooltip = "Show/Hide passing tests.  Takes effect on next run."
size_flags_horizontal = 4
custom_icons/checked = SubResource( 2 )
custom_icons/unchecked = SubResource( 2 )
pressed = true
__meta__ = {
"_editor_description_": ""
}

[node name="Sep3" type="ColorRect" parent="VBox/Toolbar"]
margin_left = 193.0
margin_right = 195.0
margin_bottom = 24.0
rect_min_size = Vector2( 2, 0 )

[node name="LblSync" type="Label" parent="VBox/Toolbar"]
margin_left = 199.0
margin_top = 5.0
margin_right = 232.0
margin_bottom = 19.0
text = "Sync:"
align = 1

[node name="ShowScript" type="ToolButton" parent="VBox/Toolbar"]
margin_left = 236.0
margin_right = 264.0
margin_bottom = 24.0
hint_tooltip = "Open script and scroll to line when a tree item is clicked."
toggle_mode = true
pressed = true
icon = SubResource( 2 )

[node name="ScrollOutput" type="ToolButton" parent="VBox/Toolbar"]
margin_left = 268.0
margin_right = 296.0
margin_bottom = 24.0
hint_tooltip = "Scroll to related line in the output panel when tree item clicked."
toggle_mode = true
pressed = true
icon = SubResource( 2 )

[node name="Output" type="Panel" parent="VBox"]
self_modulate = Color( 1, 1, 1, 0.541176 )
margin_top = 28.0
margin_right = 595.0
margin_bottom = 459.0
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="Scroll" type="ScrollContainer" parent="VBox/Output"]
anchor_right = 1.0
anchor_bottom = 1.0

[node name="Tree" type="Tree" parent="VBox/Output/Scroll"]
margin_right = 595.0
margin_bottom = 431.0
size_flags_horizontal = 3
size_flags_vertical = 3
columns = 2
hide_root = true

[node name="OverlayMessage" type="Label" parent="VBox/Output"]
anchor_right = 1.0
anchor_bottom = 1.0
align = 1
valign = 1

[node name="FontSampler" type="Label" parent="."]
visible = false
margin_right = 40.0
margin_bottom = 14.0
text = "000 of 000 passed"

[connection signal="pressed" from="VBox/Toolbar/Expand" to="." method="_on_Expand_pressed"]
[connection signal="pressed" from="VBox/Toolbar/Collapse" to="." method="_on_Collapse_pressed"]
[connection signal="pressed" from="VBox/Toolbar/ExpandAll" to="." method="_on_ExpandAll_pressed"]
[connection signal="pressed" from="VBox/Toolbar/CollapseAll" to="." method="_on_CollapseAll_pressed"]
[connection signal="pressed" from="VBox/Toolbar/HidePassing" to="." method="_on_Hide_Passing_pressed"]
[connection signal="item_activated" from="VBox/Output/Scroll/Tree" to="." method="_on_Tree_item_activated"]
[connection signal="item_selected" from="VBox/Output/Scroll/Tree" to="." method="_on_Tree_item_selected"]

--- Start of ./addons/gut/gui/Settings.tscn ---

[gd_scene format=2]

[node name="Settings" type="VBoxContainer"]
margin_right = 388.0
margin_bottom = 586.0
size_flags_horizontal = 3
size_flags_vertical = 3

--- Start of ./addons/gut/gui/ShortcutButton.tscn ---

[gd_scene load_steps=2 format=2]

[ext_resource path="res://addons/gut/gui/ShortcutButton.gd" type="Script" id=1]

[node name="ShortcutButton" type="Control"]
anchor_right = 0.123
anchor_bottom = 0.04
margin_right = 33.048
margin_bottom = 1.0
rect_min_size = Vector2( 125, 25 )
script = ExtResource( 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Layout" type="HBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="lblShortcut" type="Label" parent="Layout"]
margin_right = 50.0
margin_bottom = 25.0
size_flags_horizontal = 3
size_flags_vertical = 7
text = "<None>"
align = 2
valign = 1

[node name="CenterContainer" type="CenterContainer" parent="Layout"]
margin_left = 54.0
margin_right = 64.0
margin_bottom = 25.0
rect_min_size = Vector2( 10, 0 )

[node name="SetButton" type="Button" parent="Layout"]
margin_left = 68.0
margin_right = 128.0
margin_bottom = 25.0
rect_min_size = Vector2( 60, 0 )
text = "Set"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="SaveButton" type="Button" parent="Layout"]
visible = false
margin_left = 82.0
margin_right = 142.0
margin_bottom = 25.0
rect_min_size = Vector2( 60, 0 )
text = "Save"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="CancelButton" type="Button" parent="Layout"]
visible = false
margin_left = 82.0
margin_right = 142.0
margin_bottom = 25.0
rect_min_size = Vector2( 60, 0 )
text = "Cancel"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="ClearButton" type="Button" parent="Layout"]
margin_left = 132.0
margin_right = 192.0
margin_bottom = 25.0
rect_min_size = Vector2( 60, 0 )
text = "Clear"

[connection signal="pressed" from="Layout/SetButton" to="." method="_on_SetButton_pressed"]
[connection signal="pressed" from="Layout/SaveButton" to="." method="_on_SaveButton_pressed"]
[connection signal="pressed" from="Layout/CancelButton" to="." method="_on_CancelButton_pressed"]
[connection signal="pressed" from="Layout/ClearButton" to="." method="_on_ClearButton_pressed"]

--- Start of ./addons/gut/GutScene.tscn ---

[gd_scene load_steps=16 format=2]

[ext_resource path="res://addons/gut/GutScene.gd" type="Script" id=1]
[ext_resource path="res://addons/gut/fonts/AnonymousPro-Italic.ttf" type="DynamicFontData" id=2]
[ext_resource path="res://addons/gut/fonts/AnonymousPro-Regular.ttf" type="DynamicFontData" id=3]
[ext_resource path="res://addons/gut/fonts/AnonymousPro-BoldItalic.ttf" type="DynamicFontData" id=4]
[ext_resource path="res://addons/gut/fonts/AnonymousPro-Bold.ttf" type="DynamicFontData" id=5]
[ext_resource path="res://addons/gut/UserFileViewer.tscn" type="PackedScene" id=6]
[ext_resource path="res://addons/gut/gui/GutSceneTheme.tres" type="Theme" id=7]

[sub_resource type="StyleBoxFlat" id=1]
bg_color = Color( 0.192157, 0.192157, 0.227451, 1 )
corner_radius_top_left = 10
corner_radius_top_right = 10

[sub_resource type="StyleBoxFlat" id=2]
bg_color = Color( 1, 1, 1, 1 )
border_color = Color( 0, 0, 0, 1 )
corner_radius_top_left = 5
corner_radius_top_right = 5

[sub_resource type="Theme" id=3]
resource_local_to_scene = true
Panel/styles/panel = SubResource( 2 )
Panel/styles/panelf = null
Panel/styles/panelnc = null

[sub_resource type="DynamicFont" id=4]
font_data = ExtResource( 4 )

[sub_resource type="DynamicFont" id=5]
font_data = ExtResource( 2 )

[sub_resource type="DynamicFont" id=6]
font_data = ExtResource( 5 )

[sub_resource type="DynamicFont" id=7]
font_data = ExtResource( 3 )

[sub_resource type="StyleBoxFlat" id=8]
bg_color = Color( 0.192157, 0.192157, 0.227451, 1 )
corner_radius_top_left = 20
corner_radius_top_right = 20

[node name="Gut" type="Panel"]
margin_right = 740.0
margin_bottom = 300.0
rect_min_size = Vector2( 740, 300 )
theme = ExtResource( 7 )
custom_styles/panel = SubResource( 1 )
script = ExtResource( 1 )

[node name="UserFileViewer" parent="." instance=ExtResource( 6 )]
margin_top = 388.0
margin_bottom = 818.0

[node name="VBox" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="TitleBar" type="Panel" parent="VBox"]
margin_right = 740.0
margin_bottom = 30.0
rect_min_size = Vector2( 0, 30 )
theme = SubResource( 3 )
__meta__ = {
"_edit_group_": true,
"_edit_use_anchors_": false
}

[node name="HBox" type="HBoxContainer" parent="VBox/TitleBar"]
anchor_right = 1.0
anchor_bottom = 1.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Summary" type="Control" parent="VBox/TitleBar/HBox"]
margin_right = 110.0
margin_bottom = 30.0
rect_min_size = Vector2( 110, 0 )
mouse_filter = 2
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Passing" type="Label" parent="VBox/TitleBar/HBox/Summary"]
visible = false
margin_left = 5.0
margin_top = 7.0
margin_right = 45.0
margin_bottom = 21.0
custom_colors/font_color = Color( 0, 0, 0, 1 )
text = "0"
align = 1
valign = 1
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Failing" type="Label" parent="VBox/TitleBar/HBox/Summary"]
visible = false
margin_left = 100.0
margin_top = 7.0
margin_right = 140.0
margin_bottom = 21.0
custom_colors/font_color = Color( 0, 0, 0, 1 )
text = "0"
align = 1
valign = 1

[node name="AssertCount" type="Label" parent="VBox/TitleBar/HBox/Summary"]
margin_left = 5.0
margin_top = 7.0
margin_right = 165.0
margin_bottom = 21.0
custom_colors/font_color = Color( 0, 0, 0, 1 )
text = "Assert count"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="TitleReplacement" type="CenterContainer" parent="VBox/TitleBar/HBox"]
visible = false
margin_left = 114.0
margin_right = 352.0
margin_bottom = 30.0
rect_min_size = Vector2( 5, 0 )
mouse_filter = 2
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="Title" type="Label" parent="VBox/TitleBar/HBox"]
margin_left = 114.0
margin_right = 594.0
margin_bottom = 30.0
size_flags_horizontal = 3
size_flags_vertical = 7
custom_colors/font_color = Color( 0, 0, 0, 1 )
text = "Gut"
align = 1
valign = 1
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Time" type="Label" parent="VBox/TitleBar/HBox"]
margin_left = 598.0
margin_top = 7.0
margin_right = 654.0
margin_bottom = 22.0
custom_colors/font_color = Color( 0, 0, 0, 1 )
text = "9999.99"
valign = 1
__meta__ = {
"_edit_use_anchors_": false
}

[node name="CC" type="CenterContainer" parent="VBox/TitleBar/HBox"]
margin_left = 658.0
margin_right = 663.0
margin_bottom = 30.0
rect_min_size = Vector2( 5, 0 )
mouse_filter = 2

[node name="Minimize" type="Button" parent="VBox/TitleBar/HBox"]
margin_left = 667.0
margin_right = 697.0
margin_bottom = 30.0
rect_min_size = Vector2( 30, 0 )
custom_colors/font_color = Color( 0, 0, 0, 1 )
text = "N"
flat = true
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Maximize" type="Button" parent="VBox/TitleBar/HBox"]
margin_left = 701.0
margin_right = 731.0
margin_bottom = 30.0
rect_min_size = Vector2( 30, 0 )
custom_colors/font_color = Color( 0, 0, 0, 1 )
text = "X"
flat = true
__meta__ = {
"_edit_use_anchors_": false
}

[node name="CC2" type="CenterContainer" parent="VBox/TitleBar/HBox"]
margin_left = 735.0
margin_right = 740.0
margin_bottom = 30.0
rect_min_size = Vector2( 5, 0 )
mouse_filter = 2

[node name="TextDisplay" type="ColorRect" parent="VBox"]
margin_top = 34.0
margin_right = 740.0
margin_bottom = 176.0
size_flags_horizontal = 3
size_flags_vertical = 3
color = Color( 0, 0, 0, 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="RichTextLabel" type="RichTextLabel" parent="VBox/TextDisplay"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 10.0
rect_min_size = Vector2( 0, 116 )
focus_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
custom_fonts/bold_italics_font = SubResource( 4 )
custom_fonts/italics_font = SubResource( 5 )
custom_fonts/bold_font = SubResource( 6 )
custom_fonts/normal_font = SubResource( 7 )
bbcode_enabled = true
scroll_following = true
selection_enabled = true
__meta__ = {
"_edit_use_anchors_": false
}

[node name="WaitingLabel" type="RichTextLabel" parent="VBox/TextDisplay"]
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_top = -25.0
bbcode_enabled = true
__meta__ = {
"_edit_use_anchors_": false
}

[node name="BottomPanel" type="ColorRect" parent="VBox"]
margin_top = 180.0
margin_right = 740.0
margin_bottom = 300.0
rect_min_size = Vector2( 0, 120 )
size_flags_horizontal = 9
size_flags_vertical = 9
color = Color( 1, 1, 1, 0 )

[node name="VBox" type="VBoxContainer" parent="VBox/BottomPanel"]
anchor_right = 1.0
anchor_bottom = 1.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="HBox" type="HBoxContainer" parent="VBox/BottomPanel/VBox"]
margin_right = 740.0
margin_bottom = 80.0
size_flags_horizontal = 3

[node name="CC1" type="CenterContainer" parent="VBox/BottomPanel/VBox/HBox"]
margin_right = 5.0
margin_bottom = 80.0
rect_min_size = Vector2( 5, 0 )

[node name="Progress" type="VBoxContainer" parent="VBox/BottomPanel/VBox/HBox"]
margin_left = 9.0
margin_right = 179.0
margin_bottom = 80.0
rect_min_size = Vector2( 170, 0 )
alignment = 1

[node name="TestProgress" type="ProgressBar" parent="VBox/BottomPanel/VBox/HBox/Progress"]
margin_top = 11.0
margin_right = 100.0
margin_bottom = 36.0
rect_min_size = Vector2( 100, 25 )
hint_tooltip = "Test progress for the current script."
size_flags_horizontal = 0
step = 1.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Label" type="Label" parent="VBox/BottomPanel/VBox/HBox/Progress/TestProgress"]
margin_left = 107.5
margin_top = 3.0
margin_right = 172.5
margin_bottom = 18.0
text = "Tests"
valign = 1
__meta__ = {
"_edit_use_anchors_": false
}

[node name="xy" type="Label" parent="VBox/BottomPanel/VBox/HBox/Progress/TestProgress"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
text = "0/0"
align = 1
valign = 1
__meta__ = {
"_edit_use_anchors_": false
}

[node name="ScriptProgress" type="ProgressBar" parent="VBox/BottomPanel/VBox/HBox/Progress"]
margin_top = 40.0
margin_right = 100.0
margin_bottom = 65.0
rect_min_size = Vector2( 100, 25 )
hint_tooltip = "Overall progress of executing tests."
size_flags_horizontal = 0
step = 1.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Label" type="Label" parent="VBox/BottomPanel/VBox/HBox/Progress/ScriptProgress"]
margin_left = 107.0
margin_top = 3.5
margin_right = 172.0
margin_bottom = 18.5
text = "Scripts"
valign = 1
__meta__ = {
"_edit_use_anchors_": false
}

[node name="xy" type="Label" parent="VBox/BottomPanel/VBox/HBox/Progress/ScriptProgress"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
text = "0/0"
align = 1
valign = 1
__meta__ = {
"_edit_use_anchors_": false
}

[node name="CenterContainer" type="CenterContainer" parent="VBox/BottomPanel/VBox/HBox/Progress"]
margin_top = 69.0
margin_right = 170.0
margin_bottom = 69.0

[node name="CC2" type="CenterContainer" parent="VBox/BottomPanel/VBox/HBox"]
margin_left = 183.0
margin_right = 226.0
margin_bottom = 80.0
rect_min_size = Vector2( 5, 0 )
size_flags_horizontal = 3

[node name="Navigation" type="Panel" parent="VBox/BottomPanel/VBox/HBox"]
self_modulate = Color( 1, 1, 1, 0 )
margin_left = 230.0
margin_right = 580.0
margin_bottom = 80.0
rect_min_size = Vector2( 350, 80 )
__meta__ = {
"_edit_group_": true,
"_edit_use_anchors_": false
}

[node name="VBox" type="VBoxContainer" parent="VBox/BottomPanel/VBox/HBox/Navigation"]
anchor_right = 1.0
anchor_bottom = 1.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="CurrentScript" type="Button" parent="VBox/BottomPanel/VBox/HBox/Navigation/VBox"]
margin_right = 350.0
margin_bottom = 38.0
hint_tooltip = "Select a script to run.  You can run just this script, or this script and all scripts after using the run buttons."
size_flags_horizontal = 3
size_flags_vertical = 3
text = "res://test/unit/test_gut.gd"
clip_text = true
__meta__ = {
"_edit_use_anchors_": false
}

[node name="HBox" type="HBoxContainer" parent="VBox/BottomPanel/VBox/HBox/Navigation/VBox"]
margin_top = 42.0
margin_right = 350.0
margin_bottom = 80.0
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="Previous" type="Button" parent="VBox/BottomPanel/VBox/HBox/Navigation/VBox/HBox"]
margin_right = 84.0
margin_bottom = 38.0
hint_tooltip = "Previous script in the list."
size_flags_horizontal = 3
size_flags_vertical = 3
text = "|<"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Next" type="Button" parent="VBox/BottomPanel/VBox/HBox/Navigation/VBox/HBox"]
margin_left = 88.0
margin_right = 173.0
margin_bottom = 38.0
hint_tooltip = "Next script in the list.
"
size_flags_horizontal = 3
size_flags_vertical = 3
text = ">|"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Run" type="Button" parent="VBox/BottomPanel/VBox/HBox/Navigation/VBox/HBox"]
margin_left = 177.0
margin_right = 261.0
margin_bottom = 38.0
hint_tooltip = "Run the currently selected item and all after it."
size_flags_horizontal = 3
size_flags_vertical = 3
text = ">"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="RunSingleScript" type="Button" parent="VBox/BottomPanel/VBox/HBox/Navigation/VBox/HBox"]
margin_left = 265.0
margin_right = 350.0
margin_bottom = 38.0
hint_tooltip = "Run the currently selected item.

If the selected item has Inner Test Classes
then they will all be run.  If the selected item
is an Inner Test Class then only it will be run."
size_flags_horizontal = 3
size_flags_vertical = 3
text = "> (1)"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="CC3" type="CenterContainer" parent="VBox/BottomPanel/VBox/HBox"]
margin_left = 584.0
margin_right = 627.0
margin_bottom = 80.0
rect_min_size = Vector2( 5, 0 )
size_flags_horizontal = 3

[node name="Continue" type="VBoxContainer" parent="VBox/BottomPanel/VBox/HBox"]
self_modulate = Color( 1, 1, 1, 0 )
margin_left = 631.0
margin_right = 731.0
margin_bottom = 80.0
alignment = 1

[node name="ShowExtras" type="Button" parent="VBox/BottomPanel/VBox/HBox/Continue"]
margin_right = 50.0
margin_bottom = 35.0
rect_min_size = Vector2( 50, 35 )
rect_pivot_offset = Vector2( 35, 20 )
hint_tooltip = "Show/hide additional options."
size_flags_horizontal = 0
toggle_mode = true
text = "_"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Continue" type="Button" parent="VBox/BottomPanel/VBox/HBox/Continue"]
margin_top = 39.0
margin_right = 100.0
margin_bottom = 79.0
rect_min_size = Vector2( 100, 40 )
hint_tooltip = "When a pause_before_teardown is encountered this button will be enabled and must be pressed to continue running tests."
disabled = true
text = "Continue"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="CC4" type="CenterContainer" parent="VBox/BottomPanel/VBox/HBox"]
margin_left = 735.0
margin_right = 740.0
margin_bottom = 80.0
rect_min_size = Vector2( 5, 0 )

[node name="HBox2" type="HBoxContainer" parent="VBox/BottomPanel/VBox"]
margin_top = 84.0
margin_right = 740.0
margin_bottom = 114.0

[node name="CC" type="CenterContainer" parent="VBox/BottomPanel/VBox/HBox2"]
margin_right = 5.0
margin_bottom = 30.0
rect_min_size = Vector2( 5, 0 )

[node name="LogLevelSlider" type="HSlider" parent="VBox/BottomPanel/VBox/HBox2"]
margin_left = 9.0
margin_right = 109.0
margin_bottom = 30.0
rect_min_size = Vector2( 100, 30 )
size_flags_vertical = 3
max_value = 2.0
tick_count = 3
ticks_on_borders = true
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Label" type="Label" parent="VBox/BottomPanel/VBox/HBox2/LogLevelSlider"]
margin_left = 4.0
margin_top = -17.0
margin_right = 85.0
margin_bottom = 7.0
text = "Log Level"
valign = 1
__meta__ = {
"_edit_use_anchors_": false
}

[node name="CenterContainer" type="CenterContainer" parent="VBox/BottomPanel/VBox/HBox2"]
margin_left = 113.0
margin_right = 163.0
margin_bottom = 30.0
rect_min_size = Vector2( 50, 0 )

[node name="CurrentScriptLabel" type="Label" parent="VBox/BottomPanel/VBox/HBox2"]
margin_left = 167.0
margin_top = 7.0
margin_right = 740.0
margin_bottom = 22.0
size_flags_horizontal = 3
size_flags_vertical = 6
text = "res://test/unit/test_something.gd"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="ScriptsList" type="ItemList" parent="."]
visible = false
anchor_bottom = 1.0
margin_left = 179.0
margin_top = 40.0
margin_right = 619.0
margin_bottom = -110.0
allow_reselect = true
__meta__ = {
"_edit_use_anchors_": false
}

[node name="DoubleClickTimer" type="Timer" parent="ScriptsList"]
wait_time = 0.3
one_shot = true

[node name="ExtraOptions" type="Panel" parent="."]
visible = false
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -212.0
margin_top = -260.0
margin_right = -2.0
margin_bottom = -106.0
custom_styles/panel = SubResource( 8 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="IgnorePause" type="CheckBox" parent="ExtraOptions"]
margin_left = 17.5
margin_top = 4.5
margin_right = 162.5
margin_bottom = 29.5
rect_scale = Vector2( 1.2, 1.2 )
hint_tooltip = "Ignore all calls to pause_before_teardown."
text = "Ignore Pauses"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Copy" type="Button" parent="ExtraOptions"]
margin_left = 15.0
margin_top = 40.0
margin_right = 195.0
margin_bottom = 80.0
hint_tooltip = "Copy all output to the clipboard."
text = "Copy to Clipboard"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="UserFiles" type="Button" parent="ExtraOptions"]
margin_left = 15.0
margin_top = 90.0
margin_right = 195.0
margin_bottom = 130.0
hint_tooltip = "Copy all output to the clipboard."
text = "View User Files"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="ResizeHandle" type="Control" parent="."]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -40.0
margin_top = -40.0
__meta__ = {
"_edit_use_anchors_": false
}

[connection signal="mouse_entered" from="VBox/TitleBar" to="." method="_on_TitleBar_mouse_entered"]
[connection signal="mouse_exited" from="VBox/TitleBar" to="." method="_on_TitleBar_mouse_exited"]
[connection signal="draw" from="VBox/TitleBar/HBox/Minimize" to="." method="_on_Minimize_draw"]
[connection signal="pressed" from="VBox/TitleBar/HBox/Minimize" to="." method="_on_Minimize_pressed"]
[connection signal="draw" from="VBox/TitleBar/HBox/Maximize" to="." method="_on_Maximize_draw"]
[connection signal="pressed" from="VBox/TitleBar/HBox/Maximize" to="." method="_on_Maximize_pressed"]
[connection signal="gui_input" from="VBox/TextDisplay/RichTextLabel" to="." method="_on_RichTextLabel_gui_input"]
[connection signal="pressed" from="VBox/BottomPanel/VBox/HBox/Navigation/VBox/CurrentScript" to="." method="_on_CurrentScript_pressed"]
[connection signal="pressed" from="VBox/BottomPanel/VBox/HBox/Navigation/VBox/HBox/Previous" to="." method="_on_Previous_pressed"]
[connection signal="pressed" from="VBox/BottomPanel/VBox/HBox/Navigation/VBox/HBox/Next" to="." method="_on_Next_pressed"]
[connection signal="pressed" from="VBox/BottomPanel/VBox/HBox/Navigation/VBox/HBox/Run" to="." method="_on_Run_pressed"]
[connection signal="pressed" from="VBox/BottomPanel/VBox/HBox/Navigation/VBox/HBox/RunSingleScript" to="." method="_on_RunSingleScript_pressed"]
[connection signal="draw" from="VBox/BottomPanel/VBox/HBox/Continue/ShowExtras" to="." method="_on_ShowExtras_draw"]
[connection signal="toggled" from="VBox/BottomPanel/VBox/HBox/Continue/ShowExtras" to="." method="_on_ShowExtras_toggled"]
[connection signal="pressed" from="VBox/BottomPanel/VBox/HBox/Continue/Continue" to="." method="_on_Continue_pressed"]
[connection signal="value_changed" from="VBox/BottomPanel/VBox/HBox2/LogLevelSlider" to="." method="_on_LogLevelSlider_value_changed"]
[connection signal="item_selected" from="ScriptsList" to="." method="_on_ScriptsList_item_selected"]
[connection signal="pressed" from="ExtraOptions/IgnorePause" to="." method="_on_IgnorePause_pressed"]
[connection signal="pressed" from="ExtraOptions/Copy" to="." method="_on_Copy_pressed"]
[connection signal="pressed" from="ExtraOptions/UserFiles" to="." method="_on_UserFiles_pressed"]
[connection signal="mouse_entered" from="ResizeHandle" to="." method="_on_ResizeHandle_mouse_entered"]
[connection signal="mouse_exited" from="ResizeHandle" to="." method="_on_ResizeHandle_mouse_exited"]

--- Start of ./addons/gut/UserFileViewer.tscn ---

[gd_scene load_steps=2 format=2]

[ext_resource path="res://addons/gut/UserFileViewer.gd" type="Script" id=1]

[node name="UserFileViewer" type="WindowDialog"]
margin_top = 20.0
margin_right = 800.0
margin_bottom = 450.0
rect_min_size = Vector2( 800, 180 )
popup_exclusive = true
window_title = "View  File"
resizable = true
script = ExtResource( 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="FileDialog" type="FileDialog" parent="."]
margin_right = 416.0
margin_bottom = 184.0
rect_min_size = Vector2( 400, 140 )
rect_scale = Vector2( 2, 2 )
popup_exclusive = true
window_title = "Open a File"
resizable = true
mode = 0
access = 1
show_hidden_files = true
__meta__ = {
"_edit_use_anchors_": false
}

[node name="TextDisplay" type="ColorRect" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 8.0
margin_right = -10.0
margin_bottom = -65.0
color = Color( 0.2, 0.188235, 0.188235, 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="RichTextLabel" type="RichTextLabel" parent="TextDisplay"]
anchor_right = 1.0
anchor_bottom = 1.0
focus_mode = 2
text = "In publishing and graphic design, Lorem ipsum is a placeholder text commonly used to demonstrate the visual form of a document or a typeface without relying on meaningful content. Lorem ipsum may be used before final copy is available, but it may also be used to temporarily replace copy in a process called greeking, which allows designers to consider form without the meaning of the text influencing the design.

Lorem ipsum is typically a corrupted version of De finibus bonorum et malorum, a first-century BCE text by the Roman statesman and philosopher Cicero, with words altered, added, and removed to make it nonsensical, improper Latin.

Versions of the Lorem ipsum text have been used in typesetting at least since the 1960s, when it was popularized by advertisements for Letraset transfer sheets. Lorem ipsum was introduced to the digital world in the mid-1980s when Aldus employed it in graphic and word-processing templates for its desktop publishing program PageMaker. Other popular word processors including Pages and Microsoft Word have since adopted Lorem ipsum as well."
selection_enabled = true
__meta__ = {
"_edit_use_anchors_": false
}

[node name="OpenFile" type="Button" parent="."]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -158.0
margin_top = -50.0
margin_right = -84.0
margin_bottom = -30.0
rect_scale = Vector2( 2, 2 )
text = "Open File"

[node name="Home" type="Button" parent="."]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -478.0
margin_top = -50.0
margin_right = -404.0
margin_bottom = -30.0
rect_scale = Vector2( 2, 2 )
text = "Home"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Copy" type="Button" parent="."]
anchor_top = 1.0
anchor_bottom = 1.0
margin_left = 160.0
margin_top = -50.0
margin_right = 234.0
margin_bottom = -30.0
rect_scale = Vector2( 2, 2 )
text = "Copy"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="End" type="Button" parent="."]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -318.0
margin_top = -50.0
margin_right = -244.0
margin_bottom = -30.0
rect_scale = Vector2( 2, 2 )
text = "End"

[node name="Close" type="Button" parent="."]
anchor_top = 1.0
anchor_bottom = 1.0
margin_left = 10.0
margin_top = -50.0
margin_right = 80.0
margin_bottom = -30.0
rect_scale = Vector2( 2, 2 )
text = "Close"

[connection signal="file_selected" from="FileDialog" to="." method="_on_FileDialog_file_selected"]
[connection signal="popup_hide" from="FileDialog" to="." method="_on_FileDialog_popup_hide"]
[connection signal="pressed" from="OpenFile" to="." method="_on_OpenFile_pressed"]
[connection signal="pressed" from="Home" to="." method="_on_Home_pressed"]
[connection signal="pressed" from="Copy" to="." method="_on_Copy_pressed"]
[connection signal="pressed" from="End" to="." method="_on_End_pressed"]
[connection signal="pressed" from="Close" to="." method="_on_Close_pressed"]

--- Start of ./scenes/levels/game_world/main_game_scene.tscn ---

[gd_scene load_steps=18 format=2]

[ext_resource path="res://src/scenes/game_world/world_manager.gd" type="Script" id=1]
[ext_resource path="res://scenes/ui/hud/main_hud.tscn" type="PackedScene" id=2]
[ext_resource path="res://scenes/prefabs/camera/orbit_camera.tscn" type="PackedScene" id=3]
[ext_resource path="res://src/core/systems/agent_system.gd" type="Script" id=4]
[ext_resource path="res://src/core/systems/time_system.gd" type="Script" id=5]
[ext_resource path="res://src/core/systems/asset_system.gd" type="Script" id=7]
[ext_resource path="res://src/core/systems/character_system.gd" type="Script" id=8]
[ext_resource path="res://src/core/systems/event_system.gd" type="Script" id=10]
[ext_resource path="res://src/core/systems/inventory_system.gd" type="Script" id=15]
[ext_resource path="res://src/scenes/game_world/world_rendering.gd" type="Script" id=16]
[ext_resource path="res://scenes/ui/menus/main_menu.tscn" type="PackedScene" id=17]
[ext_resource path="res://scenes/ui/menus/debug_window.tscn" type="PackedScene" id=18]
[ext_resource path="res://scenes/ui/hud/sim_debug_panel.tscn" type="PackedScene" id=25]
[ext_resource path="res://src/core/simulation/simulation_engine.gd" type="Script" id=26]
[ext_resource path="res://src/core/systems/contact_manager.gd" type="Script" id=27]
[ext_resource path="res://src/core/ui/debug_map_panel/debug_map_panel.tscn" type="PackedScene" id=28]
[ext_resource path="res://scenes/prefabs/navigation/jump_transition_rig.tscn" type="PackedScene" id=29]

[node name="MainGameScene" type="Node"]

[node name="WorldManager" type="Node" parent="."]
script = ExtResource( 1 )

[node name="AgentSpawner" type="Node" parent="WorldManager"]
script = ExtResource( 4 )

[node name="AssetSystem" type="Node" parent="WorldManager"]
script = ExtResource( 7 )

[node name="CharacterSystem" type="Node" parent="WorldManager"]
script = ExtResource( 8 )

[node name="EventSystem" type="Node" parent="WorldManager"]
script = ExtResource( 10 )

[node name="InventorySystem" type="Node" parent="WorldManager"]
script = ExtResource( 15 )

[node name="TimeSystem" type="Node" parent="WorldManager"]
script = ExtResource( 5 )

[node name="SimulationEngine" type="Node" parent="WorldManager"]
script = ExtResource( 26 )

[node name="ContactManager" type="Node" parent="WorldManager"]
script = ExtResource( 27 )

[node name="WorldRendering" type="Node" parent="."]
script = ExtResource( 16 )

[node name="MainHUD" parent="." instance=ExtResource( 2 )]

[node name="DebugWindow" parent="." instance=ExtResource( 18 )]

[node name="MainMenu" parent="." instance=ExtResource( 17 )]

[node name="CurrentZoneContainer" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="OrbitCamera" parent="." instance=ExtResource( 3 )]

[node name="JumpTransitionRig" parent="." instance=ExtResource( 29 )]

[node name="SimDebugPanel" parent="." instance=ExtResource( 25 )]

[node name="DebugMapPanel" parent="." instance=ExtResource( 28 )]

--- Start of ./scenes/levels/sectors/sector_epsilon/Planet_epsilon.tscn ---

[gd_scene load_steps=10 format=2]

[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=1]
[ext_resource path="res://assets/art/shaders/simple_solid_NLP.gdshader" type="Shader" id=2]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=3]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/bw_noise/Craters 14 - 512x512.png" type="Texture" id=4]

[sub_resource type="SphereShape" id=1]
radius = 1000.0

[sub_resource type="SphereMesh" id=2]

[sub_resource type="ShaderMaterial" id=3]
shader = ExtResource( 2 )
shader_param/paint_color = Color( 0.55, 0.35, 0.5, 1 )
shader_param/light_tint = Color( 0.803922, 0.72549, 0.556863, 1 )
shader_param/shadow_tint = Color( 0.0862745, 0.0980392, 0.0901961, 1 )
shader_param/shadow_bias = 0.169
shader_param/shadow_softness = 0.292
shader_param/shadow_normal_blend = 0.317
shader_param/spec_tint = Color( 0.843137, 0.92549, 0.92549, 0.501961 )
shader_param/spec_intensity = 0.155
shader_param/spec_glossiness = 8.243
shader_param/spec_softness = 1.0
shader_param/rim_color = Color( 0.0196078, 0.00392157, 0.0509804, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = false
shader_param/detail_paint_scale = 0.222
shader_param/detail_paint_strength = 0.442
shader_param/detail_paint_contrast = 0.468
shader_param/detail_normal_scale = 3.507
shader_param/detail_normal_strength = 0.224
shader_param/uv_triplanar_sharpness = 100.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( -0.5, 0.3, -0.1 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/detail_texture = ExtResource( 4 )
shader_param/normal_texture = ExtResource( 3 )

[sub_resource type="BoxShape" id=4]

[sub_resource type="CubeMesh" id=5]

[node name="Planet_default" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 1000, 0, 0, 0, 1000, 0, 0, 0, 1000, 0, 0, 0 )

[node name="PlanetSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 3 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 1 )

[node name="StaticBody3" type="StaticBody" parent="."]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -340.234, 61.8828, -1450.97 )

[node name="CollisionShape" type="CollisionShape" parent="StaticBody3"]
shape = SubResource( 4 )

[node name="Model" type="Spatial" parent="StaticBody3"]

[node name="MeshInstance" type="MeshInstance" parent="StaticBody3/Model"]
transform = Transform( 1, 0, -1.77636e-15, 0, 1, 0, 1.77636e-15, 0, 1, 0, 0, 0 )
mesh = SubResource( 5 )
skeleton = NodePath("../../..")

--- Start of ./scenes/levels/sectors/sector_epsilon/sector_epsilon.tscn ---

[gd_scene load_steps=8 format=2]

[ext_resource path="res://src/core/utils/editor_object.gd" type="Script" id=1]
[ext_resource path="res://src/scenes/game_world/starsphere_slot.gd" type="Script" id=2]
[ext_resource path="res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn" type="PackedScene" id=3]
[ext_resource path="res://scenes/levels/sectors/sector_epsilon/Star_epsilon.tscn" type="PackedScene" id=4]
[ext_resource path="res://scenes/levels/sectors/sector_epsilon/Planet_epsilon.tscn" type="PackedScene" id=5]
[ext_resource path="res://scenes/levels/sectors/sector_epsilon/Station_epsilon.tscn" type="PackedScene" id=6]

[sub_resource type="SpatialMaterial" id=1]
flags_unshaded = true
params_cull_mode = 1
albedo_color = Color( 0, 0.0862745, 0.0901961, 1 )

[sub_resource type="SphereMesh" id=2]

[node name="SectorRoot" type="Spatial"]

[node name="_PlayableArea" type="MeshInstance" parent="."]
transform = Transform( 100000, 0, 0, 0, 100000, 0, 0, 0, 100000, 0, 0, 0 )
visible = false
material_override = SubResource( 1 )
mesh = SubResource( 2 )
script = ExtResource( 1 )

[node name="AgentContainer" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="StarsphereSlot" type="Spatial" parent="."]
script = ExtResource( 2 )
__meta__ = {
"_edit_lock_": true
}

[node name="Globalnebulas" parent="StarsphereSlot" instance=ExtResource( 3 )]

[node name="SceneAssets" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="Star" parent="SceneAssets" instance=ExtResource( 4 )]

[node name="Planet" parent="SceneAssets/Star" instance=ExtResource( 5 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 60000, -1000, 15000 )

[node name="Station" parent="SceneAssets" instance=ExtResource( 6 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 30000, -100, 25000 )

[node name="EntryPoint" type="Position3D" parent="SceneAssets"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 30200, -50, 24800 )

--- Start of ./scenes/levels/sectors/sector_epsilon/Star_epsilon.tscn ---

[gd_scene load_steps=12 format=2]

[ext_resource path="res://assets/art/materials/scene_materials/star_1_surface.tres" type="Material" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/materials/scene_materials/star_1_corona.tres" type="Material" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/materials/scene_materials/star_1_sprite.tres" type="Material" id=5]

[sub_resource type="SphereShape" id=1]
radius = 5000.0

[sub_resource type="SphereMesh" id=2]

[sub_resource type="SphereMesh" id=3]
radial_segments = 32

[sub_resource type="Shader" id=4]
code = "shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	//diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;


void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
}
"

[sub_resource type="ShaderMaterial" id=5]
shader = SubResource( 4 )
shader_param/albedo = Color( 0.22, 0.1, 0.03, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.357
shader_param/rim_outer_strength = 2.49
shader_param/rim_outer_exponent = 6.108

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star_default" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 4640.9, 1859.4, -68.6439, -1843.2, 4568.96, -852.759, -254.4, 816.817, 4926.26, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = ExtResource( 1 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = ExtResource( 3 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = ExtResource( 5 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 5 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 1.0, 0.8, 0.55, 1 )
light_energy = 1.5
omni_range = 100000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]

--- Start of ./scenes/levels/sectors/sector_epsilon/Station_epsilon.tscn ---

[gd_scene load_steps=6 format=2]

[ext_resource path="res://src/scenes/game_world/station/dockable_station.gd" type="Script" id=1]
[ext_resource path="res://assets/art/materials/test_solid_glow.tres" type="Material" id=2]

[sub_resource type="SphereShape" id=1]
radius = 20.0

[sub_resource type="CubeMesh" id=2]
size = Vector3( 10, 10, 10 )

[sub_resource type="SphereShape" id=3]
radius = 279.495

[node name="Station_epsilon" type="StaticBody"]
script = ExtResource( 1 )
location_id = "station_epsilon"
station_name = "Epsilon Refinery Complex"

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="MeshInstance" type="MeshInstance" parent="."]
transform = Transform( 2.97317, 0, 0, 0, 2.97317, 0, 0, 0, 2.97317, 0, 0, 0 )
material_override = ExtResource( 2 )
mesh = SubResource( 2 )

[node name="DockingZone" type="Area" parent="."]

[node name="CollisionShape" type="CollisionShape" parent="DockingZone"]
shape = SubResource( 3 )

--- Start of ./scenes/levels/sectors/sector_gamma/Planet_gamma.tscn ---

[gd_scene load_steps=10 format=2]

[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=1]
[ext_resource path="res://assets/art/shaders/simple_solid_NLP.gdshader" type="Shader" id=2]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=3]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/bw_noise/Craters 14 - 512x512.png" type="Texture" id=4]

[sub_resource type="SphereShape" id=1]
radius = 1000.0

[sub_resource type="ShaderMaterial" id=3]
shader = ExtResource( 2 )
shader_param/paint_color = Color( 0.75, 0.35, 0.25, 1 )
shader_param/light_tint = Color( 0.803922, 0.72549, 0.556863, 1 )
shader_param/shadow_tint = Color( 0.0862745, 0.0980392, 0.0901961, 1 )
shader_param/shadow_bias = 0.169
shader_param/shadow_softness = 0.292
shader_param/shadow_normal_blend = 0.317
shader_param/spec_tint = Color( 0.843137, 0.92549, 0.92549, 0.501961 )
shader_param/spec_intensity = 0.155
shader_param/spec_glossiness = 8.243
shader_param/spec_softness = 1.0
shader_param/rim_color = Color( 0.0196078, 0.00392157, 0.0509804, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = false
shader_param/detail_paint_scale = 0.222
shader_param/detail_paint_strength = 0.442
shader_param/detail_paint_contrast = 0.468
shader_param/detail_normal_scale = 3.507
shader_param/detail_normal_strength = 0.224
shader_param/uv_triplanar_sharpness = 100.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( -0.3, 0.1, 0.7 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/detail_texture = ExtResource( 4 )
shader_param/normal_texture = ExtResource( 3 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="BoxShape" id=4]

[sub_resource type="CubeMesh" id=5]

[node name="Planet_default" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 1000, 0, 0, 0, 1000, 0, 0, 0, 1000, 0, 0, 0 )

[node name="PlanetSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 3 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 1 )

[node name="StaticBody3" type="StaticBody" parent="."]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -340.234, 61.8828, -1450.97 )

[node name="CollisionShape" type="CollisionShape" parent="StaticBody3"]
shape = SubResource( 4 )

[node name="Model" type="Spatial" parent="StaticBody3"]

[node name="MeshInstance" type="MeshInstance" parent="StaticBody3/Model"]
transform = Transform( 1, 0, -1.77636e-15, 0, 1, 0, 1.77636e-15, 0, 1, 0, 0, 0 )
mesh = SubResource( 5 )
skeleton = NodePath("../../..")

--- Start of ./scenes/levels/sectors/sector_gamma/sector_gamma.tscn ---

[gd_scene load_steps=8 format=2]

[ext_resource path="res://src/core/utils/editor_object.gd" type="Script" id=1]
[ext_resource path="res://src/scenes/game_world/starsphere_slot.gd" type="Script" id=2]
[ext_resource path="res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn" type="PackedScene" id=3]
[ext_resource path="res://scenes/levels/sectors/sector_gamma/Star_gamma.tscn" type="PackedScene" id=4]
[ext_resource path="res://scenes/levels/sectors/sector_gamma/Planet_gamma.tscn" type="PackedScene" id=5]
[ext_resource path="res://scenes/levels/sectors/sector_gamma/Station_gamma.tscn" type="PackedScene" id=6]

[sub_resource type="SpatialMaterial" id=1]
flags_unshaded = true
params_cull_mode = 1
albedo_color = Color( 0, 0.0862745, 0.0901961, 1 )

[sub_resource type="SphereMesh" id=2]

[node name="SectorRoot" type="Spatial"]

[node name="_PlayableArea" type="MeshInstance" parent="."]
transform = Transform( 100000, 0, 0, 0, 100000, 0, 0, 0, 100000, 0, 0, 0 )
visible = false
material_override = SubResource( 1 )
mesh = SubResource( 2 )
script = ExtResource( 1 )

[node name="AgentContainer" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="StarsphereSlot" type="Spatial" parent="."]
script = ExtResource( 2 )
__meta__ = {
"_edit_lock_": true
}

[node name="Globalnebulas" parent="StarsphereSlot" instance=ExtResource( 3 )]

[node name="SceneAssets" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="Star" parent="SceneAssets" instance=ExtResource( 4 )]

[node name="Planet" parent="SceneAssets/Star" instance=ExtResource( 5 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 55000, -3000, -5000 )

[node name="Station" parent="SceneAssets" instance=ExtResource( 6 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 35000, -300, 20000 )

[node name="EntryPoint" type="Position3D" parent="SceneAssets"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 35200, -250, 19800 )

--- Start of ./scenes/levels/sectors/sector_gamma/Star_gamma.tscn ---

[gd_scene load_steps=12 format=2]

[ext_resource path="res://assets/art/materials/scene_materials/star_1_surface.tres" type="Material" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/materials/scene_materials/star_1_corona.tres" type="Material" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/materials/scene_materials/star_1_sprite.tres" type="Material" id=5]

[sub_resource type="SphereShape" id=1]
radius = 5000.0

[sub_resource type="SphereMesh" id=2]

[sub_resource type="SphereMesh" id=3]
radial_segments = 32

[sub_resource type="Shader" id=4]
code = "shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	//diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;


void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
}
"

[sub_resource type="ShaderMaterial" id=5]
shader = SubResource( 4 )
shader_param/albedo = Color( 0.2, 0.06, 0.02, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.357
shader_param/rim_outer_strength = 2.49
shader_param/rim_outer_exponent = 6.108

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star_default" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 4640.9, 1859.4, -68.6439, -1843.2, 4568.96, -852.759, -254.4, 816.817, 4926.26, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = ExtResource( 1 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = ExtResource( 3 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = ExtResource( 5 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 5 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 1.0, 0.75, 0.6, 1 )
light_energy = 1.5
omni_range = 100000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]

--- Start of ./scenes/levels/sectors/sector_gamma/Station_gamma.tscn ---

[gd_scene load_steps=6 format=2]

[ext_resource path="res://src/scenes/game_world/station/dockable_station.gd" type="Script" id=1]
[ext_resource path="res://assets/art/materials/test_solid_glow.tres" type="Material" id=2]

[sub_resource type="SphereShape" id=1]
radius = 20.0

[sub_resource type="CubeMesh" id=2]
size = Vector3( 10, 10, 10 )

[sub_resource type="SphereShape" id=3]
radius = 279.495

[node name="Station_gamma" type="StaticBody"]
script = ExtResource( 1 )
location_id = "station_gamma"
station_name = "Freeport Gamma"

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="MeshInstance" type="MeshInstance" parent="."]
transform = Transform( 2.97317, 0, 0, 0, 2.97317, 0, 0, 0, 2.97317, 0, 0, 0 )
material_override = ExtResource( 2 )
mesh = SubResource( 2 )

[node name="DockingZone" type="Area" parent="."]

[node name="CollisionShape" type="CollisionShape" parent="DockingZone"]
shape = SubResource( 3 )

--- Start of ./scenes/levels/sectors/sector_system_cob/sector_system_cob.tscn ---

[gd_scene load_steps=9 format=2]

[ext_resource path="res://src/core/utils/editor_object.gd" type="Script" id=1]
[ext_resource path="res://src/scenes/game_world/starsphere_slot.gd" type="Script" id=2]
[ext_resource path="res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn" type="PackedScene" id=3]
[ext_resource path="res://scenes/levels/sectors/sector_system_cob/star_cob/star_cob.tscn" type="PackedScene" id=4]
[ext_resource path="res://scenes/levels/sectors/sector_system_cob/star_cob/planet_cob_a.tscn" type="PackedScene" id=5]
[ext_resource path="res://scenes/levels/sectors/sector_system_cob/star_cob/planet_cob_a/station_cob_a1.tscn" type="PackedScene" id=6]

[sub_resource type="SpatialMaterial" id=1]
flags_unshaded = true
params_cull_mode = 1
albedo_color = Color( 0, 0.0862745, 0.0901961, 1 )

[sub_resource type="SphereMesh" id=2]

[node name="Sector System Cob" type="Spatial"]

[node name="_PlayableArea" type="MeshInstance" parent="."]
transform = Transform( 100000, 0, 0, 0, 100000, 0, 0, 0, 100000, 0, 0, 0 )
visible = false
material_override = SubResource( 1 )
mesh = SubResource( 2 )
script = ExtResource( 1 )

[node name="AgentContainer" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="StarsphereSlot" type="Spatial" parent="."]
script = ExtResource( 2 )
__meta__ = {
"_edit_lock_": true
}

[node name="Globalnebulas" parent="StarsphereSlot" instance=ExtResource( 3 )]
visible = false

[node name="SceneAssets" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="Star Cob" parent="SceneAssets" instance=ExtResource( 4 )]

[node name="Planet Cob a" parent="SceneAssets/Star Cob" instance=ExtResource( 5 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 42517.2, 17201.1, -6824.56 )

[node name="Station Cob a1" parent="SceneAssets/Star Cob/Planet Cob a" instance=ExtResource( 6 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 434.594, -2165.58, 6938.93 )

[node name="EntryPoint" type="Position3D" parent="SceneAssets"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 45200, 550, 7800 )

--- Start of ./scenes/levels/sectors/sector_system_cob/star_cob/planet_cob_a/station_cob_a1.tscn ---

[gd_scene load_steps=6 format=2]

[ext_resource path="res://src/scenes/game_world/station/dockable_station.gd" type="Script" id=1]
[ext_resource path="res://assets/art/materials/test_solid_glow.tres" type="Material" id=2]

[sub_resource type="SphereShape" id=1]
radius = 20.0

[sub_resource type="CubeMesh" id=2]
size = Vector3( 10, 10, 10 )

[sub_resource type="SphereShape" id=3]
radius = 279.495

[node name="Station_beta" type="StaticBody"]
script = ExtResource( 1 )
location_id = "station_beta"
station_name = "Station Beta - Trade Post"

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="MeshInstance" type="MeshInstance" parent="."]
transform = Transform( 2.97317, 0, 0, 0, 2.97317, 0, 0, 0, 2.97317, 0, 0, 0 )
material_override = ExtResource( 2 )
mesh = SubResource( 2 )

[node name="DockingZone" type="Area" parent="."]

[node name="CollisionShape" type="CollisionShape" parent="DockingZone"]
shape = SubResource( 3 )

--- Start of ./scenes/levels/sectors/sector_system_cob/star_cob/planet_cob_a.tscn ---

[gd_scene load_steps=8 format=2]

[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=1]
[ext_resource path="res://assets/art/shaders/simple_solid_NLP.gdshader" type="Shader" id=2]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/bw_noise/Grainy 11 - 512x512.png" type="Texture" id=3]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Milky 11 - 512x512.png" type="Texture" id=4]

[sub_resource type="SphereShape" id=1]
radius = 3000.0

[sub_resource type="ShaderMaterial" id=3]
shader = ExtResource( 2 )
shader_param/paint_color = Color( 0.270588, 0.384314, 0.305882, 1 )
shader_param/light_tint = Color( 0.803922, 0.72549, 0.556863, 1 )
shader_param/shadow_tint = Color( 0.0117647, 0.0941176, 0.0392157, 1 )
shader_param/shadow_bias = 0.169
shader_param/shadow_softness = 0.292
shader_param/shadow_normal_blend = 0.317
shader_param/spec_tint = Color( 0.843137, 0.92549, 0.92549, 0.501961 )
shader_param/spec_intensity = 0.042
shader_param/spec_glossiness = 8.243
shader_param/spec_softness = 1.0
shader_param/rim_color = Color( 0.0352941, 0.00392157, 0.0980392, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = true
shader_param/detail_paint_scale = 0.522
shader_param/detail_paint_strength = -0.233
shader_param/detail_paint_contrast = 1.726
shader_param/detail_normal_scale = 2.715
shader_param/detail_normal_strength = -0.858
shader_param/uv_triplanar_sharpness = 100.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( 0.2, 0.5, 0.1 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/detail_texture = ExtResource( 3 )
shader_param/normal_texture = ExtResource( 4 )

[sub_resource type="SphereMesh" id=2]

[node name="Planet_default" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 3000, 0, 0, 0, 3000, 0, 0, 0, 3000, 0, 0, 0 )

[node name="PlanetSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 3 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 1 )

[node name="DirectionalLight" type="DirectionalLight" parent="."]
editor_only = true

--- Start of ./scenes/levels/sectors/sector_system_cob/star_cob/star_cob.tscn ---

[gd_scene load_steps=18 format=2]

[ext_resource path="res://assets/art/shaders/star_surface_NLP.gdshader" type="Shader" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/shaders/star_sprite.gdshader" type="Shader" id=5]
[ext_resource path="res://assets/art/shaders/star_corona_NLP.gdshader" type="Shader" id=6]

[sub_resource type="SphereShape" id=1]
radius = 10000.0

[sub_resource type="ShaderMaterial" id=25]
shader = ExtResource( 1 )
shader_param/rim_color = Color( 1, 1, 1, 1 )
shader_param/overlay_color = Color( 0.215686, 0.615686, 0.568627, 1 )
shader_param/surface_color = Color( 0.647059, 0.639216, 0.85098, 1 )
shader_param/fade_color = Color( 0.662745, 0.909804, 0.803922, 1 )
shader_param/major_phase = 0.95
shader_param/major_detail_intensity = 1.0
shader_param/major_detail_level = 0.5
shader_param/detail_decay_distance = 30000.0
shader_param/detail_decay_power = 2.0
shader_param/major_detail_scale = 1.0
shader_param/major_detail_flow = 0.01
shader_param/rim_strength = 1.0
shader_param/rim_exponent = 0.03
shader_param/rim_intensity = 10.0
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 25.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/major_detail_noise = ExtResource( 3 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="OpenSimplexNoise" id=23]

[sub_resource type="NoiseTexture" id=24]
width = 256
height = 256
seamless = true
noise = SubResource( 23 )

[sub_resource type="ShaderMaterial" id=26]
shader = ExtResource( 6 )
shader_param/corona_color = Color( 0.14902, 0.32549, 0.345098, 1 )
shader_param/strength_corona = 40.0
shader_param/exponent_corona = 2.0
shader_param/exponent_corona_rim = 2.0
shader_param/corona_floor_power = 5.0
shader_param/corona_floor = 1.3
shader_param/displacement_power = 0.05
shader_param/displacement_scale_xz = 0.95
shader_param/displacement_scale_y = 0.9
shader_param/displacement_velocity = 0.1
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 27.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/displacement_texture = SubResource( 24 )

[sub_resource type="SphereMesh" id=3]
radial_segments = 32

[sub_resource type="ShaderMaterial" id=27]
shader = ExtResource( 5 )
shader_param/albedo = Color( 0.435294, 1, 0.72549, 1 )
shader_param/scale = 0.708
shader_param/flare_distance = 40000.0
shader_param/flare_size = 3.0
shader_param/attenuation = 0.749
shader_param/intensity = 1.0
shader_param/exponent = 3.0
shader_param/pulse_factor = 0.9
shader_param/pulse_rate = 1.0
shader_param/phase = 0.0
shader_param/Fcoef = 0.001

[sub_resource type="Shader" id=4]
code = "shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	//diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;


void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
}
"

[sub_resource type="ShaderMaterial" id=5]
shader = SubResource( 4 )
shader_param/albedo = Color( 0.07, 0.1, 0.18, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.357
shader_param/rim_outer_strength = 2.49
shader_param/rim_outer_exponent = 6.108

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star Cob" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 9281.79, 3718.8, -137.285, -3686.4, 9137.91, -1705.51, -508.799, 1633.63, 9852.51, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 25 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = SubResource( 26 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = SubResource( 27 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 5 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 0.505882, 0.85098, 0.898039, 1 )
light_energy = 1.5
omni_range = 100000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]

--- Start of ./scenes/levels/sectors/sector_system_elace/sector_system_elace.tscn ---

[gd_scene load_steps=10 format=2]

[ext_resource path="res://src/core/utils/editor_object.gd" type="Script" id=1]
[ext_resource path="res://src/scenes/game_world/starsphere_slot.gd" type="Script" id=2]
[ext_resource path="res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn" type="PackedScene" id=3]
[ext_resource path="res://scenes/levels/sectors/sector_system_elace/star_elace.tscn" type="PackedScene" id=4]
[ext_resource path="res://scenes/levels/sectors/sector_system_elace/star_elace/planet_elace_a.tscn" type="PackedScene" id=5]
[ext_resource path="res://scenes/levels/sectors/sector_system_elace/star_elace/planet_elace_a/station_elace_a1.tscn" type="PackedScene" id=6]
[ext_resource path="res://scenes/levels/sectors/sector_system_elace/star_elace/planet_elace_a/moon_elace_a1.tscn" type="PackedScene" id=7]

[sub_resource type="SpatialMaterial" id=1]
flags_unshaded = true
params_cull_mode = 1
albedo_color = Color( 0, 0.0862745, 0.0901961, 1 )

[sub_resource type="SphereMesh" id=2]

[node name="Sector System Elace" type="Spatial"]

[node name="_PlayableArea" type="MeshInstance" parent="."]
transform = Transform( 100000, 0, 0, 0, 100000, 0, 0, 0, 100000, 0, 0, 0 )
visible = false
material_override = SubResource( 1 )
mesh = SubResource( 2 )
script = ExtResource( 1 )

[node name="AgentContainer" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="StarsphereSlot" type="Spatial" parent="."]
script = ExtResource( 2 )
__meta__ = {
"_edit_lock_": true
}

[node name="Globalnebulas" parent="StarsphereSlot" instance=ExtResource( 3 )]

[node name="SceneAssets" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="Star Elace" parent="SceneAssets" instance=ExtResource( 4 )]

[node name="Planet Elace a" parent="SceneAssets/Star Elace" instance=ExtResource( 5 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 50000, 0, 0 )

[node name="Moon Elace a1" parent="SceneAssets/Star Elace/Planet Elace a" instance=ExtResource( 7 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -5536.92, -466.164, -3921.63 )

[node name="Station Elace a1" parent="SceneAssets/Star Elace/Planet Elace a" instance=ExtResource( 6 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 500, -929, -1570 )

[node name="EntryPoint" type="Position3D" parent="SceneAssets"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 50700, 100, -1600 )

--- Start of ./scenes/levels/sectors/sector_system_elace/star_elace/planet_elace_a/moon_elace_a1.tscn ---

[gd_scene load_steps=8 format=2]

[ext_resource path="res://assets/art/shaders/simple_solid_NLP.gdshader" type="Shader" id=1]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=2]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 1 - 512x512.png" type="Texture" id=3]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/bw_noise/Craters 14 - 512x512.png" type="Texture" id=4]

[sub_resource type="SphereShape" id=1]
radius = 300.0

[sub_resource type="ShaderMaterial" id=3]
shader = ExtResource( 1 )
shader_param/paint_color = Color( 0.196078, 0.196078, 0.196078, 1 )
shader_param/light_tint = Color( 1, 1, 1, 1 )
shader_param/shadow_tint = Color( 0, 0, 0, 1 )
shader_param/shadow_bias = 0.087
shader_param/shadow_softness = 0.33
shader_param/shadow_normal_blend = 0.625
shader_param/spec_tint = Color( 0.843137, 0.92549, 0.92549, 0.501961 )
shader_param/spec_intensity = 0.155
shader_param/spec_glossiness = 8.243
shader_param/spec_softness = 1.0
shader_param/rim_color = Color( 0.0196078, 0.00392157, 0.0509804, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = false
shader_param/detail_paint_scale = 0.168
shader_param/detail_paint_strength = 0.101
shader_param/detail_paint_contrast = 1.655
shader_param/detail_normal_scale = 0.852
shader_param/detail_normal_strength = -0.34
shader_param/uv_triplanar_sharpness = 100.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( -0.26, 0.455, -0.343 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/detail_texture = ExtResource( 4 )
shader_param/normal_texture = ExtResource( 3 )

[sub_resource type="SphereMesh" id=2]

[node name="Moon Elace a1" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 300, 0, 0, 0, 300, 0, 0, 0, 300, 0, 0, 0 )

[node name="PlanetSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 3 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 2 )

[node name="DirectionalLight" type="DirectionalLight" parent="."]
editor_only = true

--- Start of ./scenes/levels/sectors/sector_system_elace/star_elace/planet_elace_a/station_elace_a1.tscn ---

[gd_scene load_steps=6 format=2]

[ext_resource path="res://src/scenes/game_world/station/dockable_station.gd" type="Script" id=1]
[ext_resource path="res://assets/art/materials/test_solid_glow.tres" type="Material" id=2]

[sub_resource type="CubeMesh" id=2]
size = Vector3( 10, 10, 10 )

[sub_resource type="SphereShape" id=3]
radius = 279.495

[sub_resource type="BoxShape" id=4]
extents = Vector3( 1.193, 1, 1 )

[node name="Station Elace a1" type="StaticBody"]
script = ExtResource( 1 )
station_name = "Elace System - Mining Hub"

[node name="MeshInstance" type="MeshInstance" parent="."]
transform = Transform( 0.388501, 0, 0, 0, 0.299779, 0, 0, 0, 2.97317, 0, 0, 0 )
material_override = ExtResource( 2 )
mesh = SubResource( 2 )

[node name="DockingZone" type="Area" parent="."]

[node name="CollisionShape" type="CollisionShape" parent="DockingZone"]
shape = SubResource( 3 )

[node name="DirectionalLight" type="DirectionalLight" parent="."]
editor_only = true

[node name="CollisionShape" type="CollisionShape" parent="."]
transform = Transform( 0.838296, 0, 0, 0, 2.34779, 0, 0, 0, 15.5312, 0, 0, 0 )
shape = SubResource( 4 )

--- Start of ./scenes/levels/sectors/sector_system_elace/star_elace/planet_elace_a.tscn ---

[gd_scene load_steps=8 format=2]

[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=1]
[ext_resource path="res://assets/art/shaders/simple_solid_NLP.gdshader" type="Shader" id=2]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 1 - 512x512.png" type="Texture" id=3]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/bw_noise/Craters 14 - 512x512.png" type="Texture" id=4]

[sub_resource type="SphereShape" id=1]
radius = 1000.0

[sub_resource type="ShaderMaterial" id=3]
shader = ExtResource( 2 )
shader_param/paint_color = Color( 0.7, 0.55, 0.35, 1 )
shader_param/light_tint = Color( 0.803922, 0.72549, 0.556863, 1 )
shader_param/shadow_tint = Color( 0.0862745, 0.0980392, 0.0901961, 1 )
shader_param/shadow_bias = 0.087
shader_param/shadow_softness = 0.292
shader_param/shadow_normal_blend = 0.317
shader_param/spec_tint = Color( 0.843137, 0.92549, 0.92549, 0.501961 )
shader_param/spec_intensity = 0.155
shader_param/spec_glossiness = 8.243
shader_param/spec_softness = 1.0
shader_param/rim_color = Color( 0.0196078, 0.00392157, 0.0509804, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = false
shader_param/detail_paint_scale = 0.222
shader_param/detail_paint_strength = 0.274
shader_param/detail_paint_contrast = 0.763
shader_param/detail_normal_scale = 3.507
shader_param/detail_normal_strength = -0.184
shader_param/uv_triplanar_sharpness = 100.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( 0.636, 0.795, -0.423 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/detail_texture = ExtResource( 4 )
shader_param/normal_texture = ExtResource( 3 )

[sub_resource type="SphereMesh" id=2]

[node name="Planet Elace a" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 1000, 0, 0, 0, 1000, 0, 0, 0, 1000, 0, 0, 0 )

[node name="PlanetSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 3 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 1 )

[node name="DirectionalLight" type="DirectionalLight" parent="."]
editor_only = true

--- Start of ./scenes/levels/sectors/sector_system_elace/star_elace.tscn ---

[gd_scene load_steps=14 format=2]

[ext_resource path="res://assets/art/materials/scene_materials/star_1_surface.tres" type="Material" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/materials/scene_materials/star_1_corona.tres" type="Material" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/materials/scene_materials/star_1_sprite.tres" type="Material" id=5]
[ext_resource path="res://assets/art/shaders/star_sprite.gdshader" type="Shader" id=6]

[sub_resource type="SphereShape" id=1]
radius = 5000.0

[sub_resource type="SphereMesh" id=2]

[sub_resource type="SphereMesh" id=3]
rings = 64

[sub_resource type="ShaderMaterial" id=8]
shader = ExtResource( 6 )
shader_param/albedo = Color( 1, 0.603922, 0.427451, 1 )
shader_param/scale_near = 2.948
shader_param/scale_peak = 0.2
shader_param/scale_far = 0.05
shader_param/peak_distance = 40000.0
shader_param/fade_ratio = 10.0
shader_param/distance_power = 0.3
shader_param/fade_distance_near = 0.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.4
shader_param/intensity = 0.762
shader_param/exponent = 3.0

[sub_resource type="Shader" id=4]
code = "shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	//diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;


void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
}
"

[sub_resource type="ShaderMaterial" id=5]
shader = SubResource( 4 )
shader_param/albedo = Color( 0.176471, 0.12549, 0.054902, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.357
shader_param/rim_outer_strength = 2.49
shader_param/rim_outer_exponent = 6.108

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star Elace" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 4640.9, 1859.4, -68.6439, -1843.2, 4568.96, -852.759, -254.4, 816.817, 4926.26, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = ExtResource( 1 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = ExtResource( 3 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = ExtResource( 5 )

[node name="Star_sprite_square_wide_far" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide_far" index="0"]
material_override = SubResource( 8 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 5 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 0.921569, 0.894118, 0.835294, 1 )
light_energy = 1.5
omni_range = 100000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]
[editable path="ModelAdditional/Star_sprite_square_wide_far"]

--- Start of ./scenes/levels/sectors/sector_system_lywin/sector_system_lywin.tscn ---

[gd_scene load_steps=17 format=2]

[ext_resource path="res://src/core/utils/editor_object.gd" type="Script" id=1]
[ext_resource path="res://src/scenes/game_world/starsphere_slot.gd" type="Script" id=2]
[ext_resource path="res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn" type="PackedScene" id=3]
[ext_resource path="res://scenes/levels/sectors/sector_system_lywin/stars_lywin/stars_satellites/star_lywin_B.tscn" type="PackedScene" id=4]
[ext_resource path="res://scenes/levels/sectors/sector_system_lywin/stars_lywin/stars_satellites/star_lywin_C.tscn" type="PackedScene" id=5]
[ext_resource path="res://scenes/levels/sectors/sector_system_lywin/stars_lywin/stars_satellites/star_lywin_D.tscn" type="PackedScene" id=6]
[ext_resource path="res://scenes/levels/sectors/sector_system_lywin/stars_lywin/stars_satellites/star_lywin_E.tscn" type="PackedScene" id=7]
[ext_resource path="res://scenes/levels/sectors/sector_system_lywin/stars_lywin/star_lywin_A.tscn" type="PackedScene" id=8]
[ext_resource path="res://scenes/levels/sectors/sector_system_lywin/stars_lywin/planet_lywin_A_a.tscn" type="PackedScene" id=9]

[sub_resource type="SpatialMaterial" id=1]
flags_unshaded = true
params_cull_mode = 1
albedo_color = Color( 0, 0.0862745, 0.0901961, 1 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="Shader" id=7]
code = "shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform float vertex_mask_power = 1.0;
uniform float vertex_mask_overlay = 0.0;
uniform float albedo_strength = 1.0;


uniform float lum_weight_r = 1.0;
uniform float lum_weight_g = 1.0;
uniform float lum_weight_b = 1.0;

uniform float color_power_r = 1.0;
uniform float color_power_g = 1.0;
uniform float color_power_b = 1.0;
uniform float color_multiplier_r = 1.0;
uniform float color_multiplier_g = 1.0;
uniform float color_multiplier_b = 1.0;

uniform vec4 albedo : hint_color;
uniform vec4 albedo_rim : hint_color;
uniform vec4 albedo_ambient : hint_color;

uniform float normal_intensity = 1.0;
uniform float normal_detail_power = 1.0;
uniform float normal_detail_factor = 1.0;
uniform float normal_strength = 1.0;
uniform float normal_detail_clamp = 1.0;

uniform float rim_factor = 1.0;
uniform float rim_strength = 1.0;
uniform float rim_exponent = 1.0;
uniform float rim_ambient_exponent = 1.0;

uniform float fade_distance_near = 1e5;
uniform float fade_distance_far = 1e6;
uniform float fade_power = .2;

uniform float uv1_blend_sharpness = 10.0;

uniform float normal_detail_uv1_scale = 1.0;
uniform vec3 normal_detail_uv1_offset = vec3(0.0);


// Non-linear perspective
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

uniform sampler2D normal_noise;

const float pi = 3.1415926535;
	

varying vec3 uv1_triplanar_pos;
varying vec3 normal_detail_uv1_triplanar_pos;
varying vec3 uv1_power_normal;



void vertex() {
	vec3 normal = NORMAL;
	TANGENT = vec3(0.0,0.0,-1.0) * abs(normal.x);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(normal.y);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(normal.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0,1.0,0.0) * abs(normal.x);
	BINORMAL+= vec3(0.0,0.0,-1.0) * abs(normal.y);
	BINORMAL+= vec3(0.0,1.0,0.0) * abs(normal.z);
	BINORMAL = normalize(BINORMAL);
	uv1_power_normal=pow(abs(NORMAL),vec3(uv1_blend_sharpness));
	uv1_triplanar_pos = VERTEX * pow(2.0, normal_detail_uv1_scale) + normal_detail_uv1_offset;
	normal_detail_uv1_triplanar_pos = VERTEX * pow(2.0, normal_detail_uv1_scale) + normal_detail_uv1_offset;
	uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);
	normal_detail_uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);
	
	// --- Non-linear perspective (based on distance) ---
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
}


vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
	vec4 samp=vec4(0.0);
	samp+= texture(p_sampler,p_triplanar_pos.xy) * p_weights.z;
	samp+= texture(p_sampler,p_triplanar_pos.xz) * p_weights.y;
	samp+= texture(p_sampler,p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}

void fragment()
{
	// Get tangent, binormal and normal of the vertex.
	vec3 N = normalize(NORMAL);
	vec3 T = normalize(TANGENT);
	vec3 B = normalize(BINORMAL);

	// Get texture data.
	// Normal textures.
	vec4 nm_detail_minor_noise = triplanar_texture(
		normal_noise,
		uv1_power_normal,
		normal_detail_uv1_triplanar_pos);
	vec3 nm_detail_minor_noise_normalized = normalize(nm_detail_minor_noise.rgb * 2.0 - 1.0);
	vec3 nm_normal_detail_view = sign(normal_intensity)*normalize(mat3(T, B, normal_intensity*N) * nm_detail_minor_noise_normalized);

	// Calculate the dot product between the normal and view direction.
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float dt_normal_detail = clamp(abs(dot(nm_normal_detail_view, VIEW)), 1e-6, 1.0);

	// Attenuate the dot product.
	float rim_normal_detail = clamp((dt_normal_detail), 1e-6, 1.0);
	float rim = clamp(pow(dt,rim_exponent), 1e-6, 1.0);
	float rim_ambient = clamp(pow(dt,rim_ambient_exponent), 1e-6, 1.0);

	float luminosity = dot(COLOR.rgb, vec3(lum_weight_r, lum_weight_g, lum_weight_b));
	luminosity = max(luminosity, 0.0);

	// Now use this calculated luminosity value in your original formula
	float vertex_mask = vertex_mask_overlay + pow(luminosity, vertex_mask_power);
	if (vertex_mask < 0.01) {
		discard;
	}
	
	ALBEDO = albedo_strength * albedo.rgb * COLOR.rgb;
	
	// Emulate normal map
	float normal_mask = clamp(1.0 - pow((1.0-rim_normal_detail) * normal_detail_power, normal_detail_factor), 1e-6, normal_detail_clamp);
	ALBEDO *= normal_strength * normal_mask;

	// Apply rim
	float rim_mask = pow((1.0 - rim)*rim, rim_factor);
	ALBEDO += rim_strength * rim_mask * normal_mask * albedo_rim.rgb;
	
	// Apply vertex mask
	ALBEDO *= vertex_mask;
	
	// color tweak.
	ALBEDO = vec3(
		pow(ALBEDO.r, color_power_r)*color_multiplier_r,
		pow(ALBEDO.g, color_power_g)*color_multiplier_g,
		pow(ALBEDO.b, color_power_b)*color_multiplier_b
	);


	// Fade near and far.
	float dist = length(VERTEX);
	float fade_out = clamp(smoothstep(fade_distance_far, 0.0, dist), 1e-6, 1.0); // fades out
	float fade_in = clamp(smoothstep(0.0, fade_distance_near, dist), 1e-6, 1.0); // fades in
	float fade = pow(fade_in*fade_out, fade_power);
		
	// Overlay dark parts
	ALBEDO += fade * rim_ambient * albedo_ambient.rgb * (1.0 - rim_mask) * (1.0 - normal_mask);
	
	ALBEDO *= fade;

}"

[sub_resource type="OpenSimplexNoise" id=3]

[sub_resource type="NoiseTexture" id=4]
width = 1
height = 1
as_normalmap = true
noise = SubResource( 3 )

[sub_resource type="ShaderMaterial" id=8]
shader = SubResource( 7 )
shader_param/vertex_mask_power = 1.0
shader_param/vertex_mask_overlay = 0.0
shader_param/albedo_strength = 1.0
shader_param/lum_weight_r = 1.0
shader_param/lum_weight_g = 1.0
shader_param/lum_weight_b = 1.0
shader_param/color_power_r = 1.0
shader_param/color_power_g = 1.0
shader_param/color_power_b = 1.0
shader_param/color_multiplier_r = 1.0
shader_param/color_multiplier_g = 1.0
shader_param/color_multiplier_b = 1.0
shader_param/albedo = Color( 0.2, 0.0941176, 0.0509804, 1 )
shader_param/albedo_rim = null
shader_param/albedo_ambient = null
shader_param/normal_intensity = 1.0
shader_param/normal_detail_power = 1.45
shader_param/normal_detail_factor = 0.421
shader_param/normal_strength = 1.128
shader_param/normal_detail_clamp = 1.0
shader_param/rim_factor = 1.0
shader_param/rim_strength = 1.0
shader_param/rim_exponent = 1.0
shader_param/rim_ambient_exponent = 1.0
shader_param/fade_distance_near = 1e+06
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 1.0
shader_param/uv1_blend_sharpness = 10.0
shader_param/normal_detail_uv1_scale = 1.0
shader_param/normal_detail_uv1_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5
shader_param/normal_noise = SubResource( 4 )

[sub_resource type="SphereMesh" id=9]
radial_segments = 16
rings = 16

[node name="Sector System Lywin" type="Spatial"]

[node name="_PlayableArea" type="MeshInstance" parent="."]
transform = Transform( 100000, 0, 0, 0, 100000, 0, 0, 0, 100000, 0, 0, 0 )
visible = false
material_override = SubResource( 1 )
mesh = SubResource( 2 )
script = ExtResource( 1 )

[node name="AgentContainer" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="StarsphereSlot" type="Spatial" parent="."]
script = ExtResource( 2 )
__meta__ = {
"_edit_lock_": true
}

[node name="Globalnebulas" parent="StarsphereSlot" instance=ExtResource( 3 )]
visible = false

[node name="SceneAssets" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="EntryPoint" type="Position3D" parent="SceneAssets"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 40200, 250, -15200 )

[node name="Star Lywin A" parent="SceneAssets" instance=ExtResource( 8 )]

[node name="Planet Lywin A a" parent="SceneAssets/Star Lywin A" instance=ExtResource( 9 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 43395.1, 3600.17, -12229.2 )

[node name="Star Lywin B" parent="SceneAssets" instance=ExtResource( 4 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 3382.07, 20549.5, 33255.8 )

[node name="Star Lywin C" parent="SceneAssets" instance=ExtResource( 5 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -54433, 21292.2, -20608.5 )

[node name="_Star Lywin D" parent="SceneAssets" instance=ExtResource( 6 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 56718.3, -523.875, -92881.4 )
visible = false

[node name="_Star Lywin E" parent="SceneAssets" instance=ExtResource( 7 )]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 40138.7, -23678.5, 106830 )
visible = false

[node name="Spatial" type="Spatial" parent="SceneAssets"]

[node name="Model" type="Spatial" parent="SceneAssets/Spatial"]

[node name="SystemHalo" type="MeshInstance" parent="SceneAssets/Spatial/Model"]
transform = Transform( 185636, 74376.1, -2745.73, -73728, 182758, -34110.5, -10176, 32672.7, 197051, 0, 0, 0 )
material_override = SubResource( 8 )
mesh = SubResource( 9 )
skeleton = NodePath("../../Model")

--- Start of ./scenes/levels/sectors/sector_system_lywin/stars_lywin/planet_lywin_A_a/statsion_lywin_A_a1.tscn ---

[gd_scene load_steps=6 format=2]

[ext_resource path="res://src/scenes/game_world/station/dockable_station.gd" type="Script" id=1]
[ext_resource path="res://assets/art/materials/test_solid_glow.tres" type="Material" id=2]

[sub_resource type="SphereShape" id=1]
radius = 20.0

[sub_resource type="CubeMesh" id=2]
size = Vector3( 10, 10, 10 )

[sub_resource type="SphereShape" id=3]
radius = 279.495

[node name="Station_delta" type="StaticBody"]
script = ExtResource( 1 )
location_id = "station_delta"
station_name = "Outpost Delta - Military Garrison"

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="MeshInstance" type="MeshInstance" parent="."]
transform = Transform( 2.97317, 0, 0, 0, 2.97317, 0, 0, 0, 2.97317, 0, 0, 0 )
material_override = ExtResource( 2 )
mesh = SubResource( 2 )

[node name="DockingZone" type="Area" parent="."]

[node name="CollisionShape" type="CollisionShape" parent="DockingZone"]
shape = SubResource( 3 )

--- Start of ./scenes/levels/sectors/sector_system_lywin/stars_lywin/planet_lywin_A_a.tscn ---

[gd_scene load_steps=10 format=2]

[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=1]
[ext_resource path="res://assets/art/shaders/simple_solid_NLP.gdshader" type="Shader" id=2]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=3]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/bw_noise/Craters 14 - 512x512.png" type="Texture" id=4]

[sub_resource type="SphereShape" id=1]
radius = 1000.0

[sub_resource type="ShaderMaterial" id=3]
shader = ExtResource( 2 )
shader_param/paint_color = Color( 0.5, 0.55, 0.65, 1 )
shader_param/light_tint = Color( 0.803922, 0.72549, 0.556863, 1 )
shader_param/shadow_tint = Color( 0.0862745, 0.0980392, 0.0901961, 1 )
shader_param/shadow_bias = 0.169
shader_param/shadow_softness = 0.292
shader_param/shadow_normal_blend = 0.317
shader_param/spec_tint = Color( 0.843137, 0.92549, 0.92549, 0.501961 )
shader_param/spec_intensity = 0.155
shader_param/spec_glossiness = 8.243
shader_param/spec_softness = 1.0
shader_param/rim_color = Color( 0.0196078, 0.00392157, 0.0509804, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = false
shader_param/detail_paint_scale = 0.222
shader_param/detail_paint_strength = 0.442
shader_param/detail_paint_contrast = 0.468
shader_param/detail_normal_scale = 3.507
shader_param/detail_normal_strength = 0.224
shader_param/uv_triplanar_sharpness = 100.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( 0.4, -0.2, 0.55 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/detail_texture = ExtResource( 4 )
shader_param/normal_texture = ExtResource( 3 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="BoxShape" id=4]

[sub_resource type="CubeMesh" id=5]

[node name="Planet Lywin A a" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 1000, 0, 0, 0, 1000, 0, 0, 0, 1000, 0, 0, 0 )

[node name="PlanetSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 3 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 1 )

[node name="StaticBody3" type="StaticBody" parent="."]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -340.234, 61.8828, -1450.97 )

[node name="CollisionShape" type="CollisionShape" parent="StaticBody3"]
shape = SubResource( 4 )

[node name="Model" type="Spatial" parent="StaticBody3"]

[node name="MeshInstance" type="MeshInstance" parent="StaticBody3/Model"]
transform = Transform( 1, 0, -1.77636e-15, 0, 1, 0, 1.77636e-15, 0, 1, 0, 0, 0 )
mesh = SubResource( 5 )
skeleton = NodePath("../../..")

--- Start of ./scenes/levels/sectors/sector_system_lywin/stars_lywin/star_lywin_A.tscn ---

[gd_scene load_steps=18 format=2]

[ext_resource path="res://assets/art/shaders/star_corona_NLP.gdshader" type="Shader" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/shaders/star_sprite.gdshader" type="Shader" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=5]
[ext_resource path="res://assets/art/shaders/star_surface_NLP.gdshader" type="Shader" id=6]

[sub_resource type="SphereShape" id=1]
radius = 5000.0

[sub_resource type="ShaderMaterial" id=25]
shader = ExtResource( 6 )
shader_param/rim_color = Color( 1, 0.909804, 0.796078, 1 )
shader_param/overlay_color = Color( 0.858824, 0.282353, 0.737255, 1 )
shader_param/surface_color = Color( 0.796078, 0.509804, 0.2, 1 )
shader_param/fade_color = Color( 0.619608, 0.470588, 0.396078, 1 )
shader_param/major_phase = 0.95
shader_param/major_detail_intensity = 1.0
shader_param/major_detail_level = 0.5
shader_param/detail_decay_distance = 100000.0
shader_param/detail_decay_power = 2.0
shader_param/fade_distance_far = 50000.0
shader_param/fade_power = 1.0
shader_param/major_detail_scale = 1.0
shader_param/major_detail_flow = 0.01
shader_param/rim_strength = 1.0
shader_param/rim_exponent = 0.03
shader_param/rim_intensity = 10.0
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 25.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/major_detail_noise = ExtResource( 5 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="OpenSimplexNoise" id=23]

[sub_resource type="NoiseTexture" id=24]
width = 256
height = 256
seamless = true
noise = SubResource( 23 )

[sub_resource type="ShaderMaterial" id=26]
shader = ExtResource( 1 )
shader_param/corona_color = Color( 0.27451, 0.129412, 0.105882, 1 )
shader_param/strength_corona = 40.0
shader_param/exponent_corona = 2.0
shader_param/exponent_corona_rim = 2.0
shader_param/corona_floor_power = 5.0
shader_param/corona_floor = 1.3
shader_param/fade_distance_far = 100000.0
shader_param/fade_power = 1.0
shader_param/displacement_power = 0.05
shader_param/displacement_scale_xz = 0.95
shader_param/displacement_scale_y = 0.9
shader_param/displacement_velocity = 0.1
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 27.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/displacement_texture = SubResource( 24 )

[sub_resource type="SphereMesh" id=3]
radial_segments = 32

[sub_resource type="ShaderMaterial" id=27]
shader = ExtResource( 3 )
shader_param/albedo = Color( 0.823529, 0.384314, 0.247059, 1 )
shader_param/scale = 0.16
shader_param/flare_distance = 40000.0
shader_param/flare_size = 3.0
shader_param/attenuation = 0.749
shader_param/intensity = 1.0
shader_param/exponent = 3.0
shader_param/pulse_factor = 0.9
shader_param/pulse_rate = 1.0
shader_param/phase = 0.0
shader_param/Fcoef = 0.001

[sub_resource type="Shader" id=29]
code = "shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	//diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;


void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
}
"

[sub_resource type="ShaderMaterial" id=28]
shader = SubResource( 29 )
shader_param/albedo = Color( 0.2, 0.0941176, 0.0509804, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.357
shader_param/rim_outer_strength = 2.49
shader_param/rim_outer_exponent = 6.108

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star Lywin A" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 4640.9, 1859.4, -68.6439, -1843.2, 4568.96, -852.759, -254.4, 816.817, 4926.26, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 25 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = SubResource( 26 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = SubResource( 27 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 28 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 0.913725, 0.329412, 0.211765, 1 )
light_energy = 1.5
omni_range = 100000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]

--- Start of ./scenes/levels/sectors/sector_system_lywin/stars_lywin/stars_satellites/star_lywin_B.tscn ---

[gd_scene load_steps=18 format=2]

[ext_resource path="res://assets/art/shaders/star_corona_NLP.gdshader" type="Shader" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/shaders/star_sprite.gdshader" type="Shader" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=5]
[ext_resource path="res://assets/art/shaders/star_surface_NLP.gdshader" type="Shader" id=6]

[sub_resource type="SphereShape" id=1]
radius = 3000.0

[sub_resource type="ShaderMaterial" id=25]
shader = ExtResource( 6 )
shader_param/rim_color = Color( 0.623529, 0.109804, 0.109804, 1 )
shader_param/overlay_color = Color( 0.690196, 0.317647, 0.254902, 1 )
shader_param/surface_color = Color( 0.831373, 0.223529, 0.192157, 1 )
shader_param/fade_color = Color( 0.788235, 0.415686, 0.360784, 1 )
shader_param/major_phase = 0.95
shader_param/major_detail_intensity = 1.0
shader_param/major_detail_level = 0.5
shader_param/detail_decay_distance = 50000.0
shader_param/detail_decay_power = 2.0
shader_param/fade_distance_far = 50000.0
shader_param/fade_power = 1.0
shader_param/major_detail_scale = 1.0
shader_param/major_detail_flow = 0.01
shader_param/rim_strength = 1.0
shader_param/rim_exponent = 0.03
shader_param/rim_intensity = 10.0
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 25.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/major_detail_noise = ExtResource( 5 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="OpenSimplexNoise" id=23]

[sub_resource type="NoiseTexture" id=24]
width = 256
height = 256
seamless = true
noise = SubResource( 23 )

[sub_resource type="ShaderMaterial" id=26]
shader = ExtResource( 1 )
shader_param/corona_color = Color( 0.168627, 0.00392157, 0.00392157, 1 )
shader_param/strength_corona = 40.0
shader_param/exponent_corona = 2.0
shader_param/exponent_corona_rim = 2.0
shader_param/corona_floor_power = 5.0
shader_param/corona_floor = 1.3
shader_param/fade_distance_far = 50000.0
shader_param/fade_power = 1.0
shader_param/displacement_power = 0.05
shader_param/displacement_scale_xz = 0.95
shader_param/displacement_scale_y = 0.9
shader_param/displacement_velocity = 0.1
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 27.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/displacement_texture = SubResource( 24 )

[sub_resource type="SphereMesh" id=3]
radial_segments = 32

[sub_resource type="ShaderMaterial" id=27]
shader = ExtResource( 3 )
shader_param/albedo = Color( 0.807843, 0.352941, 0.352941, 1 )
shader_param/scale = 0.188
shader_param/flare_distance = 40000.0
shader_param/flare_size = 3.0
shader_param/attenuation = 0.749
shader_param/intensity = 1.0
shader_param/exponent = 3.0
shader_param/pulse_factor = 0.9
shader_param/pulse_rate = 1.0
shader_param/phase = 0.0
shader_param/Fcoef = 0.001

[sub_resource type="Shader" id=4]
code = "shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	//diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;


void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
}
"

[sub_resource type="ShaderMaterial" id=28]
shader = SubResource( 4 )
shader_param/albedo = Color( 0.141176, 0.0117647, 0.0117647, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.357
shader_param/rim_outer_strength = 2.49
shader_param/rim_outer_exponent = 6.108

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star Lywin B" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 2784.54, 1115.64, -41.1855, -1105.92, 2741.37, -511.654, -152.64, 490.09, 2955.75, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 25 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = SubResource( 26 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = SubResource( 27 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 28 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 0.737255, 0.254902, 0.254902, 1 )
light_energy = 1.5
omni_range = 50000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]

--- Start of ./scenes/levels/sectors/sector_system_lywin/stars_lywin/stars_satellites/star_lywin_C.tscn ---

[gd_scene load_steps=18 format=2]

[ext_resource path="res://assets/art/shaders/star_corona_NLP.gdshader" type="Shader" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/shaders/star_sprite.gdshader" type="Shader" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=5]
[ext_resource path="res://assets/art/shaders/star_surface_NLP.gdshader" type="Shader" id=6]
[ext_resource path="res://assets/art/shaders/simple_glow_NLP.gdshader" type="Shader" id=7]

[sub_resource type="SphereShape" id=1]
radius = 3000.0

[sub_resource type="ShaderMaterial" id=25]
shader = ExtResource( 6 )
shader_param/rim_color = Color( 1, 0.0156863, 0.333333, 1 )
shader_param/overlay_color = Color( 0.643137, 0.14902, 0.352941, 1 )
shader_param/surface_color = Color( 0.576471, 0.0862745, 0.360784, 1 )
shader_param/fade_color = Color( 0.960784, 0.513726, 0.513726, 1 )
shader_param/major_phase = 0.95
shader_param/major_detail_intensity = 1.0
shader_param/major_detail_level = 0.5
shader_param/detail_decay_distance = 50000.0
shader_param/detail_decay_power = 2.0
shader_param/fade_distance_far = 50000.0
shader_param/fade_power = 1.0
shader_param/major_detail_scale = 1.0
shader_param/major_detail_flow = 0.01
shader_param/rim_strength = 1.0
shader_param/rim_exponent = 0.03
shader_param/rim_intensity = 10.0
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 25.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/major_detail_noise = ExtResource( 5 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="OpenSimplexNoise" id=23]

[sub_resource type="NoiseTexture" id=24]
width = 256
height = 256
seamless = true
noise = SubResource( 23 )

[sub_resource type="ShaderMaterial" id=26]
shader = ExtResource( 1 )
shader_param/corona_color = Color( 0.231373, 0.0196078, 0.0196078, 1 )
shader_param/strength_corona = 40.0
shader_param/exponent_corona = 2.0
shader_param/exponent_corona_rim = 2.0
shader_param/corona_floor_power = 5.0
shader_param/corona_floor = 1.3
shader_param/fade_distance_far = 50000.0
shader_param/fade_power = 1.0
shader_param/displacement_power = 0.05
shader_param/displacement_scale_xz = 0.95
shader_param/displacement_scale_y = 0.9
shader_param/displacement_velocity = 0.1
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 27.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/displacement_texture = SubResource( 24 )

[sub_resource type="SphereMesh" id=3]
radial_segments = 32

[sub_resource type="ShaderMaterial" id=27]
shader = ExtResource( 3 )
shader_param/albedo = Color( 0.423529, 0.00784314, 0.313726, 1 )
shader_param/scale = 0.22
shader_param/flare_distance = 40000.0
shader_param/flare_size = 3.0
shader_param/attenuation = 0.749
shader_param/intensity = 1.0
shader_param/exponent = 3.0
shader_param/pulse_factor = 0.9
shader_param/pulse_rate = 1.0
shader_param/phase = 0.0
shader_param/Fcoef = 0.001

[sub_resource type="ShaderMaterial" id=28]
shader = ExtResource( 7 )
shader_param/albedo = Color( 0.2, 0.0509804, 0.0509804, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.123
shader_param/rim_outer_strength = 3.029
shader_param/rim_outer_exponent = 5.627

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star Lywin C" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 2784.54, 1115.64, -41.1855, -1105.92, 2741.37, -511.654, -152.64, 490.09, 2955.75, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 25 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = SubResource( 26 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = SubResource( 27 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 28 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 0.490196, 0.235294, 0.113725, 1 )
light_energy = 1.5
omni_range = 50000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]

--- Start of ./scenes/levels/sectors/sector_system_lywin/stars_lywin/stars_satellites/star_lywin_D.tscn ---

[gd_scene load_steps=18 format=2]

[ext_resource path="res://assets/art/shaders/star_corona_NLP.gdshader" type="Shader" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/shaders/star_sprite.gdshader" type="Shader" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=5]
[ext_resource path="res://assets/art/shaders/star_surface_NLP.gdshader" type="Shader" id=6]

[sub_resource type="SphereShape" id=1]
radius = 5000.0

[sub_resource type="ShaderMaterial" id=25]
shader = ExtResource( 6 )
shader_param/rim_color = Color( 1, 0.568627, 0.0156863, 1 )
shader_param/overlay_color = Color( 0.87451, 0.266667, 0, 1 )
shader_param/surface_color = Color( 0.960784, 0.505882, 0.0156863, 1 )
shader_param/fade_color = Color( 0.972549, 0.760784, 0.556863, 1 )
shader_param/major_phase = 0.95
shader_param/major_detail_intensity = 1.0
shader_param/major_detail_level = 0.5
shader_param/detail_decay_distance = 30000.0
shader_param/detail_decay_power = 2.0
shader_param/major_detail_scale = 1.0
shader_param/major_detail_flow = 0.01
shader_param/rim_strength = 1.0
shader_param/rim_exponent = 0.03
shader_param/rim_intensity = 10.0
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 25.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/major_detail_noise = ExtResource( 5 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="OpenSimplexNoise" id=23]

[sub_resource type="NoiseTexture" id=24]
width = 256
height = 256
seamless = true
noise = SubResource( 23 )

[sub_resource type="ShaderMaterial" id=26]
shader = ExtResource( 1 )
shader_param/corona_color = Color( 0.933333, 0.376471, 0.0666667, 1 )
shader_param/strength_corona = 40.0
shader_param/exponent_corona = 2.0
shader_param/exponent_corona_rim = 2.0
shader_param/corona_floor_power = 5.0
shader_param/corona_floor = 1.3
shader_param/displacement_power = 0.05
shader_param/displacement_scale_xz = 0.95
shader_param/displacement_scale_y = 0.9
shader_param/displacement_velocity = 0.1
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 27.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/displacement_texture = SubResource( 24 )

[sub_resource type="SphereMesh" id=3]
radial_segments = 32

[sub_resource type="ShaderMaterial" id=27]
shader = ExtResource( 3 )
shader_param/albedo = Color( 1, 0.635294, 0.435294, 1 )
shader_param/scale = 0.297
shader_param/flare_distance = 40000.0
shader_param/flare_size = 3.0
shader_param/attenuation = 0.749
shader_param/intensity = 1.0
shader_param/exponent = 3.0
shader_param/pulse_factor = 0.9
shader_param/pulse_rate = 1.0
shader_param/phase = 0.0
shader_param/Fcoef = 0.001

[sub_resource type="Shader" id=4]
code = "shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	//diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;


void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
}
"

[sub_resource type="ShaderMaterial" id=28]
shader = SubResource( 4 )
shader_param/albedo = Color( 0.2, 0.0509804, 0.0509804, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.357
shader_param/rim_outer_strength = 2.49
shader_param/rim_outer_exponent = 6.108

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star Lywin D" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 4640.9, 1859.4, -68.6439, -1843.2, 4568.96, -852.759, -254.4, 816.817, 4926.26, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 25 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = SubResource( 26 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = SubResource( 27 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 28 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 0.8, 0.85, 1, 1 )
light_energy = 1.5
omni_range = 100000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]

--- Start of ./scenes/levels/sectors/sector_system_lywin/stars_lywin/stars_satellites/star_lywin_E.tscn ---

[gd_scene load_steps=18 format=2]

[ext_resource path="res://assets/art/shaders/star_corona_NLP.gdshader" type="Shader" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/shaders/star_sprite.gdshader" type="Shader" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=5]
[ext_resource path="res://assets/art/shaders/star_surface_NLP.gdshader" type="Shader" id=6]

[sub_resource type="SphereShape" id=1]
radius = 5000.0

[sub_resource type="ShaderMaterial" id=25]
shader = ExtResource( 6 )
shader_param/rim_color = Color( 1, 0.568627, 0.0156863, 1 )
shader_param/overlay_color = Color( 0.87451, 0.266667, 0, 1 )
shader_param/surface_color = Color( 0.960784, 0.505882, 0.0156863, 1 )
shader_param/fade_color = Color( 0.972549, 0.760784, 0.556863, 1 )
shader_param/major_phase = 0.95
shader_param/major_detail_intensity = 1.0
shader_param/major_detail_level = 0.5
shader_param/detail_decay_distance = 30000.0
shader_param/detail_decay_power = 2.0
shader_param/major_detail_scale = 1.0
shader_param/major_detail_flow = 0.01
shader_param/rim_strength = 1.0
shader_param/rim_exponent = 0.03
shader_param/rim_intensity = 10.0
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 25.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/major_detail_noise = ExtResource( 5 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="OpenSimplexNoise" id=23]

[sub_resource type="NoiseTexture" id=24]
width = 256
height = 256
seamless = true
noise = SubResource( 23 )

[sub_resource type="ShaderMaterial" id=26]
shader = ExtResource( 1 )
shader_param/corona_color = Color( 0.933333, 0.376471, 0.0666667, 1 )
shader_param/strength_corona = 40.0
shader_param/exponent_corona = 2.0
shader_param/exponent_corona_rim = 2.0
shader_param/corona_floor_power = 5.0
shader_param/corona_floor = 1.3
shader_param/displacement_power = 0.05
shader_param/displacement_scale_xz = 0.95
shader_param/displacement_scale_y = 0.9
shader_param/displacement_velocity = 0.1
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 27.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/displacement_texture = SubResource( 24 )

[sub_resource type="SphereMesh" id=3]
radial_segments = 32

[sub_resource type="ShaderMaterial" id=27]
shader = ExtResource( 3 )
shader_param/albedo = Color( 1, 0.635294, 0.435294, 1 )
shader_param/scale = 0.297
shader_param/flare_distance = 40000.0
shader_param/flare_size = 3.0
shader_param/attenuation = 0.749
shader_param/intensity = 1.0
shader_param/exponent = 3.0
shader_param/pulse_factor = 0.9
shader_param/pulse_rate = 1.0
shader_param/phase = 0.0
shader_param/Fcoef = 0.001

[sub_resource type="Shader" id=4]
code = "shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	//diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;


void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
}
"

[sub_resource type="ShaderMaterial" id=28]
shader = SubResource( 4 )
shader_param/albedo = Color( 0.2, 0.0509804, 0.0509804, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.357
shader_param/rim_outer_strength = 2.49
shader_param/rim_outer_exponent = 6.108

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star Lywin E" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 4640.9, 1859.4, -68.6439, -1843.2, 4568.96, -852.759, -254.4, 816.817, 4926.26, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 25 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = SubResource( 26 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = SubResource( 27 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 28 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 0.8, 0.85, 1, 1 )
light_energy = 1.5
omni_range = 100000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]

--- Start of ./scenes/prefabs/agents/agent.tscn ---

[gd_scene load_steps=12 format=2]

[ext_resource path="res://src/core/agents/agent.gd" type="Script" id=1]
[ext_resource path="res://assets/models/ships/Phoenix.glb" type="PackedScene" id=2]
[ext_resource path="res://src/core/agents/components/movement_system.gd" type="Script" id=3]
[ext_resource path="res://src/core/agents/components/navigation_system.gd" type="Script" id=4]
[ext_resource path="res://assets/art/shaders/simple_glow_NLP.gdshader" type="Shader" id=5]
[ext_resource path="res://assets/art/materials/test_solid_panel.tres" type="Material" id=6]

[sub_resource type="CapsuleShape" id=6]
radius = 7.4844
height = 2.14715

[sub_resource type="ShaderMaterial" id=7]
shader = ExtResource( 5 )
shader_param/albedo = null
shader_param/rim_strength = 5.0
shader_param/rim_exponent = 30.0
shader_param/rim_power = 1.0
shader_param/rim_floor = 0.1
shader_param/rim_outer_strength = 3.0
shader_param/rim_outer_exponent = 3.0
shader_param/fade_distance_near = 100.0
shader_param/fade_distance_far = 1000.0
shader_param/fade_power = 0.2
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5

[sub_resource type="SphereMesh" id=4]

[sub_resource type="ShaderMaterial" id=5]
shader = ExtResource( 5 )
shader_param/albedo = null
shader_param/rim_strength = 5.0
shader_param/rim_exponent = 30.0
shader_param/rim_power = 1.0
shader_param/rim_floor = 0.1
shader_param/rim_outer_strength = 3.0
shader_param/rim_outer_exponent = 3.0
shader_param/fade_distance_near = 100.0
shader_param/fade_distance_far = 1000.0
shader_param/fade_power = 0.2
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5

[sub_resource type="ShaderMaterial" id=8]
shader = ExtResource( 5 )
shader_param/albedo = null
shader_param/rim_strength = 5.0
shader_param/rim_exponent = 30.0
shader_param/rim_power = 1.0
shader_param/rim_floor = 0.1
shader_param/rim_outer_strength = 3.0
shader_param/rim_outer_exponent = 3.0
shader_param/fade_distance_near = 100.0
shader_param/fade_distance_far = 1000.0
shader_param/fade_power = 0.2
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5

[node name="AgentBody" type="RigidBody"]
gravity_scale = 0.0
script = ExtResource( 1 )
__meta__ = {
"_edit_lock_": true
}

[node name="CollisionShape" type="CollisionShape" parent="."]
transform = Transform( 1.09343, 0, 0, 0, 0.430446, 0, 0, 0, 1, 0, 0, 0 )
shape = SubResource( 6 )

[node name="Model" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="Phoenix" parent="Model" instance=ExtResource( 2 )]

[node name="Hull joined" parent="Model/Phoenix" index="0"]
material_override = ExtResource( 6 )

[node name="Exhaust long3" type="Spatial" parent="Model"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1.47573, 0, 0, -0.018764 )

[node name="Exhaust" type="MeshInstance" parent="Model/Exhaust long3"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 5.66394, 0, 0, 5.17021 )
material_override = SubResource( 7 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust2" type="MeshInstance" parent="Model/Exhaust long3"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 5.52252, 3.3694, 0, 7.06125 )
material_override = SubResource( 7 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust3" type="MeshInstance" parent="Model/Exhaust long3"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 5.52252, -3.36764, 0, 7.06125 )
material_override = SubResource( 7 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust long2" type="Spatial" parent="Model"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1.24525, 0, 0, -0.018764 )

[node name="Exhaust" type="MeshInstance" parent="Model/Exhaust long2"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 4.18236, 0, 0, 5.17021 )
material_override = SubResource( 7 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust2" type="MeshInstance" parent="Model/Exhaust long2"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 3.46622, 3.3694, 0, 7.34439 )
material_override = SubResource( 7 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust3" type="MeshInstance" parent="Model/Exhaust long2"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 3.46622, -3.36764, 0, 7.34439 )
material_override = SubResource( 7 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust long" type="Spatial" parent="Model"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -0.018764 )

[node name="Exhaust" type="MeshInstance" parent="Model/Exhaust long"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1.86375, 0, 0, 5.17021 )
material_override = SubResource( 7 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust2" type="MeshInstance" parent="Model/Exhaust long"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1.86375, 3.3694, 0, 8.04084 )
material_override = SubResource( 7 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust3" type="MeshInstance" parent="Model/Exhaust long"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1.86375, -3.36764, 0, 8.04084 )
material_override = SubResource( 7 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust short" type="Spatial" parent="Model"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -1.29184 )

[node name="Exhaust" type="MeshInstance" parent="Model/Exhaust short"]
transform = Transform( 0.5, 0, 0, 0, 0.5, 0, 0, 0, 0.5, 0, 0, 5.18022 )
material_override = SubResource( 5 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust2" type="MeshInstance" parent="Model/Exhaust short"]
transform = Transform( 0.5, 0, 0, 0, 0.5, 0, 0, 0, 0.5, 3.3694, 0, 8.04084 )
material_override = SubResource( 5 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust3" type="MeshInstance" parent="Model/Exhaust short"]
transform = Transform( 0.5, 0, 0, 0, 0.5, 0, 0, 0, 0.5, -3.36764, 0, 8.04084 )
material_override = SubResource( 5 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust short2" type="Spatial" parent="Model"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -0.723569 )

[node name="Exhaust" type="MeshInstance" parent="Model/Exhaust short2"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 5.18022 )
material_override = SubResource( 8 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust2" type="MeshInstance" parent="Model/Exhaust short2"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 3.3694, 0, 8.04084 )
material_override = SubResource( 8 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="Exhaust3" type="MeshInstance" parent="Model/Exhaust short2"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -3.36764, 0, 8.04084 )
material_override = SubResource( 8 )
cast_shadow = 0
mesh = SubResource( 4 )
skeleton = NodePath("")

[node name="MovementSystem" type="Node" parent="."]
script = ExtResource( 3 )

[node name="NavigationSystem" type="Node" parent="."]
script = ExtResource( 4 )

[node name="DirectionalLight" type="DirectionalLight" parent="."]
transform = Transform( 0.94983, -0.0541661, 0.30804, -0.312766, -0.164495, 0.935478, 0, -0.984889, -0.173184, 0, 0, 0 )
light_energy = 0.5
editor_only = true

[editable path="Model/Phoenix"]

--- Start of ./scenes/prefabs/agents/npc_agent.tscn ---

[gd_scene load_steps=4 format=2]

[ext_resource path="res://src/modules/piloting/ship_controller_ai.gd" type="Script" id=1]
[ext_resource path="res://scenes/prefabs/agents/agent.tscn" type="PackedScene" id=2]
[ext_resource path="res://src/core/agents/components/tool_controller.gd" type="Script" id=3]

[node name="NPCAgent" type="Spatial"]
__meta__ = {
"_edit_lock_": true
}

[node name="AgentBody" parent="." instance=ExtResource( 2 )]

[node name="AIController" type="Node" parent="AgentBody"]
script = ExtResource( 1 )

[node name="ToolController" type="Node" parent="AgentBody"]
script = ExtResource( 3 )

--- Start of ./scenes/prefabs/agents/player_agent.tscn ---

[gd_scene load_steps=4 format=2]

[ext_resource path="res://scenes/prefabs/agents/agent.tscn" type="PackedScene" id=1]
[ext_resource path="res://src/modules/piloting/player_controller_ship.gd" type="Script" id=2]
[ext_resource path="res://src/core/agents/components/tool_controller.gd" type="Script" id=3]

[node name="PlayerAgent" type="Spatial"]
__meta__ = {
"_edit_lock_": true
}

[node name="AgentBody" parent="." instance=ExtResource( 1 )]

[node name="PlayerInputHandler" type="Node" parent="AgentBody"]
script = ExtResource( 2 )

[node name="ToolController" type="Node" parent="AgentBody"]
script = ExtResource( 3 )

--- Start of ./scenes/prefabs/camera/orbit_camera.tscn ---

[gd_scene load_steps=5 format=2]

[ext_resource path="res://src/scenes/camera/orbit_camera.gd" type="Script" id=1]
[ext_resource path="res://assets/art/effects/particle_quad.tres" type="QuadMesh" id=2]
[ext_resource path="res://src/scenes/camera/components/camera_particles_controller.gd" type="Script" id=3]

[sub_resource type="Gradient" id=1]
offsets = PoolRealArray( 0, 0.5, 1 )
colors = PoolColorArray( 1, 1, 1, 0, 1, 1, 1, 0.501961, 1, 1, 1, 0 )

[node name="OrbitCamera" type="Camera"]
current = true
near = 10.0
far = 2e+06
script = ExtResource( 1 )
__meta__ = {
"_edit_lock_": true
}

[node name="LocalSceneParticles" type="Spatial" parent="."]

[node name="NearDustParticles" type="CPUParticles" parent="LocalSceneParticles"]
amount = 50
lifetime = 3.0
local_coords = false
mesh = ExtResource( 2 )
emission_shape = 2
emission_box_extents = Vector3( 20, 20, 50 )
direction = Vector3( 0, 0, 1 )
spread = 10.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 1.0
initial_velocity_random = 0.5
damping = 0.5
scale_amount = 1.1
color_ramp = SubResource( 1 )
script = ExtResource( 3 )
min_camera_speed_threshold = 5.0
max_camera_speed_for_effect = 300.0
velocity_offset_scale = -100.0

[node name="FarDustParticles" type="CPUParticles" parent="LocalSceneParticles"]
amount = 200
lifetime = 10.0
local_coords = false
mesh = ExtResource( 2 )
emission_shape = 2
emission_box_extents = Vector3( 500, 500, 1000 )
direction = Vector3( 0, 0, 1 )
spread = 100.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 1.0
initial_velocity_random = 0.5
damping = 0.5
scale_amount = 1.2
color_ramp = SubResource( 1 )
script = ExtResource( 3 )
min_camera_speed_threshold = 0.0
max_camera_speed_for_effect = 10.0
velocity_offset_scale = -300.0

[node name="FarDustParticles2" type="CPUParticles" parent="LocalSceneParticles"]
amount = 100
lifetime = 30.0
local_coords = false
mesh = ExtResource( 2 )
emission_shape = 2
emission_box_extents = Vector3( 1500, 1500, 2500 )
direction = Vector3( 0, 0, 1 )
spread = 100.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 1.0
initial_velocity_random = 0.5
damping = 0.5
scale_amount = 0.9
color_ramp = SubResource( 1 )
script = ExtResource( 3 )
min_camera_speed_threshold = 0.0
max_camera_speed_for_effect = 10.0
velocity_offset_scale = -1200.0

[node name="VeryFarDustParticles" type="CPUParticles" parent="LocalSceneParticles"]
visible = false
amount = 512
lifetime = 60.0
local_coords = false
mesh = ExtResource( 2 )
emission_shape = 2
emission_box_extents = Vector3( 500000, 500000, 500000 )
direction = Vector3( 0, 0, 1 )
spread = 180.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 1.0
initial_velocity_random = 0.5
damping = 0.5
scale_amount = 1.8
color_ramp = SubResource( 1 )
hue_variation = 0.19
hue_variation_random = 1.0
script = ExtResource( 3 )
min_camera_speed_threshold = 0.0
max_camera_speed_for_effect = 1.0

--- Start of ./scenes/prefabs/celestial/Planet_default.tscn ---

[gd_scene load_steps=10 format=2]

[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=1]
[ext_resource path="res://assets/art/shaders/simple_solid_NLP.gdshader" type="Shader" id=2]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=3]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/bw_noise/Craters 14 - 512x512.png" type="Texture" id=4]

[sub_resource type="SphereShape" id=1]
radius = 1000.0

[sub_resource type="SphereMesh" id=2]

[sub_resource type="ShaderMaterial" id=3]
shader = ExtResource( 2 )
shader_param/paint_color = Color( 1, 1, 1, 1 )
shader_param/light_tint = Color( 0.803922, 0.72549, 0.556863, 1 )
shader_param/shadow_tint = Color( 0.0862745, 0.0980392, 0.0901961, 1 )
shader_param/shadow_bias = 0.169
shader_param/shadow_softness = 0.292
shader_param/shadow_normal_blend = 0.317
shader_param/spec_tint = Color( 0.843137, 0.92549, 0.92549, 0.501961 )
shader_param/spec_intensity = 0.155
shader_param/spec_glossiness = 8.243
shader_param/spec_softness = 1.0
shader_param/rim_color = Color( 0.0196078, 0.00392157, 0.0509804, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = false
shader_param/detail_paint_scale = 0.222
shader_param/detail_paint_strength = 0.442
shader_param/detail_paint_contrast = 0.468
shader_param/detail_normal_scale = 3.507
shader_param/detail_normal_strength = 0.224
shader_param/uv_triplanar_sharpness = 100.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( 0.636, 0.795, -0.423 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25
shader_param/detail_texture = ExtResource( 4 )
shader_param/normal_texture = ExtResource( 3 )

[sub_resource type="BoxShape" id=4]

[sub_resource type="CubeMesh" id=5]

[node name="Planet_default" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 1000, 0, 0, 0, 1000, 0, 0, 0, 1000, 0, 0, 0 )

[node name="PlanetSurface" type="MeshInstance" parent="Model"]
material_override = SubResource( 3 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 1 )

[node name="StaticBody3" type="StaticBody" parent="."]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -340.234, 61.8828, -1450.97 )

[node name="CollisionShape" type="CollisionShape" parent="StaticBody3"]
shape = SubResource( 4 )

[node name="Model" type="Spatial" parent="StaticBody3"]

[node name="MeshInstance" type="MeshInstance" parent="StaticBody3/Model"]
transform = Transform( 1, 0, -1.77636e-15, 0, 1, 0, 1.77636e-15, 0, 1, 0, 0, 0 )
mesh = SubResource( 5 )
skeleton = NodePath("../../..")

--- Start of ./scenes/prefabs/celestial/Star_default.tscn ---

[gd_scene load_steps=12 format=2]

[ext_resource path="res://assets/art/materials/scene_materials/star_1_surface.tres" type="Material" id=1]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=2]
[ext_resource path="res://assets/art/materials/scene_materials/star_1_corona.tres" type="Material" id=3]
[ext_resource path="res://src/core/utils/rotating_object.gd" type="Script" id=4]
[ext_resource path="res://assets/art/materials/scene_materials/star_1_sprite.tres" type="Material" id=5]

[sub_resource type="SphereShape" id=1]
radius = 5000.0

[sub_resource type="SphereMesh" id=2]

[sub_resource type="SphereMesh" id=3]
radial_segments = 32

[sub_resource type="Shader" id=4]
code = "shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	//diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;


void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
}
"

[sub_resource type="ShaderMaterial" id=5]
shader = SubResource( 4 )
shader_param/albedo = Color( 0.176471, 0.12549, 0.054902, 1 )
shader_param/rim_strength = 2.601
shader_param/rim_exponent = 30.0
shader_param/rim_power = 0.556
shader_param/rim_floor = 0.357
shader_param/rim_outer_strength = 2.49
shader_param/rim_outer_exponent = 6.108

[sub_resource type="SphereMesh" id=6]
radial_segments = 16
rings = 16

[node name="Star_default" type="StaticBody"]

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]
transform = Transform( 4640.9, 1859.4, -68.6439, -1843.2, 4568.96, -852.759, -254.4, 816.817, 4926.26, 0, 0, 0 )

[node name="StarSurface" type="MeshInstance" parent="Model"]
material_override = ExtResource( 1 )
mesh = SubResource( 2 )
skeleton = NodePath("../..")
script = ExtResource( 4 )

[node name="StarCorona" type="MeshInstance" parent="Model"]
transform = Transform( 1.55764, -5.96046e-08, 3.57628e-07, 8.9407e-08, 1.55764, 8.19564e-07, -5.96046e-08, -7.30157e-07, 1.55764, 0, 0, 0 )
material_override = ExtResource( 3 )
mesh = SubResource( 3 )

[node name="ModelAdditional" type="Spatial" parent="."]
transform = Transform( 1, 6.98492e-09, 2.98023e-08, 1.07102e-08, 1, -1.58325e-08, 2.98023e-08, 1.6531e-08, 1, 0, 0, 0 )

[node name="Star_sprite_square_wide" parent="ModelAdditional" instance=ExtResource( 2 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="ModelAdditional/Star_sprite_square_wide" index="0"]
material_override = ExtResource( 5 )

[node name="StarHalo" type="MeshInstance" parent="ModelAdditional"]
transform = Transform( 15346.5, 6148.67, -226.985, -6095.09, 15108.6, -2819.9, -841.251, 2701.05, 16290.2, 0, 0, 0 )
material_override = SubResource( 5 )
mesh = SubResource( 6 )
skeleton = NodePath("../../Model")

[node name="OmniLight" type="OmniLight" parent="."]
light_color = Color( 0.921569, 0.894118, 0.835294, 1 )
light_energy = 1.5
omni_range = 100000.0

[editable path="ModelAdditional/Star_sprite_square_wide"]

--- Start of ./scenes/prefabs/navigation/JumpPoint.tscn ---

[gd_scene load_steps=7 format=2]

[ext_resource path="res://src/scenes/game_world/jump_point.gd" type="Script" id=1]

[sub_resource type="PhysicsMaterial" id=5]
friction = 0.0

[sub_resource type="SphereShape" id=1]
radius = 10.0

[sub_resource type="SpatialMaterial" id=3]
flags_unshaded = true
albedo_color = Color( 0.33, 1, 1, 1 )

[sub_resource type="SphereMesh" id=2]
radius = 15.0
height = 30.0

[sub_resource type="SphereShape" id=4]
radius = 300.0

[node name="JumpPoint" type="StaticBody"]
physics_material_override = SubResource( 5 )
script = ExtResource( 1 )

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="Model" type="Spatial" parent="."]

[node name="MeshInstance" type="MeshInstance" parent="Model"]
material_override = SubResource( 3 )
mesh = SubResource( 2 )

[node name="DetectionZone" type="Area" parent="."]

[node name="CollisionShape" type="CollisionShape" parent="DetectionZone"]
shape = SubResource( 4 )

--- Start of ./scenes/prefabs/navigation/jump_transition_rig.tscn ---

[gd_scene load_steps=5 format=2]

[ext_resource path="res://src/scenes/game_world/jump_transition/jump_transition_rig.gd" type="Script" id=1]
[ext_resource path="res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn" type="PackedScene" id=2]
[ext_resource path="res://assets/art/effects/particle_quad.tres" type="QuadMesh" id=3]

[sub_resource type="Gradient" id=1]
offsets = PoolRealArray( 0, 0.5, 1 )
colors = PoolColorArray( 1, 1, 1, 0, 1, 1, 1, 0.501961, 1, 1, 1, 0 )

[node name="JumpTransitionRig" type="Spatial"]
pause_mode = 2
visible = false
script = ExtResource( 1 )

[node name="NebulaHolder" type="Spatial" parent="."]
pause_mode = 2

[node name="Globalnebulas" parent="NebulaHolder" instance=ExtResource( 2 )]

[node name="TransitionCamera" type="Camera" parent="."]
pause_mode = 2
fov = 95.0
far = 1e+06

[node name="JumpTransitionParticles" type="Spatial" parent="TransitionCamera"]
pause_mode = 2

[node name="NearJumpParticles" type="CPUParticles" parent="TransitionCamera/JumpTransitionParticles"]
amount = 50
lifetime = 3.0
local_coords = false
mesh = ExtResource( 3 )
emission_shape = 2
emission_box_extents = Vector3( 2000, 2000, 5000 )
direction = Vector3( 0, 0, 1 )
spread = 10.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 1.0
initial_velocity_random = 0.5
damping = 0.5
scale_amount = 8.0
color_ramp = SubResource( 1 )

[node name="FarJumpParticles" type="CPUParticles" parent="TransitionCamera/JumpTransitionParticles"]
amount = 200
lifetime = 10.0
local_coords = false
mesh = ExtResource( 3 )
emission_shape = 2
emission_box_extents = Vector3( 50000, 50000, 100000 )
direction = Vector3( 0, 0, 1 )
spread = 100.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 1.0
initial_velocity_random = 0.5
damping = 0.5
scale_amount = 8.0
color_ramp = SubResource( 1 )

[node name="FarJumpParticles2" type="CPUParticles" parent="TransitionCamera/JumpTransitionParticles"]
amount = 100
lifetime = 30.0
local_coords = false
mesh = ExtResource( 3 )
emission_shape = 2
emission_box_extents = Vector3( 150000, 150000, 250000 )
direction = Vector3( 0, 0, 1 )
spread = 100.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 1.0
initial_velocity_random = 0.5
damping = 0.5
scale_amount = 8.0
color_ramp = SubResource( 1 )

[node name="VeryFarJumpParticles" type="CPUParticles" parent="TransitionCamera/JumpTransitionParticles"]
amount = 512
lifetime = 60.0
local_coords = false
mesh = ExtResource( 3 )
emission_shape = 2
emission_box_extents = Vector3( 500000, 500000, 500000 )
direction = Vector3( 0, 0, 1 )
spread = 180.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 1.0
initial_velocity_random = 0.5
damping = 0.5
scale_amount = 8.0
color_ramp = SubResource( 1 )
hue_variation = 0.19
hue_variation_random = 1.0

[node name="TransitionOverlayLayer" type="CanvasLayer" parent="."]
pause_mode = 2
layer = 50

[node name="TransitionOverlay" type="ColorRect" parent="TransitionOverlayLayer"]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0, 0, 0, 1 )

--- Start of ./scenes/prefabs/station/DockableStation.tscn ---

[gd_scene load_steps=6 format=2]

[ext_resource path="res://src/scenes/game_world/station/dockable_station.gd" type="Script" id=1]
[ext_resource path="res://assets/art/materials/test_solid_glow.tres" type="Material" id=2]

[sub_resource type="BoxShape" id=4]

[sub_resource type="CubeMesh" id=2]
size = Vector3( 10, 10, 10 )

[sub_resource type="SphereShape" id=3]
radius = 279.495

[node name="DockableStation" type="StaticBody"]
script = ExtResource( 1 )

[node name="CollisionShape" type="CollisionShape" parent="."]
transform = Transform( 15.0971, 0, 0, 0, 15.0971, 0, 0, 0, 15.0971, 0, 0, 0 )
shape = SubResource( 4 )

[node name="MeshInstance" type="MeshInstance" parent="."]
transform = Transform( 2.97317, 0, 0, 0, 2.97317, 0, 0, 0, 2.97317, 0, 0, 0 )
material_override = ExtResource( 2 )
mesh = SubResource( 2 )

[node name="DockingZone" type="Area" parent="."]

[node name="CollisionShape" type="CollisionShape" parent="DockingZone"]
shape = SubResource( 3 )

--- Start of ./scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn ---

[gd_scene load_steps=25 format=2]

[ext_resource path="res://assets/models/nebulas/spheroid.glb" type="PackedScene" id=1]
[ext_resource path="res://assets/art/shaders/complex_transparent_cloud_NLP.gdshader" type="Shader" id=2]
[ext_resource path="res://assets/art/textures/procedural_textures/normal/global_nebulas_1.tres" type="Texture" id=3]
[ext_resource path="res://assets/models/nebulas/nebula_1.glb" type="PackedScene" id=4]
[ext_resource path="res://assets/models/nebulas/nebula_2.glb" type="PackedScene" id=5]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Voronoi 8 - 512x512.png" type="Texture" id=6]
[ext_resource path="res://assets/models/nebulas/nebula_3.glb" type="PackedScene" id=7]
[ext_resource path="res://assets/art/shaders/star_sprite.gdshader" type="Shader" id=9]
[ext_resource path="res://assets/models/sprites/Star_sprite_square_wide.glb" type="PackedScene" id=10]

[sub_resource type="GDScript" id=7]
script/source = "extends Spatial

func _ready():
	self.visible = true

"

[sub_resource type="ShaderMaterial" id=1]
shader = ExtResource( 2 )
shader_param/albedo = Color( 0, 0.0705882, 0.0705882, 1 )
shader_param/albedo_rim = Color( 1, 0.376471, 0, 1 )
shader_param/albedo_ambient = Color( 0.027451, 0.0901961, 0, 1 )
shader_param/normal_intensity = 1.0
shader_param/normal_detail_power = 5.0
shader_param/normal_detail_factor = 2.372
shader_param/normal_strength = 0.37
shader_param/normal_detail_clamp = 1.0
shader_param/rim_factor = 1.307
shader_param/rim_strength = 2.041
shader_param/rim_exponent = 0.476
shader_param/rim_ambient_exponent = 4.479
shader_param/fade_distance_near = 100000.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.2
shader_param/uv1_blend_sharpness = 10.0
shader_param/normal_detail_uv1_scale = -3.569
shader_param/normal_detail_uv1_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5
shader_param/normal_noise = ExtResource( 3 )

[sub_resource type="OpenSimplexNoise" id=3]
octaves = 9
period = 25.0

[sub_resource type="NoiseTexture" id=4]
width = 128
height = 128
seamless = true
as_normalmap = true
noise = SubResource( 3 )

[sub_resource type="ShaderMaterial" id=2]
shader = ExtResource( 2 )
shader_param/albedo = Color( 0.0745098, 0.0117647, 0, 1 )
shader_param/albedo_rim = Color( 0, 0.0156863, 0.0352941, 1 )
shader_param/albedo_ambient = Color( 0.00392157, 0.054902, 0, 1 )
shader_param/normal_intensity = 0.652
shader_param/normal_detail_power = 2.52
shader_param/normal_detail_factor = 0.18
shader_param/normal_strength = 2.069
shader_param/normal_detail_clamp = 1.0
shader_param/rim_factor = 0.485
shader_param/rim_strength = 5.0
shader_param/rim_exponent = 5.0
shader_param/rim_ambient_exponent = 4.564
shader_param/fade_distance_near = 100000.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.2
shader_param/uv1_blend_sharpness = 10.0
shader_param/normal_detail_uv1_scale = -2.506
shader_param/normal_detail_uv1_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5
shader_param/normal_noise = SubResource( 4 )

[sub_resource type="ShaderMaterial" id=5]
shader = ExtResource( 2 )
shader_param/albedo = Color( 0, 0.0431373, 0.219608, 1 )
shader_param/albedo_rim = Color( 0.0588235, 0.109804, 0.156863, 1 )
shader_param/albedo_ambient = Color( 0.0117647, 0.0509804, 0.0627451, 1 )
shader_param/normal_intensity = 1.0
shader_param/normal_detail_power = 5.0
shader_param/normal_detail_factor = 0.4
shader_param/normal_strength = 0.2
shader_param/normal_detail_clamp = 1.0
shader_param/rim_factor = 1.496
shader_param/rim_strength = 5.0
shader_param/rim_exponent = 5.0
shader_param/rim_ambient_exponent = 2.143
shader_param/fade_distance_near = 100000.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.2
shader_param/uv1_blend_sharpness = 10.0
shader_param/normal_detail_uv1_scale = -0.254
shader_param/normal_detail_uv1_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5
shader_param/normal_noise = ExtResource( 6 )

[sub_resource type="ShaderMaterial" id=6]
shader = ExtResource( 2 )
shader_param/albedo = Color( 0, 0, 0.0117647, 1 )
shader_param/albedo_rim = Color( 0.45098, 0.45098, 0.45098, 1 )
shader_param/albedo_ambient = Color( 0.00392157, 0.0156863, 0.0392157, 1 )
shader_param/normal_intensity = 0.123
shader_param/normal_detail_power = 2.208
shader_param/normal_detail_factor = 0.83
shader_param/normal_strength = 1.255
shader_param/normal_detail_clamp = 1.0
shader_param/rim_factor = 1.363
shader_param/rim_strength = 2.387
shader_param/rim_exponent = 0.463
shader_param/rim_ambient_exponent = 1.188
shader_param/fade_distance_near = 100000.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.2
shader_param/uv1_blend_sharpness = 10.0
shader_param/normal_detail_uv1_scale = -2.685
shader_param/normal_detail_uv1_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5
shader_param/normal_noise = ExtResource( 3 )

[sub_resource type="ShaderMaterial" id=9]
shader = ExtResource( 9 )
shader_param/albedo = Color( 0.588235, 0.247059, 0.113725, 1 )
shader_param/scale_near = 10.0
shader_param/scale_peak = 0.6
shader_param/scale_far = 0.1
shader_param/peak_distance = 40000.0
shader_param/fade_ratio = 10.0
shader_param/distance_power = 0.3
shader_param/fade_distance_near = 0.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.4
shader_param/intensity = 0.799
shader_param/exponent = 3.0

[sub_resource type="ShaderMaterial" id=8]
shader = ExtResource( 9 )
shader_param/albedo = Color( 1, 0.603922, 0.427451, 1 )
shader_param/scale_near = 2.948
shader_param/scale_peak = 0.2
shader_param/scale_far = 0.05
shader_param/peak_distance = 40000.0
shader_param/fade_ratio = 10.0
shader_param/distance_power = 0.3
shader_param/fade_distance_near = 0.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.4
shader_param/intensity = 0.762
shader_param/exponent = 3.0

[sub_resource type="ShaderMaterial" id=14]
shader = ExtResource( 9 )
shader_param/albedo = Color( 0.796078, 0.188235, 0.141176, 1 )
shader_param/scale_near = 0.2
shader_param/scale_peak = 0.6
shader_param/scale_far = 0.1
shader_param/peak_distance = 40000.0
shader_param/fade_ratio = 10.0
shader_param/distance_power = 0.3
shader_param/fade_distance_near = 100000.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.4
shader_param/intensity = 0.463
shader_param/exponent = 3.0

[sub_resource type="ShaderMaterial" id=15]
shader = ExtResource( 9 )
shader_param/albedo = Color( 1, 0.964706, 0.12549, 1 )
shader_param/scale_near = 0.1
shader_param/scale_peak = 0.2
shader_param/scale_far = 0.05
shader_param/peak_distance = 40000.0
shader_param/fade_ratio = 10.0
shader_param/distance_power = 0.3
shader_param/fade_distance_near = 100000.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.4
shader_param/intensity = 0.671
shader_param/exponent = 2.1

[sub_resource type="ShaderMaterial" id=10]
shader = ExtResource( 9 )
shader_param/albedo = Color( 0.321569, 0.0470588, 0, 1 )
shader_param/scale_near = 10.0
shader_param/scale_peak = 0.5
shader_param/scale_far = 0.1
shader_param/peak_distance = 40000.0
shader_param/fade_ratio = 10.0
shader_param/distance_power = 0.3
shader_param/fade_distance_near = 0.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.4
shader_param/intensity = 1.0
shader_param/exponent = 3.0

[sub_resource type="ShaderMaterial" id=11]
shader = ExtResource( 9 )
shader_param/albedo = Color( 1, 0.984314, 1, 1 )
shader_param/scale_near = 2.415
shader_param/scale_peak = 0.1
shader_param/scale_far = 0.1
shader_param/peak_distance = 40000.0
shader_param/fade_ratio = 10.0
shader_param/distance_power = 0.3
shader_param/fade_distance_near = 0.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.4
shader_param/intensity = 0.687
shader_param/exponent = 3.5

[sub_resource type="ShaderMaterial" id=12]
shader = ExtResource( 9 )
shader_param/albedo = Color( 0, 0.345098, 0.290196, 1 )
shader_param/scale_near = 0.2
shader_param/scale_peak = 1.2
shader_param/scale_far = 0.35
shader_param/peak_distance = 40000.0
shader_param/fade_ratio = 10.0
shader_param/distance_power = 0.3
shader_param/fade_distance_near = 100000.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.4
shader_param/intensity = 0.643
shader_param/exponent = 3.0

[sub_resource type="ShaderMaterial" id=13]
shader = ExtResource( 9 )
shader_param/albedo = Color( 1, 1, 1, 1 )
shader_param/scale_near = 0.1
shader_param/scale_peak = 0.5
shader_param/scale_far = 0.2
shader_param/peak_distance = 40000.0
shader_param/fade_ratio = 10.0
shader_param/distance_power = 0.3
shader_param/fade_distance_near = 100000.0
shader_param/fade_distance_far = 1e+06
shader_param/fade_power = 0.4
shader_param/intensity = 0.764
shader_param/exponent = 3.0

[node name="Globalnebulas" type="Spatial"]
script = SubResource( 7 )
__meta__ = {
"_edit_lock_": true
}

[node name="ClusterA" type="Spatial" parent="."]
transform = Transform( -0.207212, 0.408861, 0.446669, -0.479269, -0.411242, 0.105134, 0.339467, -0.331031, 0.421079, 8655.56, -193353, -364406 )

[node name="spheroid" parent="ClusterA" instance=ExtResource( 1 )]
transform = Transform( -11468.5, 71096, 61539.7, 24198.7, -50095.1, 149348, 126577, 11236.1, -10531.7, -199615, 196235, -325802 )

[node name="Spheroid" parent="ClusterA/spheroid" index="0"]
material_override = SubResource( 1 )

[node name="spheroid2" parent="ClusterA" instance=ExtResource( 1 )]
transform = Transform( 53962.5, 102106, 54519.2, -89588.9, -26699, 172308, 98294.6, -143237, 66075.4, -111196, 190454, -442150 )

[node name="Spheroid" parent="ClusterA/spheroid2" index="0"]
transform = Transform( 0.829987, 0.00768842, -0.581861, 0.238535, -1.00958, 0.0232532, -0.475861, -0.377517, -0.78696, -0.134238, -0.31044, -0.475308 )
material_override = SubResource( 1 )

[node name="spheroid3" parent="ClusterA" instance=ExtResource( 1 )]
transform = Transform( 194042, -38851.3, -149026, 29923.3, 187949, -42734.6, 160582, 11923.3, 188041, -69535.5, 103105, -201030 )

[node name="Spheroid" parent="ClusterA/spheroid3" index="0"]
transform = Transform( 1, 1.86265e-09, 1.49012e-08, 1.49012e-08, 1, -7.45058e-09, 0, -1.86265e-09, 1, 0, 0, 0 )
material_override = SubResource( 1 )

[node name="spheroid4" parent="ClusterA" instance=ExtResource( 1 )]
transform = Transform( -29453.9, -177194, 93306.5, -24422.3, -90428.1, -179438, 198765, -37368.5, -8220.87, -259486, 84157.8, -257839 )

[node name="Spheroid" parent="ClusterA/spheroid4" index="0"]
transform = Transform( 1, 1.86265e-09, 1.49012e-08, 1.49012e-08, 1, -7.45058e-09, 0, -1.86265e-09, 1, 0, 0, 0 )
material_override = SubResource( 1 )

[node name="ClusterA2" type="Spatial" parent="."]
transform = Transform( -0.499423, -0.0293612, -0.653852, -0.671697, 0.240053, 0.537996, 0.115365, 0.913515, -0.194197, 85456.2, -1936.12, -322450 )

[node name="spheroid" parent="ClusterA2" instance=ExtResource( 1 )]
transform = Transform( -11468.5, 71096, 61539.7, 24198.7, -50095.1, 149348, 126577, 11236.1, -10531.7, -123395, -47571.6, -178471 )

[node name="Spheroid" parent="ClusterA2/spheroid" index="0"]
material_override = SubResource( 1 )

[node name="spheroid2" parent="ClusterA2" instance=ExtResource( 1 )]
transform = Transform( -25264.1, 112869, 115233, -130035, -16147.6, 95796.5, 39008, -136798, 145844, 53942.3, -199760, -287988 )

[node name="Spheroid" parent="ClusterA2/spheroid2" index="0"]
transform = Transform( 0.829987, 0.00768842, -0.581861, 0.238535, -1.00958, 0.0232532, -0.475861, -0.377517, -0.78696, -0.134238, -0.31044, -0.475308 )
material_override = SubResource( 1 )

[node name="spheroid3" parent="ClusterA2" instance=ExtResource( 1 )]
transform = Transform( 94972.3, -190368, -74849.5, 206737, 55567.3, 30268, 13823.4, -83883.3, 232327, -71718.6, 105172, -204678 )

[node name="Spheroid" parent="ClusterA2/spheroid3" index="0"]
transform = Transform( 1, 1.86265e-09, 1.49012e-08, 1.49012e-08, 1, -7.45058e-09, 0, -1.86265e-09, 1, 0, 0, 0 )
material_override = SubResource( 1 )

[node name="spheroid4" parent="ClusterA2" instance=ExtResource( 1 )]
transform = Transform( -29453.9, -177194, 93306.4, -24422.3, -90428.1, -179438, 198765, -37368.5, -8220.87, -112326, 25224.5, -216845 )

[node name="Spheroid" parent="ClusterA2/spheroid4" index="0"]
transform = Transform( 1, 1.86265e-09, 1.49012e-08, 1.49012e-08, 1, -7.45058e-09, 0, -1.86265e-09, 1, 0, 0, 0 )
material_override = SubResource( 1 )

[node name="ClusterB" type="Spatial" parent="."]
transform = Transform( -0.0725186, -0.839348, 0.363187, -1.23566, 0.153811, 0.952019, -0.990386, -0.130444, -1.21439, 140103, -119461, 557084 )

[node name="nebula_4" parent="ClusterB" instance=ExtResource( 4 )]
transform = Transform( -81020.7, 80145.8, -38206.3, 113494, -6147.82, -84651.2, -59422.2, -91690.6, -61193.8, 11879, 106178, 141110 )

[node name="nebula_1" parent="ClusterB/nebula_4" index="0"]
transform = Transform( 1, -1.19209e-07, 0, 4.47035e-08, 1, 0, 3.72529e-08, -1.78814e-07, 1, -0.313653, -0.196829, 1.16247 )
material_override = SubResource( 2 )

[node name="nebula_5" parent="ClusterB" instance=ExtResource( 4 )]
transform = Transform( 145936, -124384, 1565.87, 1307.19, 80681.7, -190893, 111065, 135910, 83109.8, -112776, -220433, 59064.4 )

[node name="nebula_1" parent="ClusterB/nebula_5" index="0"]
material_override = SubResource( 2 )

[node name="ClusterC" type="Spatial" parent="."]
transform = Transform( 0.458892, 0.0579308, -0.281655, 0.0222194, 0.521709, 0.143506, 0.286692, -0.133161, 0.439709, -482132, -4545.31, 218681 )

[node name="nebula_4" parent="ClusterC" instance=ExtResource( 5 )]
transform = Transform( -719696, 448823, -306724, 541547, 547534, -469486, -47421.8, -558792, -706393, 0, 0.03125, 0 )

[node name="nebula_2" parent="ClusterC/nebula_4" index="0"]
material_override = SubResource( 5 )

[node name="nebula_5" parent="ClusterC" instance=ExtResource( 5 )]
transform = Transform( -527606, -1.06018e+06, -110063, 991720, -533280, 382856, -390638, 78066.6, 1.12062e+06, 0, 0, 0 )

[node name="nebula_2" parent="ClusterC/nebula_5" index="0"]
material_override = SubResource( 5 )

[node name="Cluster D" type="Spatial" parent="."]
transform = Transform( -0.859772, -0.0592988, -0.241692, -0.122096, -0.656957, 0.595516, -0.21685, 0.605004, 0.622965, -554998, 284016, -225420 )

[node name="nebula_3" parent="Cluster D" instance=ExtResource( 7 )]
transform = Transform( 100000, 0, 0, 0, 100000, 0, 0, 0, 100000, 0, 0, 0 )

[node name="nebula_3" parent="Cluster D/nebula_3" index="0"]
material_override = SubResource( 6 )

[node name="nebula_4" parent="Cluster D" instance=ExtResource( 7 )]
transform = Transform( -68227.9, 4023.75, 49825.2, 48033.5, -18062.9, 67233.2, 13839.2, 82530.8, 12285.6, -83770.7, 41297.6, 66914.3 )

[node name="nebula_3" parent="Cluster D/nebula_4" index="0"]
material_override = SubResource( 6 )

[node name="SectorStars (clipped by near plane which is 10u)" type="Spatial" parent="."]

[node name="Star Elace" type="Spatial" parent="SectorStars (clipped by near plane which is 10u)"]

[node name="Star_sprite_square_wide" parent="SectorStars (clipped by near plane which is 10u)/Star Elace" instance=ExtResource( 10 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="SectorStars (clipped by near plane which is 10u)/Star Elace/Star_sprite_square_wide" index="0"]
material_override = SubResource( 9 )

[node name="Star_sprite_square_wide_far" parent="SectorStars (clipped by near plane which is 10u)/Star Elace" instance=ExtResource( 10 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="SectorStars (clipped by near plane which is 10u)/Star Elace/Star_sprite_square_wide_far" index="0"]
material_override = SubResource( 8 )

[node name="Star Vidr" type="Spatial" parent="SectorStars (clipped by near plane which is 10u)"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -150000, -260000, -330000 )

[node name="Star_sprite_square_wide" parent="SectorStars (clipped by near plane which is 10u)/Star Vidr" instance=ExtResource( 10 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="SectorStars (clipped by near plane which is 10u)/Star Vidr/Star_sprite_square_wide" index="0"]
material_override = SubResource( 14 )

[node name="Star_sprite_square_wide_far" parent="SectorStars (clipped by near plane which is 10u)/Star Vidr" instance=ExtResource( 10 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="SectorStars (clipped by near plane which is 10u)/Star Vidr/Star_sprite_square_wide_far" index="0"]
material_override = SubResource( 15 )

[node name="Stars Lywin" type="Spatial" parent="SectorStars (clipped by near plane which is 10u)"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 70000, 16000, -110000 )

[node name="Star_sprite_square_wide" parent="SectorStars (clipped by near plane which is 10u)/Stars Lywin" instance=ExtResource( 10 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="SectorStars (clipped by near plane which is 10u)/Stars Lywin/Star_sprite_square_wide" index="0"]
material_override = SubResource( 10 )

[node name="Star_sprite_square_wide_far" parent="SectorStars (clipped by near plane which is 10u)/Stars Lywin" instance=ExtResource( 10 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="SectorStars (clipped by near plane which is 10u)/Stars Lywin/Star_sprite_square_wide_far" index="0"]
material_override = SubResource( 11 )

[node name="Star Cob" type="Spatial" parent="SectorStars (clipped by near plane which is 10u)"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -400000, 24000, 130000 )

[node name="Star_sprite_square_wide" parent="SectorStars (clipped by near plane which is 10u)/Star Cob" instance=ExtResource( 10 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="SectorStars (clipped by near plane which is 10u)/Star Cob/Star_sprite_square_wide" index="0"]
material_override = SubResource( 12 )

[node name="Star_sprite_square_wide_far" parent="SectorStars (clipped by near plane which is 10u)/Star Cob" instance=ExtResource( 10 )]
transform = Transform( 13922.7, 5578.2, -205.932, -5529.6, 13706.9, -2558.28, -763.2, 2450.45, 14778.8, 0, 0, 0 )

[node name="Plane" parent="SectorStars (clipped by near plane which is 10u)/Star Cob/Star_sprite_square_wide_far" index="0"]
material_override = SubResource( 13 )

[editable path="ClusterA/spheroid"]
[editable path="ClusterA/spheroid2"]
[editable path="ClusterA/spheroid3"]
[editable path="ClusterA/spheroid4"]
[editable path="ClusterA2/spheroid"]
[editable path="ClusterA2/spheroid2"]
[editable path="ClusterA2/spheroid3"]
[editable path="ClusterA2/spheroid4"]
[editable path="ClusterB/nebula_4"]
[editable path="ClusterB/nebula_5"]
[editable path="ClusterC/nebula_4"]
[editable path="ClusterC/nebula_5"]
[editable path="Cluster D/nebula_3"]
[editable path="Cluster D/nebula_4"]
[editable path="SectorStars (clipped by near plane which is 10u)/Star Elace/Star_sprite_square_wide"]
[editable path="SectorStars (clipped by near plane which is 10u)/Star Elace/Star_sprite_square_wide_far"]
[editable path="SectorStars (clipped by near plane which is 10u)/Star Vidr/Star_sprite_square_wide"]
[editable path="SectorStars (clipped by near plane which is 10u)/Star Vidr/Star_sprite_square_wide_far"]
[editable path="SectorStars (clipped by near plane which is 10u)/Stars Lywin/Star_sprite_square_wide"]
[editable path="SectorStars (clipped by near plane which is 10u)/Stars Lywin/Star_sprite_square_wide_far"]
[editable path="SectorStars (clipped by near plane which is 10u)/Star Cob/Star_sprite_square_wide"]
[editable path="SectorStars (clipped by near plane which is 10u)/Star Cob/Star_sprite_square_wide_far"]

--- Start of ./scenes/ui/hud/main_hud.tscn ---

[gd_scene load_steps=21 format=2]

[ext_resource path="res://src/core/ui/main_hud/main_hud.gd" type="Script" id=1]
[ext_resource path="res://assets/art/ui/controls/button_approach.png" type="Texture" id=2]
[ext_resource path="res://assets/art/ui/controls/button_orbit.png" type="Texture" id=3]
[ext_resource path="res://assets/art/ui/controls/button_placeholder.png" type="Texture" id=4]
[ext_resource path="res://assets/art/ui/controls/button_flee.png" type="Texture" id=5]
[ext_resource path="res://assets/art/ui/controls/button_stop.png" type="Texture" id=6]
[ext_resource path="res://assets/art/ui/controls/button_free_flight.png" type="Texture" id=7]
[ext_resource path="res://assets/art/ui/controls/button_options.png" type="Texture" id=8]
[ext_resource path="res://assets/themes/main_theme.tres" type="Theme" id=9]
[ext_resource path="res://assets/art/ui/controls/button_debug.png" type="Texture" id=10]
[ext_resource path="res://assets/art/ui/controls/button_camera.png" type="Texture" id=11]
[ext_resource path="res://assets/art/ui/controls/button_ui_opacity.png" type="Texture" id=12]
[ext_resource path="res://assets/art/ui/controls/button_attack.png" type="Texture" id=13]
[ext_resource path="res://src/core/ui/helpers/CenteredGrowingLabel.gd" type="Script" id=14]
[ext_resource path="res://assets/art/ui/controls/button_dock.png" type="Texture" id=15]
[ext_resource path="res://assets/art/ui/controls/button_planet.png" type="Texture" id=16]
[ext_resource path="res://assets/art/ui/controls/button_system.png" type="Texture" id=17]
[ext_resource path="res://assets/art/ui/controls/button_character.png" type="Texture" id=18]
[ext_resource path="res://assets/art/ui/controls/button_ship.png" type="Texture" id=19]
[ext_resource path="res://assets/art/ui/controls/button_structure.png" type="Texture" id=20]

[node name="MainHUD" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
mouse_default_cursor_shape = 3
script = ExtResource( 1 )

[node name="ProjectedTargetOverlay" type="Control" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
__meta__ = {
"_edit_lock_": true
}

[node name="ScreenControls" type="Control" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 20.0
margin_top = 20.0
margin_right = -20.0
margin_bottom = -20.0
mouse_filter = 2
__meta__ = {
"_edit_lock_": true
}

[node name="_ScreenUIArea" type="ColorRect" parent="ScreenControls"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0.431373, 0.431373, 0.431373, 0.168627 )
__meta__ = {
"_edit_lock_": true
}

[node name="_CentralVerticalLine" type="ColorRect" parent="ScreenControls/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -1.0
margin_top = -540.0
margin_right = 1.0
margin_bottom = 540.0
color = Color( 1, 1, 1, 0.12549 )

[node name="_CentralHorizontalLine" type="ColorRect" parent="ScreenControls/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -960.0
margin_top = -1.0
margin_right = 960.0
margin_bottom = 1.0
color = Color( 1, 1, 1, 0.12549 )

[node name="_DoNotCoverWithUI" type="ColorRect" parent="ScreenControls"]
visible = false
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -450.0
margin_top = -300.0
margin_right = 450.0
margin_bottom = 300.0
mouse_filter = 2
color = Color( 0.219608, 0.619608, 0.172549, 0.168627 )
__meta__ = {
"_edit_lock_": true
}

[node name="CenterLeftZone" type="Control" parent="ScreenControls"]
anchor_top = 1.0
anchor_bottom = 1.0
margin_top = -1040.0
margin_right = 375.0
mouse_filter = 2
__meta__ = {
"_edit_lock_": true
}

[node name="_ScreenUIArea" type="ColorRect" parent="ScreenControls/CenterLeftZone"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0.431373, 0.431373, 0.431373, 0.168627 )
__meta__ = {
"_edit_lock_": true
}

[node name="_CentralVerticalLine" type="ColorRect" parent="ScreenControls/CenterLeftZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -1.0
margin_top = -540.0
margin_right = 1.0
margin_bottom = 540.0
color = Color( 1, 1, 1, 0.12549 )

[node name="_CentralHorizontalLine" type="ColorRect" parent="ScreenControls/CenterLeftZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -960.0
margin_top = -1.0
margin_right = 960.0
margin_bottom = 1.0
color = Color( 1, 1, 1, 0.12549 )

[node name="ButtonMenu" type="TextureButton" parent="ScreenControls/CenterLeftZone"]
anchor_top = 1.0
anchor_bottom = 1.0
margin_top = -100.0
margin_right = 100.0
texture_normal = ExtResource( 8 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonDebug" type="TextureButton" parent="ScreenControls/CenterLeftZone"]
anchor_top = 1.0
anchor_bottom = 1.0
margin_left = 120.0
margin_top = -100.0
margin_right = 220.0
texture_normal = ExtResource( 10 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonPlaceholder" type="TextureButton" parent="ScreenControls/CenterLeftZone"]
anchor_top = 1.0
anchor_bottom = 1.0
margin_left = 240.0
margin_top = -100.0
margin_right = 340.0
texture_normal = ExtResource( 4 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonOverlayStructures" type="TextureButton" parent="ScreenControls/CenterLeftZone"]
anchor_top = 1.0
anchor_bottom = 1.0
margin_left = 240.0
margin_top = -1040.0
margin_right = 340.0
margin_bottom = -940.0
texture_normal = ExtResource( 20 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonOverlayStellar" type="TextureButton" parent="ScreenControls/CenterLeftZone"]
anchor_top = 1.0
anchor_bottom = 1.0
margin_left = 120.0
margin_top = -1040.0
margin_right = 220.0
margin_bottom = -940.0
texture_normal = ExtResource( 16 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonOverlayJump" type="TextureButton" parent="ScreenControls/CenterLeftZone"]
anchor_top = 1.0
anchor_bottom = 1.0
margin_top = -1040.0
margin_right = 100.0
margin_bottom = -940.0
texture_normal = ExtResource( 17 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="SliderControlLeft" type="VSlider" parent="ScreenControls/CenterLeftZone"]
anchor_top = 0.5
anchor_bottom = 0.5
margin_top = -250.0
margin_right = 100.0
margin_bottom = 250.0
focus_mode = 0
theme = ExtResource( 9 )
tick_count = 10
ticks_on_borders = true
__meta__ = {
"_edit_lock_": true,
"_editor_description_": "Zoom"
}

[node name="LabelContainer" type="Control" parent="ScreenControls/CenterLeftZone"]
anchor_top = 0.5
anchor_bottom = 0.5
margin_left = 30.0
margin_top = 250.0
margin_right = 100.0
margin_bottom = 290.0
__meta__ = {
"_edit_group_": true,
"_edit_lock_": true
}

[node name="LabelZoomSlider" type="Label" parent="ScreenControls/CenterLeftZone/LabelContainer"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -32.5
margin_top = -13.5
margin_right = 32.5
margin_bottom = 13.5
theme = ExtResource( 9 )
text = "ZOOM"
align = 1
script = ExtResource( 14 )
__meta__ = {
"_edit_lock_": true
}

[node name="BottomCenterZone" type="Control" parent="ScreenControls"]
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
margin_left = -565.0
margin_top = -170.0
margin_right = 565.0
mouse_filter = 2
__meta__ = {
"_edit_lock_": true
}

[node name="_ScreenUIArea" type="ColorRect" parent="ScreenControls/BottomCenterZone"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0.431373, 0.431373, 0.431373, 0.168627 )
__meta__ = {
"_edit_lock_": true
}

[node name="_CentralVerticalLine" type="ColorRect" parent="ScreenControls/BottomCenterZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -1.0
margin_top = -540.0
margin_right = 1.0
margin_bottom = 540.0
color = Color( 1, 1, 1, 0.12549 )

[node name="_CentralHorizontalLine" type="ColorRect" parent="ScreenControls/BottomCenterZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -960.0
margin_top = -1.0
margin_right = 960.0
margin_bottom = 1.0
color = Color( 1, 1, 1, 0.12549 )

[node name="ButtonOrbit" type="TextureButton" parent="ScreenControls/BottomCenterZone"]
anchor_left = 0.5
anchor_right = 0.5
margin_left = -235.0
margin_top = 20.0
margin_right = -85.0
margin_bottom = 170.0
texture_normal = ExtResource( 3 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonOrbit" type="Label" parent="ScreenControls/BottomCenterZone/ButtonOrbit"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -35.0
margin_top = -13.5
margin_right = 35.0
margin_bottom = 13.5
theme = ExtResource( 9 )
text = "ORBIT"
align = 1
script = ExtResource( 14 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonStop" type="TextureButton" parent="ScreenControls/BottomCenterZone"]
anchor_left = 0.5
anchor_right = 0.5
margin_left = 85.0
margin_top = 20.0
margin_right = 235.0
margin_bottom = 170.0
texture_normal = ExtResource( 6 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonStop" type="Label" parent="ScreenControls/BottomCenterZone/ButtonStop"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -35.0
margin_top = -13.5
margin_right = 35.0
margin_bottom = 13.5
theme = ExtResource( 9 )
text = "STOP"
align = 1
script = ExtResource( 14 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonManualFlight" type="TextureButton" parent="ScreenControls/BottomCenterZone"]
anchor_left = 0.5
anchor_right = 0.5
margin_left = -75.0
margin_top = 20.0
margin_right = 75.0
margin_bottom = 170.0
texture_normal = ExtResource( 7 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonManualFlight" type="Label" parent="ScreenControls/BottomCenterZone/ButtonManualFlight"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -39.5
margin_top = -13.5
margin_right = 39.5
margin_bottom = 13.5
theme = ExtResource( 9 )
text = "MANUAL"
align = 1
script = ExtResource( 14 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonApproach" type="TextureButton" parent="ScreenControls/BottomCenterZone"]
anchor_left = 0.5
anchor_right = 0.5
margin_left = -555.0
margin_top = 20.0
margin_right = -405.0
margin_bottom = 170.0
texture_normal = ExtResource( 2 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonApproach" type="Label" parent="ScreenControls/BottomCenterZone/ButtonApproach"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -50.5
margin_top = -13.5
margin_right = 50.5
margin_bottom = 13.5
grow_horizontal = 2
theme = ExtResource( 9 )
text = "APPROACH"
align = 1
script = ExtResource( 14 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonFlee" type="TextureButton" parent="ScreenControls/BottomCenterZone"]
anchor_left = 0.5
anchor_right = 0.5
margin_left = -395.0
margin_top = 20.0
margin_right = -245.0
margin_bottom = 170.0
texture_normal = ExtResource( 5 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonFlee" type="Label" parent="ScreenControls/BottomCenterZone/ButtonFlee"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -35.0
margin_top = -13.5
margin_right = 35.0
margin_bottom = 13.5
theme = ExtResource( 9 )
text = "FLEE"
align = 1
script = ExtResource( 14 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonDock" type="TextureButton" parent="ScreenControls/BottomCenterZone"]
anchor_left = 0.5
anchor_right = 0.5
margin_left = 245.0
margin_top = 20.0
margin_right = 395.0
margin_bottom = 170.0
texture_normal = ExtResource( 15 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonDock" type="Label" parent="ScreenControls/BottomCenterZone/ButtonDock"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -35.0
margin_top = -13.5
margin_right = 35.0
margin_bottom = 13.5
grow_horizontal = 2
theme = ExtResource( 9 )
text = "DOCK"
align = 1
script = ExtResource( 14 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonAttack" type="TextureButton" parent="ScreenControls/BottomCenterZone"]
anchor_left = 0.5
anchor_right = 0.5
margin_left = 405.0
margin_top = 20.0
margin_right = 555.0
margin_bottom = 170.0
texture_normal = ExtResource( 13 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonAttack" type="Label" parent="ScreenControls/BottomCenterZone/ButtonAttack"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -35.0
margin_top = -13.5
margin_right = 35.0
margin_bottom = 13.5
grow_horizontal = 2
theme = ExtResource( 9 )
text = "ATTACK"
align = 1
script = ExtResource( 14 )
__meta__ = {
"_edit_lock_": true
}

[node name="CenterRightZone" type="Control" parent="ScreenControls"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -375.0
margin_top = -1040.0
mouse_filter = 2
__meta__ = {
"_edit_lock_": true
}

[node name="_ScreenUIArea" type="ColorRect" parent="ScreenControls/CenterRightZone"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0.431373, 0.431373, 0.431373, 0.168627 )
__meta__ = {
"_edit_lock_": true
}

[node name="_CentralVerticalLine" type="ColorRect" parent="ScreenControls/CenterRightZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -1.0
margin_top = -540.0
margin_right = 1.0
margin_bottom = 540.0
color = Color( 1, 1, 1, 0.12549 )

[node name="_CentralHorizontalLine" type="ColorRect" parent="ScreenControls/CenterRightZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -960.0
margin_top = -1.0
margin_right = 960.0
margin_bottom = 1.0
color = Color( 1, 1, 1, 0.12549 )

[node name="ButtonUIOpacity" type="TextureButton" parent="ScreenControls/CenterRightZone"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -100.0
margin_top = -100.0
texture_normal = ExtResource( 12 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonCamera" type="TextureButton" parent="ScreenControls/CenterRightZone"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -220.0
margin_top = -100.0
margin_right = -120.0
texture_normal = ExtResource( 11 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonPlaceholder" type="TextureButton" parent="ScreenControls/CenterRightZone"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -340.0
margin_top = -100.0
margin_right = -240.0
texture_normal = ExtResource( 4 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonCharacter" type="TextureButton" parent="ScreenControls/CenterRightZone"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -340.0
margin_top = -1040.0
margin_right = -240.0
margin_bottom = -940.0
texture_normal = ExtResource( 18 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonShip" type="TextureButton" parent="ScreenControls/CenterRightZone"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -220.0
margin_top = -1040.0
margin_right = -120.0
margin_bottom = -940.0
texture_normal = ExtResource( 19 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonPlaceholder4" type="TextureButton" parent="ScreenControls/CenterRightZone"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -100.0
margin_top = -1040.0
margin_bottom = -940.0
texture_normal = ExtResource( 4 )
expand = true
__meta__ = {
"_edit_lock_": true
}

[node name="SliderControlRight" type="VSlider" parent="ScreenControls/CenterRightZone"]
anchor_left = 1.0
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
margin_top = 250.0
margin_right = 100.0
margin_bottom = 750.0
rect_rotation = 180.0
focus_mode = 0
theme = ExtResource( 9 )
tick_count = 10
ticks_on_borders = true
__meta__ = {
"_edit_lock_": true,
"_editor_description_": "Speed"
}

[node name="_ScreenUIArea" type="ColorRect" parent="ScreenControls/CenterRightZone/SliderControlRight"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0.431373, 0.431373, 0.431373, 0.168627 )

[node name="_CentralVerticalLine" type="ColorRect" parent="ScreenControls/CenterRightZone/SliderControlRight/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -1.0
margin_top = -540.0
margin_right = 1.0
margin_bottom = 540.0
color = Color( 1, 1, 1, 0.12549 )

[node name="_CentralHorizontalLine" type="ColorRect" parent="ScreenControls/CenterRightZone/SliderControlRight/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -960.0
margin_top = -1.0
margin_right = 960.0
margin_bottom = 1.0
color = Color( 1, 1, 1, 0.12549 )

[node name="LabelContainer" type="Control" parent="ScreenControls/CenterRightZone"]
anchor_left = 1.0
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
margin_left = -100.0
margin_top = 250.0
margin_right = -30.0
margin_bottom = 290.0
__meta__ = {
"_edit_group_": true,
"_edit_lock_": true
}

[node name="LabelThrustSlider" type="Label" parent="ScreenControls/CenterRightZone/LabelContainer"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -32.5
margin_top = -13.5
margin_right = 32.5
margin_bottom = 13.5
theme = ExtResource( 9 )
text = "THRUST"
align = 1
script = ExtResource( 14 )
__meta__ = {
"_edit_lock_": true
}

[node name="TopLeftZone" type="Control" parent="ScreenControls"]
margin_left = 375.0
margin_right = 940.0
margin_bottom = 195.0
mouse_filter = 2
__meta__ = {
"_edit_lock_": true
}

[node name="_ScreenUIArea" type="ColorRect" parent="ScreenControls/TopLeftZone"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0.431373, 0.431373, 0.431373, 0.168627 )
__meta__ = {
"_edit_lock_": true
}

[node name="_CentralVerticalLine" type="ColorRect" parent="ScreenControls/TopLeftZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -1.0
margin_top = -540.0
margin_right = 1.0
margin_bottom = 540.0
color = Color( 1, 1, 1, 0.12549 )

[node name="_CentralHorizontalLine" type="ColorRect" parent="ScreenControls/TopLeftZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -960.0
margin_top = -1.0
margin_right = 960.0
margin_bottom = 1.0
color = Color( 1, 1, 1, 0.12549 )

[node name="TopRightZone" type="Control" parent="ScreenControls"]
anchor_left = 1.0
anchor_right = 1.0
margin_left = -940.0
margin_right = -375.0
margin_bottom = 196.0
mouse_filter = 2
__meta__ = {
"_edit_lock_": true
}

[node name="_ScreenUIArea" type="ColorRect" parent="ScreenControls/TopRightZone"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0.431373, 0.431373, 0.431373, 0.168627 )
__meta__ = {
"_edit_lock_": true
}

[node name="_CentralVerticalLine" type="ColorRect" parent="ScreenControls/TopRightZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -1.0
margin_top = -540.0
margin_right = 1.0
margin_bottom = 540.0
color = Color( 1, 1, 1, 0.12549 )

[node name="_CentralHorizontalLine" type="ColorRect" parent="ScreenControls/TopRightZone/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -960.0
margin_top = -1.0
margin_right = 960.0
margin_bottom = 1.0
color = Color( 1, 1, 1, 0.12549 )

[node name="GameOverOverlay (to be made into a dedicated window like main menu)" type="Control" parent="."]
pause_mode = 2
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 1

[node name="CenterContainer" type="CenterContainer" parent="GameOverOverlay (to be made into a dedicated window like main menu)"]
anchor_right = 1.0
anchor_bottom = 1.0

[node name="PanelContainer" type="PanelContainer" parent="GameOverOverlay (to be made into a dedicated window like main menu)/CenterContainer"]
margin_left = 953.0
margin_top = 533.0
margin_right = 967.0
margin_bottom = 547.0
theme = ExtResource( 9 )

[node name="VBoxContainer" type="VBoxContainer" parent="GameOverOverlay (to be made into a dedicated window like main menu)/CenterContainer/PanelContainer"]
margin_left = 7.0
margin_top = 7.0
margin_right = 146.0
margin_bottom = 69.0

[node name="LabelGameOver" type="Label" parent="GameOverOverlay (to be made into a dedicated window like main menu)/CenterContainer/PanelContainer/VBoxContainer"]
margin_right = 139.0
margin_bottom = 27.0
theme = ExtResource( 9 )
text = "GAME OVER"
align = 1

[node name="ButtonReturnToMenu" type="Button" parent="GameOverOverlay (to be made into a dedicated window like main menu)/CenterContainer/PanelContainer/VBoxContainer"]
margin_top = 31.0
margin_right = 139.0
margin_bottom = 62.0
theme = ExtResource( 9 )
text = "Return to Menu"

[connection signal="pressed" from="ScreenControls/CenterLeftZone/ButtonMenu" to="." method="_on_ButtonMenu_pressed"]
[connection signal="pressed" from="ScreenControls/CenterLeftZone/ButtonDebug" to="." method="_on_ButtonDebug_pressed"]
[connection signal="value_changed" from="ScreenControls/CenterLeftZone/SliderControlLeft" to="." method="_on_SliderControlLeft_value_changed"]
[connection signal="pressed" from="ScreenControls/BottomCenterZone/ButtonOrbit" to="." method="_on_ButtonOrbit_pressed"]
[connection signal="pressed" from="ScreenControls/BottomCenterZone/ButtonStop" to="." method="_on_ButtonStop_pressed"]
[connection signal="pressed" from="ScreenControls/BottomCenterZone/ButtonManualFlight" to="." method="_on_ButtonFreeFlight_pressed"]
[connection signal="pressed" from="ScreenControls/BottomCenterZone/ButtonApproach" to="." method="_on_ButtonApproach_pressed"]
[connection signal="pressed" from="ScreenControls/BottomCenterZone/ButtonFlee" to="." method="_on_ButtonFlee_pressed"]
[connection signal="pressed" from="ScreenControls/BottomCenterZone/ButtonDock" to="." method="_on_ButtonDock_pressed"]
[connection signal="pressed" from="ScreenControls/BottomCenterZone/ButtonAttack" to="." method="_on_ButtonAttack_pressed"]
[connection signal="pressed" from="ScreenControls/CenterRightZone/ButtonUIOpacity" to="." method="_on_ButtonUIOpacity_pressed"]
[connection signal="value_changed" from="ScreenControls/CenterRightZone/SliderControlRight" to="." method="_on_SliderControlRight_value_changed"]
[connection signal="pressed" from="GameOverOverlay (to be made into a dedicated window like main menu)/CenterContainer/PanelContainer/VBoxContainer/ButtonReturnToMenu" to="." method="_on_ButtonReturnToMenu_pressed"]

--- Start of ./scenes/ui/hud/projected_target_bracket.tscn ---

[gd_scene load_steps=6 format=2]

[ext_resource path="res://src/core/ui/main_hud/projected_target_bracket.gd" type="Script" id=1]
[ext_resource path="res://assets/art/ui/controls/bracket_targeting.png" type="Texture" id=2]
[ext_resource path="res://assets/art/ui/controls/bracket_targeting_selected.png" type="Texture" id=3]
[ext_resource path="res://assets/themes/main_theme.tres" type="Theme" id=4]
[ext_resource path="res://src/core/ui/helpers/CenteredGrowingLabel.gd" type="Script" id=5]

[node name="ProjectedTargetBracket" type="Button"]
margin_right = 150.0
margin_bottom = 150.0
focus_mode = 0
theme = ExtResource( 4 )
flat = true
script = ExtResource( 1 )

[node name="BracketNormal" type="TextureRect" parent="."]
modulate = Color( 0.35, 0.95, 1, 0.95 )
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
texture = ExtResource( 2 )
stretch_mode = 4
__meta__ = {
"_edit_lock_": true
}

[node name="BracketSelected" type="TextureRect" parent="."]
modulate = Color( 1, 0.901961, 0.34902, 1 )
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
texture = ExtResource( 3 )
stretch_mode = 4
__meta__ = {
"_edit_lock_": true
}

[node name="DistancePanel" type="Control" parent="BracketSelected"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = 12.0
margin_top = -50.0
margin_right = 92.0
margin_bottom = -12.0
mouse_filter = 2
__meta__ = {
"_edit_group_": true,
"_edit_lock_": true
}

[node name="DistanceLabel" type="Label" parent="BracketSelected/DistancePanel"]
modulate = Color( 1, 0.901961, 0.34902, 1 )
anchor_right = 1.0
anchor_bottom = 1.0
text = "0000k"
align = 1
valign = 1
autowrap = true
script = ExtResource( 5 )
__meta__ = {
"_edit_lock_": true
}

[node name="InfoPanel" type="Control" parent="."]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -140.0
margin_top = 25.0
margin_right = 140.0
margin_bottom = 81.0
mouse_filter = 2
__meta__ = {
"_edit_group_": true,
"_edit_lock_": true
}

[node name="InfoLabel" type="Label" parent="InfoPanel"]
anchor_right = 1.0
anchor_bottom = 1.0
text = "TARGET"
align = 1
valign = 1
autowrap = true
script = ExtResource( 5 )
__meta__ = {
"_edit_lock_": true
}

--- Start of ./scenes/ui/hud/radar_display.tscn ---

[gd_scene load_steps=3 format=2]

[ext_resource path="res://src/core/ui/radar_display/radar_display.gd" type="Script" id=1]

[sub_resource type="StyleBoxFlat" id=1]
bg_color = Color( 0.1, 0.1, 0.12, 0.85 )

[node name="RadarDisplay" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource( 1 )

[node name="PanelBg" type="Panel" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
custom_styles/panel = SubResource( 1 )

[node name="VBoxContainer" type="VBoxContainer" parent="PanelBg"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 10.0
margin_top = 10.0
margin_right = -10.0
margin_bottom = -10.0

[node name="HeaderLabel" type="Label" parent="PanelBg/VBoxContainer"]
margin_right = 1900.0
margin_bottom = 14.0
text = "SECTOR SCAN"

[node name="SectorLabel" type="Label" parent="PanelBg/VBoxContainer"]
margin_top = 18.0
margin_right = 1900.0
margin_bottom = 32.0
custom_colors/font_color = Color( 0.7, 0.7, 0.7, 1 )

[node name="HSeparator" type="HSeparator" parent="PanelBg/VBoxContainer"]
margin_top = 36.0
margin_right = 1900.0
margin_bottom = 40.0

[node name="ContactList" type="VBoxContainer" parent="PanelBg/VBoxContainer"]
margin_top = 44.0
margin_right = 1900.0
margin_bottom = 1060.0
size_flags_horizontal = 3
size_flags_vertical = 3

--- Start of ./scenes/ui/hud/sector_info_panel.tscn ---

[gd_scene load_steps=3 format=2]

[ext_resource path="res://src/core/ui/sector_info_panel/sector_info_panel.gd" type="Script" id=1]

[sub_resource type="StyleBoxFlat" id=1]
bg_color = Color( 0.1, 0.1, 0.12, 0.85 )

[node name="SectorInfoPanel" type="Control"]
anchor_left = 0.5
anchor_right = 0.5
margin_left = -300.0
margin_right = 300.0
rect_min_size = Vector2( 0, 50 )
mouse_filter = 2
script = ExtResource( 1 )

[node name="PanelBg" type="Panel" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
custom_styles/panel = SubResource( 1 )

[node name="InfoLabel" type="RichTextLabel" parent="PanelBg"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 8.0
margin_top = 4.0
margin_right = -8.0
margin_bottom = -4.0
bbcode_enabled = true
bbcode_text = "Awaiting sensor data..."
text = "Awaiting sensor data..."
scroll_active = false

--- Start of ./scenes/ui/hud/sim_debug_panel.tscn ---

[gd_scene load_steps=6 format=2]

[ext_resource path="res://src/core/ui/sim_debug_panel/sim_debug_panel.gd" type="Script" id=1]
[ext_resource path="res://assets/fonts/Roboto_Condensed/static/RobotoCondensed-Regular.ttf" type="DynamicFontData" id=2]
[ext_resource path="res://assets/themes/main_theme.tres" type="Theme" id=3]
[ext_resource path="res://scenes/ui/shared/window_close_button.tscn" type="PackedScene" id=4]

[sub_resource type="DynamicFont" id=1]
size = 22
font_data = ExtResource( 2 )

[node name="SimDebugPanel" type="CanvasLayer"]
script = ExtResource( 1 )

[node name="Panel" type="Panel" parent="."]
visible = false
self_modulate = Color( 0, 0, 0, 0.85 )
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 10.0
margin_top = 10.0
margin_right = -10.0
margin_bottom = -10.0

[node name="VBoxContainer" type="VBoxContainer" parent="Panel"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 8.0
margin_top = 8.0
margin_right = -8.0
margin_bottom = -8.0

[node name="HeaderRow" type="HBoxContainer" parent="Panel/VBoxContainer"]
margin_right = 1884.0
margin_bottom = 36.0

[node name="HeaderLabel" type="Label" parent="Panel/VBoxContainer/HeaderRow"]
size_flags_horizontal = 3
custom_fonts/font = SubResource( 1 )
text = "SIM DEBUG  [F3 to close]"

[node name="BtnDumpConsole" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 220, 0 )
theme = ExtResource( 3 )
text = "Dump to Console"

[node name="BtnTick" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 180, 0 )
theme = ExtResource( 3 )
text = "Advance 1 Tick"

[node name="BtnRun30" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 120, 0 )
theme = ExtResource( 3 )
text = "Run 30"

[node name="BtnRun300" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 120, 0 )
theme = ExtResource( 3 )
text = "Run 300"

[node name="BtnRun3000" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 130, 0 )
theme = ExtResource( 3 )
text = "Run 3000"

[node name="BtnBack" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 120, 0 )
theme = ExtResource( 3 )
text = "< Back"

[node name="BtnClose" parent="Panel/VBoxContainer/HeaderRow" instance=ExtResource( 4 )]

[node name="RichTextLabel" type="RichTextLabel" parent="Panel/VBoxContainer"]
margin_top = 40.0
margin_right = 1884.0
margin_bottom = 1044.0
size_flags_vertical = 3
custom_fonts/bold_font = SubResource( 1 )
custom_fonts/normal_font = SubResource( 1 )
bbcode_enabled = true

--- Start of ./scenes/ui/menus/debug_window.tscn ---

[gd_scene load_steps=4 format=2]

[ext_resource path="res://src/core/ui/debug_window/debug_window.gd" type="Script" id=1]
[ext_resource path="res://assets/themes/main_theme.tres" type="Theme" id=2]
[ext_resource path="res://scenes/ui/shared/window_close_button.tscn" type="PackedScene" id=3]

[node name="DebugWindow" type="Control"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
theme = ExtResource( 2 )
mouse_filter = 1
script = ExtResource( 1 )

[node name="Background" type="ColorRect" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0, 0, 0, 0.4 )

[node name="Panel" type="Panel" parent="."]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -380.0
margin_top = -340.0
margin_right = 380.0
margin_bottom = 340.0

[node name="VBoxContainer" type="VBoxContainer" parent="Panel"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 20.0
margin_top = 20.0
margin_right = -20.0
margin_bottom = -20.0
custom_constants/separation = 16

[node name="debug_HeaderRow" type="HBoxContainer" parent="Panel/VBoxContainer"]
margin_right = 720.0
margin_bottom = 150.0
alignment = 1

[node name="debug_LabelTitle" type="Label" parent="Panel/VBoxContainer/debug_HeaderRow"]
size_flags_horizontal = 3
margin_top = 61.0
margin_right = 570.0
margin_bottom = 88.0
text = "Debug Window"

[node name="debug_ButtonClose" parent="Panel/VBoxContainer/debug_HeaderRow" instance=ExtResource( 3 )]
margin_left = 570.0
margin_right = 720.0
margin_bottom = 150.0

[node name="debug_LabelCredits" type="Label" parent="Panel/VBoxContainer"]
margin_top = 166.0
margin_right = 720.0
margin_bottom = 193.0
text = "Credits: --"

[node name="debug_LabelFP" type="Label" parent="Panel/VBoxContainer"]
margin_top = 209.0
margin_right = 720.0
margin_bottom = 236.0
text = "Current FP: --"

[node name="debug_LabelTime" type="Label" parent="Panel/VBoxContainer"]
margin_top = 252.0
margin_right = 720.0
margin_bottom = 279.0
text = "Time: 00:00"

[node name="debug_LabelPlayerHull" type="Label" parent="Panel/VBoxContainer"]
margin_top = 295.0
margin_right = 720.0
margin_bottom = 322.0
text = "Hull: 100%"

[node name="debug_PlayerHullBar" type="ProgressBar" parent="Panel/VBoxContainer"]
margin_top = 338.0
margin_right = 720.0
margin_bottom = 352.0
value = 100.0

[node name="debug_ButtonSimPanel" type="Button" parent="Panel/VBoxContainer"]
margin_top = 368.0
margin_right = 720.0
margin_bottom = 418.0
rect_min_size = Vector2( 0, 50 )
text = "SIM DEBUG"

[node name="debug_ButtonMapPanel" type="Button" parent="Panel/VBoxContainer"]
margin_top = 434.0
margin_right = 720.0
margin_bottom = 484.0
rect_min_size = Vector2( 0, 50 )
text = "MAP DEBUG"

[node name="debug_ButtonInventory" type="Button" parent="Panel/VBoxContainer"]
margin_top = 500.0
margin_right = 720.0
margin_bottom = 550.0
rect_min_size = Vector2( 0, 50 )
disabled = true
text = "Placeholder"

--- Start of ./scenes/ui/menus/main_menu.tscn ---

[gd_scene load_steps=15 format=2]

[ext_resource path="res://assets/art/ui/main_menu/button_start_new_game.png" type="Texture" id=1]
[ext_resource path="res://assets/themes/main_theme.tres" type="Theme" id=2]
[ext_resource path="res://src/core/ui/main_menu/main_menu.gd" type="Script" id=3]
[ext_resource path="res://assets/art/ui/main_menu/button_load_game.png" type="Texture" id=4]
[ext_resource path="res://assets/art/ui/main_menu/button_exit_game.png" type="Texture" id=5]
[ext_resource path="res://assets/art/ui/main_menu/button_save_game.png" type="Texture" id=6]
[ext_resource path="res://assets/art/ui/main_menu/button_settings.png" type="Texture" id=7]
[ext_resource path="res://assets/fonts/Roboto_Condensed/static/RobotoCondensed-Regular.ttf" type="DynamicFontData" id=8]
[ext_resource path="res://src/core/ui/helpers/CenteredGrowingLabel.gd" type="Script" id=10]
[ext_resource path="res://scenes/ui/shared/window_close_button.tscn" type="PackedScene" id=11]

[sub_resource type="DynamicFont" id=4]
size = 50
font_data = ExtResource( 8 )

[sub_resource type="DynamicFont" id=1]
size = 100
font_data = ExtResource( 8 )

[sub_resource type="DynamicFont" id=2]
size = 50
font_data = ExtResource( 8 )

[sub_resource type="DynamicFont" id=3]
size = 50
font_data = ExtResource( 8 )

[node name="MainMenu" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource( 3 )
__meta__ = {
"_edit_lock_": true
}

[node name="ScreenControls" type="Control" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
__meta__ = {
"_edit_lock_": true
}

[node name="_ScreenUIArea" type="ColorRect" parent="ScreenControls"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color( 0.431373, 0.431373, 0.431373, 0.168627 )
__meta__ = {
"_edit_lock_": true
}

[node name="_CentralVerticalLine" type="ColorRect" parent="ScreenControls/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -1.0
margin_top = -540.0
margin_right = 1.0
margin_bottom = 540.0
color = Color( 1, 1, 1, 0.12549 )

[node name="_CentralHorizontalLine" type="ColorRect" parent="ScreenControls/_ScreenUIArea"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -960.0
margin_top = -1.0
margin_right = 960.0
margin_bottom = 1.0
color = Color( 1, 1, 1, 0.12549 )

[node name="Background" type="ColorRect" parent="ScreenControls"]
anchor_right = 1.0
anchor_bottom = 1.0
color = Color( 0.14902, 0.211765, 0.196078, 1 )
__meta__ = {
"_edit_lock_": true
}

[node name="MainButtonsHBoxContainer" type="HBoxContainer" parent="ScreenControls"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -960.0
margin_top = -245.0
margin_right = 960.0
margin_bottom = 205.0
theme = ExtResource( 2 )
alignment = 1
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonStartNewGame" type="TextureButton" parent="ScreenControls/MainButtonsHBoxContainer"]
margin_left = 130.0
margin_right = 430.0
margin_bottom = 450.0
texture_normal = ExtResource( 1 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelContainerControl" type="Control" parent="ScreenControls/MainButtonsHBoxContainer/ButtonStartNewGame"]
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
margin_left = -150.0
margin_top = -75.0
margin_right = 150.0
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonNew" type="Label" parent="ScreenControls/MainButtonsHBoxContainer/ButtonStartNewGame/LabelContainerControl"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -47.0
margin_top = -30.0
margin_right = 47.0
margin_bottom = 30.0
theme = ExtResource( 2 )
custom_fonts/font = SubResource( 4 )
text = "New"
align = 1
script = ExtResource( 10 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonLoadGame" type="TextureButton" parent="ScreenControls/MainButtonsHBoxContainer"]
margin_left = 470.0
margin_right = 770.0
margin_bottom = 450.0
texture_normal = ExtResource( 4 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelContainerControl" type="Control" parent="ScreenControls/MainButtonsHBoxContainer/ButtonLoadGame"]
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
margin_left = -150.0
margin_top = -75.0
margin_right = 150.0
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonLoad" type="Label" parent="ScreenControls/MainButtonsHBoxContainer/ButtonLoadGame/LabelContainerControl"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -56.0
margin_top = -30.0
margin_right = 56.0
margin_bottom = 30.0
theme = ExtResource( 2 )
custom_fonts/font = SubResource( 4 )
text = "Load"
align = 1
script = ExtResource( 10 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonSaveGame" type="TextureButton" parent="ScreenControls/MainButtonsHBoxContainer"]
margin_left = 810.0
margin_right = 1110.0
margin_bottom = 450.0
texture_normal = ExtResource( 6 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelContainerControl" type="Control" parent="ScreenControls/MainButtonsHBoxContainer/ButtonSaveGame"]
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
margin_left = -150.0
margin_top = -75.0
margin_right = 150.0
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonSave" type="Label" parent="ScreenControls/MainButtonsHBoxContainer/ButtonSaveGame/LabelContainerControl"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -54.0
margin_top = -30.0
margin_right = 54.0
margin_bottom = 30.0
theme = ExtResource( 2 )
custom_fonts/font = SubResource( 4 )
text = "Save"
align = 1
script = ExtResource( 10 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonSettings" type="TextureButton" parent="ScreenControls/MainButtonsHBoxContainer"]
margin_left = 1150.0
margin_right = 1450.0
margin_bottom = 450.0
texture_normal = ExtResource( 7 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelContainerControl" type="Control" parent="ScreenControls/MainButtonsHBoxContainer/ButtonSettings"]
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
margin_left = -150.0
margin_top = -75.0
margin_right = 150.0
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonSettings" type="Label" parent="ScreenControls/MainButtonsHBoxContainer/ButtonSettings/LabelContainerControl"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -101.5
margin_top = -30.0
margin_right = 101.5
margin_bottom = 30.0
theme = ExtResource( 2 )
custom_fonts/font = SubResource( 4 )
text = "Settings"
align = 1
script = ExtResource( 10 )
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonExitgame" type="TextureButton" parent="ScreenControls/MainButtonsHBoxContainer"]
margin_left = 1490.0
margin_right = 1790.0
margin_bottom = 450.0
texture_normal = ExtResource( 5 )
__meta__ = {
"_edit_lock_": true
}

[node name="LabelContainerControl" type="Control" parent="ScreenControls/MainButtonsHBoxContainer/ButtonExitgame"]
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
margin_left = -150.0
margin_top = -75.0
margin_right = 150.0
__meta__ = {
"_edit_lock_": true
}

[node name="LabelButtonExit" type="Label" parent="ScreenControls/MainButtonsHBoxContainer/ButtonExitgame/LabelContainerControl"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -46.0
margin_top = -30.0
margin_right = 46.0
margin_bottom = 30.0
theme = ExtResource( 2 )
custom_fonts/font = SubResource( 4 )
text = "Exit"
align = 1
script = ExtResource( 10 )
__meta__ = {
"_edit_lock_": true
}

[node name="TitleLabel" type="Label" parent="ScreenControls"]
anchor_left = 0.5
anchor_right = 0.5
margin_left = -217.5
margin_top = 40.0
margin_right = 217.5
margin_bottom = 158.0
theme = ExtResource( 2 )
custom_fonts/font = SubResource( 1 )
text = "GDTLancer"
__meta__ = {
"_edit_lock_": true
}

[node name="TimeLabel" type="Label" parent="ScreenControls"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = -152.0
margin_top = -100.0
margin_right = -40.0
margin_bottom = -40.0
theme = ExtResource( 2 )
custom_fonts/font = SubResource( 2 )
text = "14:45"
__meta__ = {
"_edit_lock_": true
}

[node name="VersionLabel" type="Label" parent="ScreenControls"]
anchor_top = 1.0
anchor_bottom = 1.0
margin_left = 40.0
margin_top = -100.0
margin_right = 256.0
margin_bottom = -40.0
theme = ExtResource( 2 )
custom_fonts/font = SubResource( 3 )
text = "version 0.1"
__meta__ = {
"_edit_lock_": true
}

[node name="ButtonClose" parent="ScreenControls" instance=ExtResource( 11 )]
anchor_left = 1.0
anchor_right = 1.0
margin_left = -150.0
margin_right = 0.0
margin_bottom = 150.0
__meta__ = {
"_edit_lock_": true
}

--- Start of ./scenes/ui/menus/station_menu/StationMenu.tscn ---

[gd_scene load_steps=4 format=2]

[ext_resource path="res://src/core/ui/station_menu/station_menu.gd" type="Script" id=1]
[ext_resource path="res://assets/themes/main_theme.tres" type="Theme" id=2]
[ext_resource path="res://scenes/ui/shared/window_close_button.tscn" type="PackedScene" id=3]

[node name="StationMenu" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
theme = ExtResource( 2 )
script = ExtResource( 1 )

[node name="ColorRect" type="ColorRect" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 1
color = Color( 0, 0, 0, 0.5 )

[node name="Panel" type="Panel" parent="."]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -200.0
margin_top = -200.0
margin_right = 200.0
margin_bottom = 200.0

[node name="VBoxContainer" type="VBoxContainer" parent="Panel"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 20.0
margin_top = 20.0
margin_right = -20.0
margin_bottom = -20.0
custom_constants/separation = 15

[node name="HeaderRow" type="HBoxContainer" parent="Panel/VBoxContainer"]
margin_right = 360.0
margin_bottom = 150.0

[node name="LabelStationName" type="Label" parent="Panel/VBoxContainer/HeaderRow"]
size_flags_horizontal = 3
margin_top = 61.0
margin_right = 210.0
margin_bottom = 88.0
text = "Station Name"
align = 1

[node name="BtnClose" parent="Panel/VBoxContainer/HeaderRow" instance=ExtResource( 3 )]
margin_left = 210.0
margin_right = 360.0
margin_bottom = 150.0

[node name="HSeparator" type="HSeparator" parent="Panel/VBoxContainer"]
margin_top = 165.0
margin_right = 360.0
margin_bottom = 169.0

[node name="LabelInfo" type="Label" parent="Panel/VBoxContainer"]
margin_top = 184.0
margin_right = 360.0
margin_bottom = 211.0
text = ""
align = 1

[node name="BtnTrade" type="Button" parent="Panel/VBoxContainer"]
margin_top = 226.0
margin_right = 360.0
margin_bottom = 276.0
rect_min_size = Vector2( 0, 50 )
text = "Trade (coming soon)"

[node name="BtnContracts" type="Button" parent="Panel/VBoxContainer"]
margin_top = 291.0
margin_right = 360.0
margin_bottom = 341.0
rect_min_size = Vector2( 0, 50 )
text = "Contracts (coming soon)"

[node name="HSeparator2" type="HSeparator" parent="Panel/VBoxContainer"]
margin_top = 356.0
margin_right = 360.0
margin_bottom = 360.0

[node name="BtnUndock" type="Button" parent="Panel/VBoxContainer"]
margin_top = 375.0
margin_right = 360.0
margin_bottom = 425.0
rect_min_size = Vector2( 0, 50 )
text = "Undock"

--- Start of ./scenes/ui/shared/window_close_button.tscn ---

[gd_scene load_steps=2 format=2]

[ext_resource path="res://assets/art/ui/controls/button_close.png" type="Texture" id=1]

[node name="WindowCloseButton" type="TextureButton"]
rect_min_size = Vector2( 150, 150 )
focus_mode = 0
texture_normal = ExtResource( 1 )
expand = true

--- Start of ./src/core/ui/debug_map_panel/debug_map_panel.tscn ---

[gd_scene load_steps=6 format=2]

[ext_resource path="res://src/core/ui/debug_map_panel/debug_map_panel.gd" type="Script" id=1]
[ext_resource path="res://assets/fonts/Roboto_Condensed/static/RobotoCondensed-Regular.ttf" type="DynamicFontData" id=2]
[ext_resource path="res://assets/themes/main_theme.tres" type="Theme" id=3]
[ext_resource path="res://scenes/ui/shared/window_close_button.tscn" type="PackedScene" id=4]

[sub_resource type="DynamicFont" id=1]
size = 18
font_data = ExtResource( 2 )

[node name="DebugMapPanel" type="CanvasLayer"]
layer = 101
script = ExtResource( 1 )

[node name="Panel" type="Panel" parent="."]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
self_modulate = Color( 0.05, 0.05, 0.1, 1 )

[node name="VBoxContainer" type="VBoxContainer" parent="Panel"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 8.0
margin_top = 8.0
margin_right = -8.0
margin_bottom = -8.0

[node name="HeaderRow" type="HBoxContainer" parent="Panel/VBoxContainer"]
margin_right = 1.0
margin_bottom = 36.0

[node name="HeaderLabel" type="Label" parent="Panel/VBoxContainer/HeaderRow"]
size_flags_horizontal = 3
custom_fonts/font = SubResource( 1 )
text = "GALACTIC MAP  [F4 to close]"

[node name="BtnRotL" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 50, 0 )
theme = ExtResource( 3 )
text = "RotL"

[node name="BtnRotR" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 50, 0 )
theme = ExtResource( 3 )
text = "RotR"

[node name="BtnRotU" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 50, 0 )
theme = ExtResource( 3 )
text = "RotU"

[node name="BtnRotD" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 50, 0 )
theme = ExtResource( 3 )
text = "RotD"

[node name="BtnZoomIn" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 40, 0 )
theme = ExtResource( 3 )
text = "+"

[node name="BtnZoomOut" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 40, 0 )
theme = ExtResource( 3 )
text = "-"

[node name="BtnCoords" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 80, 0 )
theme = ExtResource( 3 )
text = "Coords"

[node name="BtnAxes" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 90, 0 )
theme = ExtResource( 3 )
text = "Axes On"

[node name="BtnPanL" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 55, 0 )
theme = ExtResource( 3 )
text = "PanL"

[node name="BtnPanR" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 55, 0 )
theme = ExtResource( 3 )
text = "PanR"

[node name="BtnPanU" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 55, 0 )
theme = ExtResource( 3 )
text = "PanU"

[node name="BtnPanD" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 55, 0 )
theme = ExtResource( 3 )
text = "PanD"

[node name="BtnReset" type="Button" parent="Panel/VBoxContainer/HeaderRow"]
rect_min_size = Vector2( 70, 0 )
theme = ExtResource( 3 )
text = "Reset"

[node name="BtnClose" parent="Panel/VBoxContainer/HeaderRow" instance=ExtResource( 4 )]

[node name="MapArea" type="Control" parent="Panel/VBoxContainer"]
size_flags_vertical = 3
size_flags_stretch_ratio = 1.0

[node name="ViewportContainer" type="ViewportContainer" parent="Panel/VBoxContainer/MapArea"]
anchor_right = 1.0
anchor_bottom = 1.0
stretch = true

[node name="Viewport" type="Viewport" parent="Panel/VBoxContainer/MapArea/ViewportContainer"]
size = Vector2( 800, 600 )
render_target_update_mode = 3

[node name="MapCamera" type="Camera" parent="Panel/VBoxContainer/MapArea/ViewportContainer/Viewport"]
transform = Transform( 1, 0, 0, 0, 0.866025, 0.5, 0, -0.5, 0.866025, 0, 100000, 200000 )
fov = 60.0
near = 1.0
far = 1000000.0

[node name="MapContent" type="Spatial" parent="Panel/VBoxContainer/MapArea/ViewportContainer/Viewport"]

[node name="LabelOverlay" type="Control" parent="Panel/VBoxContainer/MapArea"]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

--- Start of ./src/tests/helpers/mock_agent.tscn ---

[gd_scene load_steps=2 format=2]

[ext_resource path="res://src/tests/helpers/mock_agent_body.gd" type="Script" id=1]

[node name="MockAgent" type="Spatial"]

[node name="AgentBody" type="RigidBody" parent="."]
script = ExtResource( 1 )
gravity_scale = 0.0
