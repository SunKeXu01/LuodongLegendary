extends Node

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset()
	_expect(GameState.get_item_count("healing_salve") == 2, "初始金疮药数量应为 2")
	_expect(GameState.get_attack() == 22, "装备旧制长剑后攻击应为 22")

	GameState.damage_player(60)
	_expect(GameState.use_item("healing_salve"), "受伤时应能使用金疮药")
	_expect(GameState.player_health == 72, "金疮药应恢复 32 点气血")
	_expect(GameState.get_item_count("healing_salve") == 1, "使用后金疮药应减少 1")

	GameState.add_item("monk_bracer")
	_expect(GameState.equip_item("monk_bracer"), "武僧护腕应能装备")
	_expect(GameState.get_defense() == 8, "装备护腕后防御应为 8")

	GameState.accept_quest()
	_expect(GameState.quest_state == "accepted", "任务应进入已接受状态")
	GameState.mark_quest_ready()
	_expect(GameState.quest_state == "ready", "清剿后任务应进入可交付状态")
	GameState.finish_quest()
	_expect(GameState.quest_state == "completed", "交付后任务应完成")
	_expect(GameState.silver == 50, "任务应奖励碎银 50 两")
	_expect(GameState.get_item_count("qingming_charm") == 1, "任务应奖励青冥玉符")

	GameState.equip_item("qingming_charm")
	_expect(GameState.get_attack() == 24, "装备玉符后攻击应为 24")
	_expect(GameState.get_defense() == 10, "装备玉符后防御应为 10")

	if failures.is_empty():
		print("GAMEPLAY STATE SMOKE TEST PASSED")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("GAMEPLAY TEST: %s" % failure)
	get_tree().quit(1)


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		failures.append(failure)
