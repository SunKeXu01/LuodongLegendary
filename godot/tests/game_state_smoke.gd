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

	GameState.begin_silent_temple()
	_expect(GameState.dungeon_state == "infiltrate", "完成序章后应能进入寂音禅院")
	GameState.mark_temple_guards_cleared()
	_expect(GameState.dungeon_state == "mechanism_available", "清除守卫后应开放机关目标")
	GameState.disable_temple_traps()
	_expect(GameState.dungeon_state == "rescue", "关闭总闸后应进入营救阶段")
	GameState.rescue_temple_prisoner()
	_expect(GameState.dungeon_state == "boss", "营救商客后应触发首领战")
	GameState.mark_temple_boss_defeated()
	_expect(GameState.dungeon_state == "ending", "击败院主后应进入结局选择")
	GameState.finish_silent_temple("justice")
	_expect(GameState.dungeon_state == "completed", "选择处置方案后副本应完成")
	_expect(GameState.dungeon_ending == "justice", "副本应记录罪证交官结局")
	_expect(GameState.silver == 175, "主线和副本应累计获得碎银 175 两")
	_expect(GameState.cloud_ford_reputation == 6, "公断结局应额外增加 3 点声望")
	_expect(GameState.equipment["accessory"] == "silent_temple_manual", "机关谱应自动装备")
	_expect(GameState.get_attack() == 32, "副本装备完成后攻击应为 32")
	_expect(GameState.get_defense() == 13, "副本装备完成后防御应为 13")

	var test_save_path := "user://automated_state_test.json"
	var snapshot := {
		"current_zone": "silent_temple",
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
	_expect(GameState.cloud_ford_reputation == 6, "读取存档后声望应恢复")
	_expect(GameState.dungeon_state == "completed", "读取存档后副本状态应恢复")
	_expect(GameState.dungeon_ending == "justice", "读取存档后副本结局应恢复")
	_expect(GameState.player_level == 9, "读取存档后境界应恢复")
	_expect(GameState.player_max_health == 112, "读取存档后气血上限应恢复")
	_expect(GameState.silver == 175, "读取存档后碎银应恢复")
	_expect(restored.get("loot", []).size() == 1, "读取存档后地面掉落应恢复")
	_expect(restored.get("current_zone", "") == "silent_temple", "读取后所在区域应恢复")
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
	for enemy in followup_enemies:
		enemy.queue_free()
	followup_enemies.clear()
	GameState.mark_quest_ready()
	GameState.finish_quest()
	main_scene.call("_enter_silent_temple")
	_expect(main_scene.get("current_zone") == "silent_temple", "完成序章后应切换到禅院地图")
	var temple_world = main_scene.get("world")
	_expect(temple_world is SilentTempleWorld3D, "副本应使用独立的寂音禅院世界")
	var temple_enemies: Array = main_scene.get("enemies")
	_expect(temple_enemies.size() == 2, "初次进入禅院应生成两名巡夜守卫")
	_expect(is_instance_valid(temple_world.mechanism_marker), "禅院地图应包含可交互机关总闸")
	var dungeon_player = main_scene.get("player")
	var health_before_trap := GameState.player_health
	dungeon_player.global_position = Vector3(-2.0, 0.0, 1.3)
	main_scene.call("_update_dungeon_hazards")
	_expect(GameState.player_health == health_before_trap - 10, "踩中禅院踏板应损失 10 点气血")
	for enemy in temple_enemies:
		enemy.queue_free()
	temple_enemies.clear()
	GameState.mark_temple_guards_cleared()
	GameState.disable_temple_traps()
	main_scene.call("_rescue_temple_prisoner")
	var boss_wave: Array = main_scene.get("enemies")
	_expect(boss_wave.size() == 3, "营救商客后应生成院主与两名护院武僧")
	if not boss_wave.is_empty():
		_expect(boss_wave[0].display_name == "寂音院主·法砚", "首领波次应包含寂音院主")
	boss_wave.clear()
	main_scene.queue_free()
	AudioManager.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))

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
