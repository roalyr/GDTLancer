# PROJECT: GDTLancer
# MODULE: asset_template.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

# File: core/resource/asset_template.gd
# Purpose: Defines a asset-wide fields.
# Is not meant to be standalone, acts as a base for differnt asset types.
# Version: 1.0

extends Template
class_name AssetTemplate

export var asset_type: String = "asset_type" # For categorization
export var asset_icon_id: String = "asset_default"