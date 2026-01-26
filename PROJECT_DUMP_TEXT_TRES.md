--- Start of ./addons/gut/gui/GutSceneTheme.tres ---

[gd_resource type="Theme" load_steps=3 format=2]

[sub_resource type="DynamicFontData" id=9]
font_path = "res://addons/gut/fonts/AnonymousPro-Regular.ttf"

[sub_resource type="DynamicFont" id=10]
size = 14
font_data = SubResource( 9 )

[resource]
default_font = SubResource( 10 )

--- Start of ./assets/art/effects/particle_dust_material.tres ---

[gd_resource type="SpatialMaterial" format=2]

[resource]
flags_transparent = true
flags_unshaded = true
flags_fixed_size = true
vertex_color_use_as_albedo = true
params_billboard_mode = 3
particles_anim_h_frames = 1
particles_anim_v_frames = 1
particles_anim_loop = false

--- Start of ./assets/art/effects/particle_quad.tres ---

[gd_resource type="QuadMesh" load_steps=2 format=2]

[ext_resource path="res://assets/art/effects/particle_dust_material.tres" type="Material" id=1]

[resource]
material = ExtResource( 1 )
size = Vector2( 0.002, 0.002 )

--- Start of ./assets/art/materials/test_solid_frame.tres ---

[gd_resource type="ShaderMaterial" load_steps=2 format=2]

[ext_resource path="res://assets/art/shaders/solid.gdshader" type="Shader" id=1]

