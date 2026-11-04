# GUT pre-run hook: tests save into their own folder, so a test can never touch real saves
# (permadeath deletes every save slot when the player's ship is lost), and write no evolution life
# logs (each run would leave one in user://evolution_logs/).

extends GutHookScript


func run() -> void:
	GameStateManager.save_dir = "user://test_savegames/"
	Evolution.log_lives = false
	Evolution.frozen = false  # The tests exercise evolving; frozen worlds have their own
