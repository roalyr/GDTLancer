# PROJECT: GDTLancer
# MODULE: tight_beam_system.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md
# LOG_REF: 2026-07-26 02:10:00

extends Node
class_name TightBeamSystem

signal message_queued(msg_id, delivery_tick)
signal message_delivered(message_dict)

var pending_messages: Array = []
var inbox: Array = []
var msg_counter: int = 0

func _ready() -> void:
	if EventBus.has_signal("tick_advanced"):
		EventBus.connect("tick_advanced", self, "_on_tick_advanced")

func send_message(sender_npc_id: String, subject: String, body: String, travel_ticks: int = 2, payload: Dictionary = {}, current_tick: int = 0) -> String:
	msg_counter += 1
	var msg_id = "msg_" + str(msg_counter)
	var target_tick = current_tick + max(1, travel_ticks)
	
	var msg_dict = {
		"msg_id": msg_id,
		"sender_npc_id": sender_npc_id,
		"subject": subject,
		"body": body,
		"dispatch_tick": current_tick,
		"delivery_tick": target_tick,
		"payload": payload.duplicate(),
		"read": false
	}
	
	pending_messages.append(msg_dict)
	emit_signal("message_queued", msg_id, target_tick)
	return msg_id

func process_tick(current_tick: int) -> Array:
	var delivered_now: Array = []
	var remaining: Array = []
	
	for msg in pending_messages:
		if current_tick >= int(msg["delivery_tick"]):
			inbox.append(msg)
			delivered_now.append(msg)
			emit_signal("message_delivered", msg)
		else:
			remaining.append(msg)
			
	pending_messages = remaining
	return delivered_now

func _on_tick_advanced(current_tick: int, _delta_ticks: int) -> void:
	process_tick(current_tick)

func get_inbox() -> Array:
	return inbox

func mark_read(msg_id: String) -> void:
	for msg in inbox:
		if msg["msg_id"] == msg_id:
			msg["read"] = true
			break

func clear_all() -> void:
	pending_messages.clear()
	inbox.clear()
	msg_counter = 0
