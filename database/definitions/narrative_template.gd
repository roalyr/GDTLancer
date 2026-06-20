# PROJECT: GDTLancer
# MODULE: narrative_template.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-MASTER-DESIGN-DIRECTIVE.md §2.2, §7.4; TRUTH_GAME-LOOP-VISION.md §5.2
# LOG_REF: 2026-06-20 19:57:00

extends Template
class_name NarrativeTemplate

export var title: String = ""
export var body_text: String = ""
export var creole_dialect: String = ""
