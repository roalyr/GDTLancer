#
# PROJECT: GDTLancer
# MODULE: test_tool_controller.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-05-23 15:24:18
#

extends GutTest

const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")


class AgentBodyHarness:
	extends RigidBody
	var agent_uid = 0
	var character_uid = -1


func test_fire_at_target_returns_explicit_combat_unavailable_boundary() -> void:
	var harness = _create_tool_controller_harness(17)
	var result: Dictionary = harness["controller"].fire_at_target(0, 99, Vector3(1, 2, 3))

	assert_false(result.get("success", true), "Deferred combat fire attempts should fail explicitly instead of pretending to succeed.")
	assert_eq(result.get("reason", ""), "combat_unavailable", "Deferred combat fire attempts should report the canonical combat-unavailable reason.")
	assert_true(
		str(result.get("message", "")).find("Combat actions are unavailable while the combat layer is rebuilt.") != -1,
		"Deferred combat fire attempts should explain why combat is unavailable."
	)
	assert_true(harness["controller"]._deferred_combatant_uids.has(17), "Attacker uid should be tracked at the deferred combat boundary.")
	assert_true(harness["controller"]._deferred_combatant_uids.has(99), "Target uid should be tracked at the deferred combat boundary.")


func test_ensure_combatant_registered_ignores_invalid_uid() -> void:
	var harness = _create_tool_controller_harness(17)
	harness["controller"]._ensure_combatant_registered(-1)

	assert_false(harness["controller"]._deferred_combatant_uids.has(-1), "Invalid combatant ids should be ignored by the deferred combat boundary.")


func _create_tool_controller_harness(agent_uid: int) -> Dictionary:
	var agent_body = AgentBodyHarness.new()
	agent_body.agent_uid = agent_uid
	add_child_autofree(agent_body)

	var controller = ToolControllerScript.new()
	agent_body.add_child(controller)
	controller._agent_body = agent_body

	return {
		"agent_body": agent_body,
		"controller": controller,
	}