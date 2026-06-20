# PROJECT: GDTLancer
# MODULE: asset_module_template.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

# File: core/resource/module_template.gd
# Purpose: Defines equipment.
# Version: 1.0

extends AssetTemplate
class_name ModuleTemplate

export var module_name: String = "Unnamed Module"
export var base_value: int = 10 # Base value in WP for one unit