[resource]
shader = ExtResource( 1 )
shader_param/paint_color = Color( 1, 1, 1, 1 )
shader_param/light_tint = Color( 1, 0.95, 0.9, 1 )
shader_param/shadow_tint = Color( 0.15, 0.15, 0.25, 1 )
shader_param/shadow_bias = 0.0
shader_param/shadow_softness = 0.1
shader_param/shadow_normal_blend = 0.5
shader_param/spec_tint = Color( 1, 1, 1, 0.5 )
shader_param/spec_intensity = 0.0
shader_param/spec_glossiness = 10.0
shader_param/spec_softness = 0.1
shader_param/rim_color = Color( 0.5, 0.7, 1, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = true
shader_param/detail_paint_scale = 1.0
shader_param/detail_paint_strength = 0.0
shader_param/detail_paint_contrast = 1.0
shader_param/detail_normal_scale = 1.0
shader_param/detail_normal_strength = 1.0
shader_param/uv_triplanar_sharpness = 10.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25

--- Start of ./assets/art/materials/test_solid_glow.tres ---

[gd_resource type="ShaderMaterial" load_steps=2 format=2]

[ext_resource path="res://assets/art/shaders/solid.gdshader" type="Shader" id=1]

[resource]
shader = ExtResource( 1 )
shader_param/paint_color = Color( 1, 1, 1, 1 )
shader_param/light_tint = Color( 1, 0.95, 0.9, 1 )
shader_param/shadow_tint = Color( 0.15, 0.15, 0.25, 1 )
shader_param/shadow_bias = 0.0
shader_param/shadow_softness = 0.1
shader_param/shadow_normal_blend = 0.5
shader_param/spec_tint = Color( 1, 1, 1, 0.5 )
shader_param/spec_intensity = 0.0
shader_param/spec_glossiness = 10.0
shader_param/spec_softness = 0.1
shader_param/rim_color = Color( 0.5, 0.7, 1, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = true
shader_param/detail_paint_scale = 1.0
shader_param/detail_paint_strength = 0.0
shader_param/detail_paint_contrast = 1.0
shader_param/detail_normal_scale = 1.0
shader_param/detail_normal_strength = 1.0
shader_param/uv_triplanar_sharpness = 10.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25

--- Start of ./assets/art/materials/test_solid_panel_2.tres ---

[gd_resource type="ShaderMaterial" load_steps=2 format=2]

[ext_resource path="res://assets/art/shaders/solid.gdshader" type="Shader" id=1]

[resource]
shader = ExtResource( 1 )
shader_param/paint_color = Color( 1, 1, 1, 1 )
shader_param/light_tint = Color( 1, 0.95, 0.9, 1 )
shader_param/shadow_tint = Color( 0.15, 0.15, 0.25, 1 )
shader_param/shadow_bias = 0.0
shader_param/shadow_softness = 0.1
shader_param/shadow_normal_blend = 0.5
shader_param/spec_tint = Color( 1, 1, 1, 0.5 )
shader_param/spec_intensity = 0.0
shader_param/spec_glossiness = 10.0
shader_param/spec_softness = 0.1
shader_param/rim_color = Color( 0.5, 0.7, 1, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = true
shader_param/detail_paint_scale = 1.0
shader_param/detail_paint_strength = 0.0
shader_param/detail_paint_contrast = 1.0
shader_param/detail_normal_scale = 1.0
shader_param/detail_normal_strength = 1.0
shader_param/uv_triplanar_sharpness = 10.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25

--- Start of ./assets/art/materials/test_solid_panel_3.tres ---

[gd_resource type="ShaderMaterial" load_steps=2 format=2]

[ext_resource path="res://assets/art/shaders/solid.gdshader" type="Shader" id=1]

[resource]
shader = ExtResource( 1 )
shader_param/paint_color = Color( 1, 1, 1, 1 )
shader_param/light_tint = Color( 1, 0.95, 0.9, 1 )
shader_param/shadow_tint = Color( 0.15, 0.15, 0.25, 1 )
shader_param/shadow_bias = 0.0
shader_param/shadow_softness = 0.1
shader_param/shadow_normal_blend = 0.5
shader_param/spec_tint = Color( 1, 1, 1, 0.5 )
shader_param/spec_intensity = 0.0
shader_param/spec_glossiness = 10.0
shader_param/spec_softness = 0.1
shader_param/rim_color = Color( 0.5, 0.7, 1, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = true
shader_param/detail_paint_scale = 1.0
shader_param/detail_paint_strength = 0.0
shader_param/detail_paint_contrast = 1.0
shader_param/detail_normal_scale = 1.0
shader_param/detail_normal_strength = 1.0
shader_param/uv_triplanar_sharpness = 10.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25

--- Start of ./assets/art/materials/test_solid_panel.tres ---

[gd_resource type="ShaderMaterial" load_steps=2 format=2]

[ext_resource path="res://assets/art/shaders/solid.gdshader" type="Shader" id=1]

[resource]
shader = ExtResource( 1 )
shader_param/paint_color = Color( 1, 1, 1, 1 )
shader_param/light_tint = Color( 1, 0.95, 0.9, 1 )
shader_param/shadow_tint = Color( 0.15, 0.15, 0.25, 1 )
shader_param/shadow_bias = 0.0
shader_param/shadow_softness = 0.1
shader_param/shadow_normal_blend = 0.5
shader_param/spec_tint = Color( 1, 1, 1, 0.5 )
shader_param/spec_intensity = 0.0
shader_param/spec_glossiness = 10.0
shader_param/spec_softness = 0.1
shader_param/rim_color = Color( 0.5, 0.7, 1, 1 )
shader_param/rim_width = 3.0
shader_param/rim_power = 2.0
shader_param/rim_mask_on_shadow = true
shader_param/detail_paint_scale = 1.0
shader_param/detail_paint_strength = 0.0
shader_param/detail_paint_contrast = 1.0
shader_param/detail_normal_scale = 1.0
shader_param/detail_normal_strength = 1.0
shader_param/uv_triplanar_sharpness = 10.0
shader_param/uv_scale = Vector3( 1, 1, 1 )
shader_param/uv_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 3000.0
shader_param/scale_end_mul = 30.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.25

--- Start of ./assets/art/shaders/simple_solid_glow.tres ---

[gd_resource type="Shader" format=2]

[resource]
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

uniform vec4 color : hint_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float strength : hint_range(0.0, 1e2, 5e-4) = 40;
uniform float exponent = 2;
uniform float exponent_rim = 2;

void fragment()
{
	float dt = clamp(abs(dot(NORMAL,VIEW)), 1e-9, 0.99999);
	float corona = pow(dt, exp(exponent))*pow(1.1,strength);

	ALBEDO = pow(corona,exponent_rim)*color.rgb;
}
"

--- Start of ./assets/themes/main_theme.tres ---

[gd_resource type="Theme" load_steps=11 format=2]

[ext_resource path="res://assets/art/ui/controls/slider_vert.png" type="Texture" id=1]
[ext_resource path="res://assets/art/ui/controls/slider_tick.png" type="Texture" id=2]
[ext_resource path="res://assets/fonts/Roboto_Condensed/static/RobotoCondensed-Regular.ttf" type="DynamicFontData" id=3]

[sub_resource type="DynamicFont" id=2]
size = 22
use_mipmaps = true
use_filter = true
font_data = ExtResource( 3 )

[sub_resource type="StyleBoxFlat" id=8]
bg_color = Color( 0.3, 0.3, 0.35, 1 )
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color( 0.5, 0.5, 0.6, 1 )
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4

[sub_resource type="StyleBoxFlat" id=7]
bg_color = Color( 0.2, 0.2, 0.25, 0.9 )
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color( 0.4, 0.4, 0.5, 1 )
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4

[sub_resource type="DynamicFont" id=1]
size = 18
use_mipmaps = true
use_filter = true
font_data = ExtResource( 3 )

[sub_resource type="StyleBoxFlat" id=4]
bg_color = Color( 0, 0, 0, 0 )

[sub_resource type="StyleBoxFlat" id=5]
bg_color = Color( 0, 0, 0, 0 )

[sub_resource type="StyleBoxFlat" id=6]
border_width_left = 50
border_width_right = 50
border_color = Color( 0, 0, 0, 0 )

[resource]
default_font = SubResource( 2 )
Button/fonts/font = SubResource( 2 )
Button/styles/hover = SubResource( 8 )
Button/styles/normal = SubResource( 7 )
Button/styles/pressed = SubResource( 7 )
HBoxContainer/constants/separation = 40
ItemList/fonts/font = SubResource( 1 )
Label/fonts/font = SubResource( 2 )
RichTextLabel/fonts/normal_font = SubResource( 2 )
TabContainer/fonts/font = SubResource( 2 )
VSlider/icons/grabber = ExtResource( 1 )
VSlider/icons/grabber_disabled = ExtResource( 1 )
VSlider/icons/grabber_highlight = ExtResource( 1 )
VSlider/icons/tick = ExtResource( 2 )
VSlider/styles/grabber_area = SubResource( 4 )
VSlider/styles/grabber_area_highlight = SubResource( 5 )
VSlider/styles/slider = SubResource( 6 )

--- Start of ./database/registry/actions/action_default.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/action_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "action_default"
action_name = "Unnamed Action"
tu_cost = 1
base_attribute = "int"
associated_skill = "computers"

--- Start of ./database/registry/agents/npc_default.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/agent_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "agent_npc_default"
agent_type = "npc"

--- Start of ./database/registry/agents/npc_hostile_default.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/agent_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "agent_npc_hostile_default"
agent_type = "npc"

--- Start of ./database/registry/agents/player_default.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/agent_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "agent_player_default"
agent_type = "player"

--- Start of ./database/registry/assets/commodities/commodity_default.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/asset_commodity_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "commodity_default"
asset_type = "commodity"
asset_icon_id = "asset_default"
commodity_name = "Unnamed Commodity"
base_value = 10

--- Start of ./database/registry/assets/commodities/commodity_food.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/asset_commodity_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "commodity_food"
asset_type = "commodity"
asset_icon_id = "icon_food"
commodity_name = "Food Supplies"
base_value = 20

--- Start of ./database/registry/assets/commodities/commodity_fuel.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/asset_commodity_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "commodity_fuel"
asset_type = "commodity"
asset_icon_id = "icon_fuel"
commodity_name = "Starship Fuel"
base_value = 25

--- Start of ./database/registry/assets/commodities/commodity_luxury.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/asset_commodity_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "commodity_luxury"
asset_type = "commodity"
asset_icon_id = "icon_luxury"
commodity_name = "Luxury Goods"
base_value = 100

--- Start of ./database/registry/assets/commodities/commodity_ore.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/asset_commodity_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "commodity_ore"
asset_type = "commodity"
asset_icon_id = "icon_ore"
commodity_name = "Mineral Ore"
base_value = 10

--- Start of ./database/registry/assets/commodities/commodity_tech.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/asset_commodity_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "commodity_tech"
asset_type = "commodity"
asset_icon_id = "icon_tech"
commodity_name = "Tech Components"
base_value = 60

--- Start of ./database/registry/assets/modules/module_default.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/asset_module_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "module_default"
asset_type = "module"
asset_icon_id = "asset_default"
module_name = "Unnamed Module"
base_value = 10

--- Start of ./database/registry/assets/ships/ship_default.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/asset_ship_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "ship_default"
asset_type = "ship"
asset_icon_id = "asset_default"
ship_model_name = "Default Ship Model"
hull_integrity = 100
armor_integrity = 100
cargo_capacity = 100
interaction_radius = 15.0
ship_quirks = [  ]
ship_upgrades = [  ]
weapon_slots_small = 2
weapon_slots_medium = 0
weapon_slots_large = 0
equipped_weapons = [ "weapon_ablative_laser" ]
power_capacity = 100.0
power_regen = 10.0
mass = 60000.0
linear_thrust = 5e+06
angular_thrust = 5e+06
alignment_threshold_angle_deg = 45.0

--- Start of ./database/registry/assets/ships/ship_hostile_default.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/asset_ship_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "ship_hostile_default"
asset_type = "ship"
asset_icon_id = "asset_default"
ship_model_name = "Hostile Fighter"
hull_integrity = 50
armor_integrity = 25
cargo_capacity = 10
interaction_radius = 15.0
ship_quirks = [  ]
ship_upgrades = [  ]
weapon_slots_small = 2
weapon_slots_medium = 0
weapon_slots_large = 0
equipped_weapons = [ "weapon_ablative_laser" ]
power_capacity = 100.0
power_regen = 10.0
mass = 60000.0
linear_thrust = 5e+06
angular_thrust = 5e+06
alignment_threshold_angle_deg = 45.0

--- Start of ./database/registry/characters/character_default.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/character_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "character_default"
character_name = "Unnamed"
character_icon_id = "character_default_icon"
faction_id = "faction_default"
wealth_points = 10000
focus_points = 0
active_ship_uid = -1
skills = {
"combat": 1,
"piloting": 2,
"trading": 3
}
age = 30
reputation = 0
faction_standings = {
}
character_standings = {
}

--- Start of ./database/registry/contracts/delivery_01.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/contract_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "delivery_01"
template_type = "contract"
contract_type = "delivery"
title = "Ore Shipment to Beta"
description = "The Mining Guild needs 10 units of mineral ore transported to Station Beta. Standard freight rates apply. Payment on delivery."
issuer_id = "mining_guild_rep"
faction_id = "faction_miners"
origin_location_id = "station_alpha"
destination_location_id = "station_beta"
required_commodity_id = "commodity_ore"
required_quantity = 10
target_type = ""
target_count = 0
reward_wp = 80
reward_reputation = 3
reward_items = {}
time_limit_tu = -1
difficulty = 1
accepted_at_tu = -1
progress = {}

--- Start of ./database/registry/contracts/delivery_02.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/contract_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "delivery_02"
template_type = "contract"
contract_type = "delivery"
title = "Food Run to Gamma"
description = "Freeport Gamma is running low on supplies. Deliver 5 units of food supplies from our stores. Bonus for quick delivery."
issuer_id = "station_quartermaster"
faction_id = "faction_independents"
origin_location_id = "station_alpha"
destination_location_id = "station_gamma"
required_commodity_id = "commodity_food"
required_quantity = 5
target_type = ""
target_count = 0
reward_wp = 100
reward_reputation = 2
reward_items = {}
time_limit_tu = -1
difficulty = 1
accepted_at_tu = -1
progress = {}

--- Start of ./database/registry/contracts/delivery_03.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/contract_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "delivery_03"
template_type = "contract"
contract_type = "delivery"
title = "Tech Components to Alpha"
description = "Station Alpha needs tech components for their mining equipment. Transport 8 units of tech components. Guild rates guaranteed."
issuer_id = "tech_merchant"
faction_id = "faction_traders"
origin_location_id = "station_beta"
destination_location_id = "station_alpha"
required_commodity_id = "commodity_tech"
required_quantity = 8
target_type = ""
target_count = 0
reward_wp = 200
reward_reputation = 4
reward_items = {}
time_limit_tu = -1
difficulty = 2
accepted_at_tu = -1
progress = {}

--- Start of ./database/registry/contracts/delivery_04.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/contract_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "delivery_04"
template_type = "contract"
contract_type = "delivery"
title = "Luxury Goods to Gamma"
description = "A wealthy client at Freeport Gamma is expecting a shipment. Deliver 3 units of luxury goods discretely. Premium payment."
issuer_id = "private_broker"
faction_id = "faction_traders"
origin_location_id = "station_beta"
destination_location_id = "station_gamma"
required_commodity_id = "commodity_luxury"
required_quantity = 3
target_type = ""
target_count = 0
reward_wp = 150
reward_reputation = 2
reward_items = {}
time_limit_tu = -1
difficulty = 2
accepted_at_tu = -1
progress = {}

--- Start of ./database/registry/contracts/delivery_05.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/contract_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "delivery_05"
template_type = "contract"
contract_type = "delivery"
title = "Fuel to Beta Station"
description = "Station Beta's fuel reserves are dangerously low. Deliver 15 units of starship fuel urgently. Hazard pay included."
issuer_id = "freeport_admin"
faction_id = "faction_independents"
origin_location_id = "station_gamma"
destination_location_id = "station_beta"
required_commodity_id = "commodity_fuel"
required_quantity = 15
target_type = ""
target_count = 0
reward_wp = 180
reward_reputation = 5
reward_items = {}
time_limit_tu = -1
difficulty = 2
accepted_at_tu = -1
progress = {}

--- Start of ./database/registry/contracts/delivery_06.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/contract_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "delivery_06"
template_type = "contract"
contract_type = "delivery"
title = "Ore to Mining Hub"
description = "The Mining Guild at Alpha is short on refined ore for processing. Deliver 20 units of mineral ore. Bulk contract."
issuer_id = "freeport_broker"
faction_id = "faction_miners"
origin_location_id = "station_gamma"
destination_location_id = "station_alpha"
required_commodity_id = "commodity_ore"
required_quantity = 20
target_type = ""
target_count = 0
reward_wp = 120
reward_reputation = 4
reward_items = {}
time_limit_tu = -1
difficulty = 2
accepted_at_tu = -1
progress = {}

--- Start of ./database/registry/locations/station_alpha.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/location_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "station_alpha"
location_name = "Station Alpha - Mining Hub"
location_type = "station"
position_in_zone = Vector3( 48042, 233, -673 )
interaction_radius = 150.0
market_inventory = {
"commodity_ore": {
"buy_price": 8,
"sell_price": 6,
"quantity": 200
},
"commodity_food": {
"buy_price": 30,
"sell_price": 25,
"quantity": 40
},
"commodity_tech": {
"buy_price": 80,
"sell_price": 65,
"quantity": 15
},
"commodity_fuel": {
"buy_price": 25,
"sell_price": 20,
"quantity": 100
}
}
available_services = [ "trade", "contracts", "repair" ]
controlling_faction_id = "faction_miners"
danger_level = 1
available_contract_ids = [ "delivery_01", "delivery_02" ]

--- Start of ./database/registry/locations/station_beta.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/location_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "station_beta"
location_name = "Station Beta - Trade Post"
location_type = "station"
position_in_zone = Vector3( 49500, 100, 1500 )
interaction_radius = 150.0
market_inventory = {
"commodity_ore": {
"buy_price": 15,
"sell_price": 12,
"quantity": 30
},
"commodity_food": {
"buy_price": 22,
"sell_price": 18,
"quantity": 80
},
"commodity_tech": {
"buy_price": 70,
"sell_price": 55,
"quantity": 50
},
"commodity_fuel": {
"buy_price": 30,
"sell_price": 25,
"quantity": 60
},
"commodity_luxury": {
"buy_price": 90,
"sell_price": 75,
"quantity": 20
}
}
available_services = [ "trade", "contracts" ]
controlling_faction_id = "faction_traders"
danger_level = 2
available_contract_ids = [ "delivery_03", "delivery_04" ]

--- Start of ./database/registry/locations/station_gamma.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/location_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "station_gamma"
location_name = "Freeport Gamma"
location_type = "station"
position_in_zone = Vector3( 46000, -200, 500 )
interaction_radius = 150.0
market_inventory = {
"commodity_ore": {
"buy_price": 12,
"sell_price": 10,
"quantity": 80
},
"commodity_food": {
"buy_price": 25,
"sell_price": 20,
"quantity": 60
},
"commodity_tech": {
"buy_price": 55,
"sell_price": 45,
"quantity": 30
},
"commodity_fuel": {
"buy_price": 20,
"sell_price": 15,
"quantity": 150
},
"commodity_luxury": {
"buy_price": 120,
"sell_price": 100,
"quantity": 10
}
}
available_services = [ "trade", "contracts", "black_market" ]
controlling_faction_id = "faction_independents"
danger_level = 4
available_contract_ids = [ "delivery_05", "delivery_06" ]

--- Start of ./database/registry/quirks/quirk_damaged_sensor_array.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/quirk_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "quirk_damaged_sensor_array"
display_name = "Damaged Sensor Array"
description = "Sensors are miscalibrated or damaged. Scan range and accuracy reduced."
effect_type = "sensor_range_penalty"
effect_value = 0.5
source_category = "combat"

--- Start of ./database/registry/quirks/quirk_hull_stress_fracture.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/quirk_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "quirk_hull_stress_fracture"
display_name = "Hull Stress Fracture"
description = "Micro-fractures in the hull integrity. Maximum hull integrity reduced."
effect_type = "max_hull_reduction"
effect_value = 20.0
source_category = "combat"

--- Start of ./database/registry/quirks/quirk_jammed_landing_gear.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/quirk_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "quirk_jammed_landing_gear"
display_name = "Jammed Landing Gear"
description = "The landing gear deployment mechanism is damaged. Docking maneuvers are riskier."
effect_type = "maneuver_penalty"
effect_value = 0.2
source_category = "piloting"

--- Start of ./database/registry/weapons/weapon_ablative_laser.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/utility_tool_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "weapon_ablative_laser"
tool_name = "Ablative Laser"
description = "A standard mining laser repurposed for combat. Continuous beam gradually ablates hull material."
tool_type = "weapon"
damage = 8.0
range_effective = 80.0
range_max = 120.0
fire_rate = 2.0
projectile_speed = 0.0
accuracy = 0.85
hull_damage_multiplier = 1.0
armor_damage_multiplier = 0.8
energy_per_shot = 8.0
ammo_type = ""
ammo_per_shot = 0
cooldown_time = 0.0
charge_time = 0.0
warmup_time = 0.1
effect_type = ""
effect_strength = 0.0
effect_duration = 0.0
mount_size = "small"
power_draw = 15.0
projectile_scene = ""
muzzle_effect = ""
impact_effect = ""
fire_sound = ""

--- Start of ./database/registry/weapons/weapon_harpoon.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/utility_tool_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "weapon_harpoon"
tool_name = "Tether Harpoon"
description = "Fires a magnetic harpoon that tethers to targets. Useful for salvage operations and immobilizing smaller craft."
tool_type = "grapple"
damage = 5.0
range_effective = 60.0
range_max = 100.0
fire_rate = 0.25
projectile_speed = 150.0
accuracy = 0.75
hull_damage_multiplier = 0.5
armor_damage_multiplier = 0.3
energy_per_shot = 20.0
ammo_type = ""
ammo_per_shot = 0
cooldown_time = 2.0
charge_time = 0.5
warmup_time = 0.0
effect_type = "grapple"
effect_strength = 1.0
effect_duration = 10.0
mount_size = "small"
power_draw = 10.0
projectile_scene = ""
muzzle_effect = ""
impact_effect = ""
fire_sound = ""

--- Start of ./database/registry/weapons/weapon_rotary_drill.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/utility_tool_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "weapon_rotary_drill"
tool_name = "Rotary Drill"
description = "An industrial drill designed for asteroid mining. At close range, it can breach hull plating."
tool_type = "weapon"
damage = 25.0
range_effective = 20.0
range_max = 30.0
fire_rate = 0.5
projectile_speed = 0.0
accuracy = 0.95
hull_damage_multiplier = 1.5
armor_damage_multiplier = 1.2
energy_per_shot = 15.0
ammo_type = ""
ammo_per_shot = 0
cooldown_time = 0.5
charge_time = 0.0
warmup_time = 0.3
effect_type = "breach"
effect_strength = 0.2
effect_duration = 0.0
mount_size = "medium"
power_draw = 25.0
projectile_scene = ""
muzzle_effect = ""
impact_effect = ""
fire_sound = ""

--- Start of ./default_env.tres ---

[gd_resource type="Environment" load_steps=2 format=2]

[sub_resource type="ProceduralSky" id=1]

[resource]
background_sky = SubResource( 1 )

--- Start of ./scenes/levels/zones/zone1/scene_materials/nebula_1_inside.tres ---

[gd_resource type="ShaderMaterial" load_steps=2 format=2]

[ext_resource path="res://assets/art/shaders/cloud_solid_inside.gdshader" type="Shader" id=1]

[resource]
shader = ExtResource( 1 )
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
shader_param/albedo = Color( 1, 1, 1, 1 )
shader_param/albedo_near = Color( 0.117647, 0.101961, 0.160784, 1 )
shader_param/albedo_ambient = Color( 0.145098, 0.12549, 0.196078, 1 )
shader_param/albedo_far = Color( 0.454902, 0.0509804, 0.603922, 1 )
shader_param/fade_distance = 100000.0
shader_param/fade_distance_far = 500000.0
shader_param/fade_power = 2.0
shader_param/rim_exponent = 0.5
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5

--- Start of ./scenes/levels/zones/zone1/scene_materials/nebula_1.tres ---

[gd_resource type="ShaderMaterial" load_steps=5 format=2]

[ext_resource path="res://assets/art/shaders/cloud_solid.gdshader" type="Shader" id=1]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/bw_noise/Manifold 11 - 512x512.png" type="Texture" id=2]
[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Voronoi 8 - 512x512.png" type="Texture" id=3]
[ext_resource path="res://scenes/levels/zones/zone1/scene_materials/nebula_1_inside.tres" type="Material" id=4]

[resource]
next_pass = ExtResource( 4 )
shader = ExtResource( 1 )
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
shader_param/albedo = Color( 0, 0.47451, 0.658824, 1 )
shader_param/albedo_near = Color( 0.117647, 0.101961, 0.160784, 1 )
shader_param/albedo_ambient = Color( 0.145098, 0.12549, 0.196078, 1 )
shader_param/albedo_rim = Color( 0.960784, 0.423529, 0.164706, 1 )
shader_param/normal_intensity = 1.0
shader_param/normal_detail_power = 1.0
shader_param/normal_detail_strength = -0.06
shader_param/rim_strength = 5.39
shader_param/rim_factor = 1.671
shader_param/rim_normal_detail_factor = 1.0
shader_param/rim_exponent = 0.265
shader_param/fade_distance = 100000.0
shader_param/fade_power = 2.0
shader_param/uv1_blend_sharpness = 10.0
shader_param/normal_detail_uv1_scale = -1.519
shader_param/normal_detail_uv1_offset = Vector3( 0, 0, 0 )
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5
shader_param/detail_noise = ExtResource( 2 )
shader_param/normal_noise = ExtResource( 3 )

--- Start of ./scenes/levels/zones/zone1/scene_materials/nebula_transparent_1.tres ---

[gd_resource type="ShaderMaterial" load_steps=3 format=2]

[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Voronoi 8 - 512x512.png" type="Texture" id=1]
[ext_resource path="res://assets/art/shaders/cloud_transparent.gdshader" type="Shader" id=2]

[resource]
shader = ExtResource( 2 )
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
shader_param/albedo = Color( 0.32549, 0.0980392, 0, 1 )
shader_param/albedo_rim = Color( 0, 0.458824, 0.447059, 1 )
shader_param/albedo_ambient = Color( 0, 0, 0, 1 )
shader_param/normal_intensity = -1.0
shader_param/normal_detail_power = 1.2
shader_param/normal_detail_factor = 0.034
shader_param/normal_strength = 1.148
shader_param/normal_detail_clamp = 0.141
shader_param/rim_factor = 1.0
shader_param/rim_strength = 1.0
shader_param/rim_exponent = 5.0
shader_param/fade_distance = 500000.0
shader_param/fade_power = 2.0
shader_param/uv1_blend_sharpness = 10.0
shader_param/normal_detail_uv1_scale = -2.555
shader_param/normal_detail_uv1_offset = Vector3( 1.136, 0.214, -0.719 )
shader_param/scale_start = 100000.0
shader_param/scale_end_mul = 100.0
shader_param/scale_power = 1.0
shader_param/scale_min = 0.5
shader_param/normal_noise = ExtResource( 1 )

--- Start of ./scenes/levels/zones/zone1/scene_materials/star_1_corona.tres ---

[gd_resource type="ShaderMaterial" load_steps=4 format=2]

[ext_resource path="res://assets/art/shaders/star_corona.gdshader" type="Shader" id=1]

[sub_resource type="OpenSimplexNoise" id=23]

[sub_resource type="NoiseTexture" id=24]
width = 256
height = 256
seamless = true
noise = SubResource( 23 )

[resource]
shader = ExtResource( 1 )
shader_param/corona_color = Color( 0.345098, 0.219608, 0.14902, 1 )
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

--- Start of ./scenes/levels/zones/zone1/scene_materials/star_1_sprite.tres ---

[gd_resource type="ShaderMaterial" load_steps=2 format=2]

[ext_resource path="res://assets/art/shaders/star_sprite.gdshader" type="Shader" id=1]

[resource]
shader = ExtResource( 1 )
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

--- Start of ./scenes/levels/zones/zone1/scene_materials/star_1_surface.tres ---

[gd_resource type="ShaderMaterial" load_steps=3 format=2]

[ext_resource path="res://assets/art/textures/sbs-noise_texture_pack-512x512/normal_maps/Craters 14 - 512x512.png" type="Texture" id=1]
[ext_resource path="res://assets/art/shaders/star_surface.gdshader" type="Shader" id=2]

[resource]
shader = ExtResource( 2 )
shader_param/rim_color = Color( 1, 1, 1, 1 )
shader_param/overlay_color = Color( 0.615686, 0.376471, 0.215686, 1 )
shader_param/surface_color = Color( 0.85098, 0.74902, 0.639216, 1 )
shader_param/fade_color = Color( 0.909804, 0.784314, 0.662745, 1 )
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
shader_param/major_detail_noise = ExtResource( 1 )

--- Start of ./tests/data/test_action.tres ---

[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/action_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
action_name = "Unnamed Action"
tu_cost = 1
base_attribute = "INT"
associated_skill = "Computers"
