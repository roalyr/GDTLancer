# File: core/resource/asset_template.gd
# Purpose: Defines a asset-wide fields.
# Is not meant to be standalone, acts as a base for differnt asset types.
# Version: 1.0

extends Template
class_name AssetTemplate

export var asset_type: String = "asset_type" # For categorization
export var asset_icon_id: String = "asset_default"
