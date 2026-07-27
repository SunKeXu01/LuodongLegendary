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

	GameState.choose_quest_route("investigate")
	_expect(GameState.quest_state == "accepted", "任务应进入已接受状态")
	_expect(GameState.quest_route == "investigate", "应记录追查证据路线")
	GameState.mark_quest_ready()
	_expect(GameState.quest_state == "ready", "清剿后任务应进入可交付状态")
	_expect(GameState.evidence_count == 3, "追查路线应获得三枚涉案铜签")
	GameState.finish_first_quest()
	_expect(GameState.quest_state == "followup_available", "首次交付后应解锁追兵任务")
	_expect(GameState.silver == 25, "首次交付应奖励碎银 25 两")
	_expect(GameState.get_item_count("cold_iron") == 2, "追查路线应奖励两份寒铁")
	_expect(GameState.get_item_count("qingming_charm") == 1, "首次交付应奖励青冥玉符")

	GameState.equip_item("qingming_charm")
	_expect(GameState.get_attack() == 24, "装备玉符后攻击应为 24")
	_expect(GameState.get_defense() == 10, "装备玉符后防御应为 10")
	GameState.accept_followup()
	_expect(GameState.quest_state == "second_accepted", "应能接受寒岭追兵任务")
	GameState.mark_quest_ready()
	_expect(GameState.quest_state == "second_ready", "击退追兵后应进入最终交付状态")
	GameState.finish_quest()
	_expect(GameState.quest_state == "completed", "交付后任务应完成")
	_expect(GameState.silver == 75, "两段任务应累计奖励碎银 75 两")
	_expect(GameState.player_level == 9, "完成序章后应提升至第 9 境")
	_expect(GameState.player_experience == 11, "升级后应保留 11 点经验")
	_expect(GameState.player_max_health == 112, "升级后气血上限应提升")
	_expect(GameState.equipment["weapon"] == "hanling_blade", "新兵器应自动装备")
	_expect(GameState.get_attack() == 31, "升级并装备雁翎刀后攻击应为 31")
	_expect(GameState.cloud_ford_reputation == 3, "追查路线完成序章应获得 3 点声望")

	var test_save_path := "user://automated_state_test.json"
	var snapshot := {
		"player_position": [1.0, 0.0, 2.0],
		"enemies": [],
		"loot": [{"item_id": "cold_iron", "amount": 1, "position": [2.0, 0.0, 3.0]}],
		"world_time": 0.72,
	}
	_expect(GameState.save_game(snapshot, test_save_path), "游戏状态应能写入存档")
	GameState.reset()
	var restored := GameState.load_game(test_save_path)
	_expect(GameState.quest_state == "completed", "读取存档后任务状态应恢复")
	_expect(GameState.quest_route == "investigate", "读取存档后路线选择应恢复")
	_expect(GameState.cloud_ford_reputation == 3, "读取存档后声望应恢复")
	_expect(GameState.player_level == 9, "读取存档后境界应恢复")
	_expect(GameState.player_max_health == 112, "读取存档后气血上限应恢复")
	_expect(GameState.silver == 75, "读取存档后碎银应恢复")
	_expect(restored.get("loot", []).size() == 1, "读取存档后地面掉落应恢复")
	_expect(is_equal_approx(float(restored.get("world_time", 0.0)), 0.72), "读取存档后时辰应恢复")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))

	GameState.reset()
	GameState.choose_quest_route("protect")
	GameState.mark_quest_ready()
	GameState.finish_first_quest()
	_expect(GameState.cloud_ford_reputation == 2, "护民路线首次交付应获得 2 点声望")
	_expect(GameState.get_item_count("healing_salve") == 4, "护民路线应额外奖励两份金疮药")

	var main_scene = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)
	var initial_enemies: Array = main_scene.get("enemies")
	for enemy in initial_enemies:
		enemy.queue_free()
	initial_enemies.clear()
	GameState.choose_quest_route("protect")
	GameState.mark_quest_ready()
	GameState.finish_first_quest()
	GameState.accept_followup()
	main_scene.call("_spawn_enemy_wave", main_scene.call("_followup_enemy_specs"))
	var followup_enemies: Array = main_scene.get("enemies")
	_expect(followup_enemies.size() == 2, "后续任务应动态生成两名寒岭追兵")
	if followup_enemies.size() == 2:
		_expect(followup_enemies[0].display_name == "寒岭追骑", "第一名追兵配置应正确")
		_expect(followup_enemies[1].display_name == "武氏刀客", "第二名追兵配置应正确")
	main_scene.queue_free()
	await get_tree().process_frame

	var test_settings_path := "user://automated_settings_test.json"
	GameState.master_volume = 0.4
	GameState.fullscreen = true
	_expect(GameState.save_settings(test_settings_path), "设置应能写入文件")
	GameState.master_volume = 1.0
	GameState.fullscreen = false
	GameState.load_settings(test_settings_path)
	_expect(is_equal_approx(GameState.master_volume, 0.4), "读取后音量应恢复")
	_expect(GameState.fullscreen, "读取后全屏设置应恢复")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_settings_path))

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
