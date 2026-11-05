# The xenohive's hive (scenes/prefabs/station/xenohive_hive.tscn): a grown XenoForm, Constants
# XENO_HIVE_LENGTH long. Built on creation, so the station that holds it fits to it.

extends "res://src/scenes/game_world/models/station_model.gd"

const XenoForm = preload("res://src/scenes/game_world/models/xeno_form.gd")


func _init() -> void:
	add_child(XenoForm.build(Constants.XENO_FORMS.hive, Constants.XENO_HIVE_LENGTH, Constants.XENO_HIVE_SEED))
