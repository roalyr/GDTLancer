# GUT pre-run hook: tests save into their own folder, so a test can never touch real saves
# (permadeath deletes every save slot when the player's ship is lost), and write no evolution life
# logs (each run would leave one in user://evolution_logs/).

extends GutHookScript

const TEST_SAVE_DIR = "user://test_savegames/"  # Tests that change the folder put it back to this, never to a real one


func run() -> void:
	GameStateManager.save_dir = TEST_SAVE_DIR
	Evolution.log_lives = false
	Evolution.frozen = false  # The tests exercise evolving; frozen worlds have their own
