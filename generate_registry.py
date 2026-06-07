import os

registry_path = '/home/roalyr/Software_archive/Games/GDTLancer/database/registry/locations'

sectors = {
    'sector_system_elace': {
        'name': 'Elace System',
        'type': 'star',
        'dev': 'hub',
        'scene': 'res://scenes/levels/sectors/sector_system_elace/sector_system_elace.tscn',
        'pos': 'Vector3( 150000, 0, 0 )',
        'connections': 'PoolStringArray( "sector_planet_elace_a", "sector_planet_elace_b", "sector_planet_elace_c" )',
        'tags': 'PoolStringArray( "STATION", "SECURE", "MILD", "RAW_RICH" )'
    },
    'sector_planet_elace_a': {
        'name': 'Elace Planet A',
        'type': 'planet',
        'dev': 'colony',
        'scene': 'res://scenes/levels/sectors/sector_system_elace/sector_planet_elace_a.tscn',
        'pos': 'Vector3( 225000, 0, 0 )',
        'connections': 'PoolStringArray( "sector_system_elace", "sector_moon_elace_a1", "sector_moon_elace_a2" )',
        'tags': 'PoolStringArray( "STATION", "SECURE", "MILD", "MANUFACTURED_RICH" )'
    },
    'sector_planet_elace_b': {
        'name': 'Elace Planet B',
        'type': 'planet',
        'dev': 'outpost',
        'scene': 'res://scenes/levels/sectors/sector_system_elace/sector_planet_elace_b.tscn',
        'pos': 'Vector3( 75000, 50000, 0 )',
        'connections': 'PoolStringArray( "sector_system_elace" )',
        'tags': 'PoolStringArray( "STATION", "CONTESTED", "HARSH", "RAW_ADEQUATE" )'
    },
    'sector_planet_elace_c': {
        'name': 'Elace Planet C',
        'type': 'planet',
        'dev': 'frontier',
        'scene': 'res://scenes/levels/sectors/sector_system_elace/sector_planet_elace_c.tscn',
        'pos': 'Vector3( 100000, -75000, 0 )',
        'connections': 'PoolStringArray( "sector_system_elace", "sector_moon_elace_c1" )',
        'tags': 'PoolStringArray( "STATION", "LAWLESS", "EXTREME", "RAW_POOR" )'
    },
    'sector_moon_elace_a1': {
        'name': 'Elace Moon A1',
        'type': 'moon',
        'dev': 'outpost',
        'scene': 'res://scenes/levels/sectors/sector_system_elace/sector_moon_elace_a1.tscn',
        'pos': 'Vector3( 233000, 0, 0 )',
        'connections': 'PoolStringArray( "sector_planet_elace_a" )',
        'tags': 'PoolStringArray( "STATION", "SECURE", "HARSH", "RAW_RICH" )'
    },
    'sector_moon_elace_a2': {
        'name': 'Elace Moon A2',
        'type': 'moon',
        'dev': 'frontier',
        'scene': 'res://scenes/levels/sectors/sector_system_elace/sector_moon_elace_a2.tscn',
        'pos': 'Vector3( 217000, 5000, 0 )',
        'connections': 'PoolStringArray( "sector_planet_elace_a" )',
        'tags': 'PoolStringArray( "STATION", "CONTESTED", "EXTREME", "RAW_ADEQUATE" )'
    },
    'sector_moon_elace_c1': {
        'name': 'Elace Moon C1',
        'type': 'moon',
        'dev': 'frontier',
        'scene': 'res://scenes/levels/sectors/sector_system_elace/sector_moon_elace_c1.tscn',
        'pos': 'Vector3( 92000, -80000, 0 )',
        'connections': 'PoolStringArray( "sector_planet_elace_c" )',
        'tags': 'PoolStringArray( "STATION", "LAWLESS", "EXTREME", "RAW_POOR" )'
    }
}

template = """[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://database/definitions/location_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "{id}"
location_name = "{name}"
position_in_zone = Vector3( 0, 0, 0 )
interaction_radius = 0.0
sector_scene_path = "{scene}"
global_position = {pos}
is_procedural = false
procedural_type = "deep_space"
procedural_hints = {{
}}
sector_description = ""
connections = {connections}
sector_type = "{type}"
development_level = "{dev}"
radiation_level = 0.05
thermal_background_k = 280.0
gravity_well_penalty = 1.2
mineral_density = 2.0
propellant_sources = 0.3
station_power_output = 150.0
stockpile_capacity = 1500
market_inventory = {{
"commodity_contraband": {{
"buy_price": 80,
"quantity": 15,
"sell_price": 65
}},
"commodity_food": {{
"buy_price": 30,
"quantity": 40,
"sell_price": 25
}},
"commodity_fuel": {{
"buy_price": 25,
"quantity": 100,
"sell_price": 20
}},
"commodity_ore": {{
"buy_price": 8,
"quantity": 200,
"sell_price": 6
}}
}}
available_services = [ "trade", "contracts", "repair", "black_market" ]
controlling_faction_id = "faction_miners"
danger_level = 1
initial_sector_tags = {tags}
available_contract_ids = [ "delivery_01", "delivery_02" ]
"""

for sector_id, data in sectors.items():
    content = template.format(
        id=sector_id,
        name=data['name'],
        scene=data['scene'],
        pos=data['pos'],
        connections=data['connections'],
        type=data['type'],
        dev=data['dev'],
        tags=data['tags']
    )
    with open(os.path.join(registry_path, f'{sector_id}.tres'), 'w') as f:
        f.write(content)

print("Created registry files.")
