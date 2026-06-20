# PROJECT: GDTLancer
# MODULE: asset_commodity_template.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

# File: core/resource/commodity_template.gd
# Purpose: Defines commodity.
# Version: 1.0

extends AssetTemplate
class_name CommodityTemplate

export var commodity_name: String = "Unnamed Commodity"
export var base_value: int = 10 # Base value in WP for one unit