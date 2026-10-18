# GUT pre-run hook: tests save into their own folder, so a test can never touch real saves
# (permadeath deletes every save slot when the player's ship is lost).

extends GutHookScript


func run() -> void:
	GameStateManager.save_dir = "user://test_savegames/"
