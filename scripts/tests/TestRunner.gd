extends Node

var tests_passed: int = 0
var tests_failed: int = 0
var failures: Array = []

func _ready() -> void:
	print("\n========================================================")
	print("🚀 [TEST RUNNER] 开始全系统自动化回归与深度压力测试")
	print("========================================================\n")

	test_suite_1_data_integrity()
	test_suite_2_gamestate_logic()
	test_suite_3_meta_and_settings()
	test_suite_4_garage_ui()
	test_suite_5_main_screen_navigation()
	test_suite_6_combat_simulation()
	test_suite_7_super_weapons_and_drops()
	test_suite_8_all_wanted_bosses()
	test_suite_9_swarm_and_crush_mechanics()

	print("\n========================================================")
	print("📊 [TEST RESULTS] 测试统计汇总:")
	print("   ✅ 通过测试数: %d" % tests_passed)
	print("   ❌ 失败测试数: %d" % tests_failed)
	if tests_failed > 0:
		print("\n❌ 失败项列表:")
		for f in failures:
			print("   - %s" % f)
		print("========================================================\n")
		get_tree().quit(1)
	else:
		print("🎉 全部测试 100% 通过！游戏系统与数据逻辑无异常！")
		print("========================================================\n")
		get_tree().quit(0)

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		tests_passed += 1
		print("  ✅ [PASS] " + test_name)
	else:
		tests_failed += 1
		failures.append(test_name)
		print("  ❌ [FAIL] " + test_name)

# ============================================================================
# 1. 数据完整性与资源关联测试
# ============================================================================
func test_suite_1_data_integrity() -> void:
	print("--- [Suite 1] 数据完整性与资源关联检查 ---")

	# 1.1 猎人数据校验
	assert_true(GameData.HUNTERS.size() == 6, "猎人数量应为 6")
	for h_id in GameData.HUNTERS.keys():
		var h: Dictionary = GameData.HUNTERS[h_id]
		var valid: bool = h.has("id") and h.has("name") and h.has("char_name") and h.has("title") and h.has("quote") and h.has("bio") and h.has("trait_tags")
		assert_true(valid, "猎人数据字段完整: %s" % h_id)
		var p_tex: Texture2D = GameData.get_hunter_portrait_tex(h_id)
		assert_true(p_tex != null, "猎人专属独立立绘加载正常: %s" % h_id)
		var icon_tex: Texture2D = GameData.get_hunter_tex(h_id)
		assert_true(icon_tex != null, "猎人头像图标加载正常: %s" % h_id)

	# 1.2 战车底盘校验
	assert_true(GameData.CHASSIS.size() == 8, "战车底盘数量应为 8")
	for c_id in GameData.CHASSIS.keys():
		var ch: Dictionary = GameData.CHASSIS[c_id]
		var valid: bool = ch.has("id") and ch.has("name") and ch.has("slots") and ch.has("base_weight") and ch.has("sp_per_ton") and ch.has("speed")
		assert_true(valid, "战车底盘字段完整: %s" % c_id)
		var c_tex: Texture2D = GameData.get_chassis_tex(c_id)
		assert_true(c_tex != null, "战车底盘美术素材加载正常: %s" % c_id)

		for w_id in ch.get("starter_weapons", []):
			assert_true(GameData.WEAPONS.has(w_id), "战车初始武器存在于武器库: %s -> %s" % [c_id, w_id])

		var eng_id: String = ch.get("starter_engine", "")
		assert_true(GameData.ENGINES.has(eng_id), "战车初始引擎存在于引擎库: %s -> %s" % [c_id, eng_id])

		var cu_id: String = ch.get("starter_c_unit", "")
		assert_true(GameData.C_UNITS.has(cu_id), "战车初始C装置存在于核心库: %s -> %s" % [c_id, cu_id])

	# 1.3 武器库与超武配方校验
	assert_true(GameData.WEAPONS.size() >= 15, "武器库武器总数充足 (当前 %d)" % GameData.WEAPONS.size())
	for w_id in GameData.WEAPONS.keys():
		var w: Dictionary = GameData.WEAPONS[w_id]
		var valid: bool = w.has("id") and w.has("name") and w.has("slot") and w.has("base_dmg") and w.has("weight")
		assert_true(valid, "武器字段完整: %s (%s)" % [w_id, w.get("name", "")])

	assert_true(GameData.SUPER_EVOLUTIONS.size() >= 5, "超武合成配方数量 >= 5")
	for evo in GameData.SUPER_EVOLUTIONS:
		var res_id: String = evo["result"]
		assert_true(GameData.WEAPONS.has(res_id), "超武合成目标武器在武器库中存在: %s" % res_id)
		for ca in evo["comp_a"]:
			assert_true(GameData.WEAPONS.has(ca), "合成配件A存在: %s" % ca)
		for cb in evo["comp_b"]:
			assert_true(GameData.WEAPONS.has(cb), "合成配件B存在: %s" % cb)

	# 1.4 赏金首与战区生态校验
	assert_true(GameData.WANTED_BOSSES.size() == 10, "赏金首总数为 10 名")
	for b in GameData.WANTED_BOSSES:
		assert_true(b.has("id") and b.has("name") and b.has("hp") and b.has("bounty"), "赏金首信息完整: %s" % b["id"])
		var rw: String = b.get("reward_weapon", "")
		assert_true(GameData.WEAPONS.has(rw), "赏金首击杀掉落红武存在: %s -> %s" % [b["id"], rw])
		var b_tex: Texture2D = GameData.get_boss_tex(b["id"])
		assert_true(b_tex != null, "赏金首贴图正常加载: %s" % b["id"])

	assert_true(GameData.MAPS.size() == 5, "战区地图章节总数为 5 大章")
	for m in GameData.MAPS:
		for e_id in m["enemy_pool"]:
			assert_true(GameData.ENEMIES.has(e_id), "地图小怪生态存在: %s -> %s" % [m["id"], e_id])
		for el_id in m["elite_pool"]:
			assert_true(GameData.ENEMIES.has(el_id), "地图精英生态存在: %s -> %s" % [m["id"], el_id])
		assert_true(GameData.get_boss_by_id(m["regional_boss_id"]) != null, "区域Boss存在: %s" % m["regional_boss_id"])
		assert_true(GameData.get_boss_by_id(m["final_boss_id"]) != null, "关底Boss存在: %s" % m["final_boss_id"])
		var m_tex: Texture2D = GameData.get_terrain_tex(m["id"])
		assert_true(m_tex != null, "战区地貌贴图正常加载: %s" % m["id"])

# ============================================================================
# 2. GameState 运行状态与战车数据计算测试
# ============================================================================
func test_suite_2_gamestate_logic() -> void:
	print("\n--- [Suite 2] 核心状态机与战车改装数值计算 ---")

	var sample_pairs: Array = [
		["bounty_hunter", "buggy"],
		["lone_wolf", "r_wolf"],
		["mechanic", "mammoth"],
		["iron_fist", "ambulance"],
		["pochi", "bus"],
		["mince_aide", "missile_carrier"]
	]

	for pair in sample_pairs:
		var h_id: String = pair[0]
		var c_id: String = pair[1]
		GameState.start_new_run(h_id, c_id, 0, "normal")

		assert_true(GameState.selected_hunter_id == h_id, "开局猎人匹配: %s" % h_id)
		assert_true(GameState.selected_chassis_id == c_id, "开局底盘匹配: %s" % c_id)
		assert_true(GameState.equipped_weapons.size() > 0, "战车装配初始武器数量 > 0")
		assert_true(GameState.max_sp > 50.0, "战车SP最大值计算正常 (>50SP): 当前 %.1f" % GameState.max_sp)
		assert_true(GameState.max_weight > 10.0, "底盘最大载重正常: %.1f 吨" % GameState.max_weight)
		assert_true(GameState.used_weight <= GameState.max_weight, "初始配置未超重: 已用 %.1f / 上限 %.1f" % [GameState.used_weight, GameState.max_weight])

	# 测试武器购买、升星合成
	GameState.start_new_run("lone_wolf", "r_wolf", 0, "normal")
	GameState.add_gold(1000)

	var res1: Dictionary = GameState.add_weapon_to_first_valid_slot("cannon_105mm", 0)
	assert_true(res1.get("equipped", false) or res1.get("merged", false), "武器装配成功")

	for i in range(4):
		GameState.add_weapon_to_first_valid_slot("cannon_105mm", 0)
	var w_105: Dictionary = {}
	for w in GameState.equipped_weapons:
		if w["id"] == "cannon_105mm":
			w_105 = w
			break
	assert_true(not w_105.is_empty(), "找到已装配的 105mm 皇家加农")
	assert_true(w_105.get("rarity", 0) >= 1, "武器成功升级星级: 当前 ★%d" % (w_105.get("rarity", 0) + 1))

	# 测试槽位改装改孔
	var slots_count: int = GameState.chassis_slots.size()
	assert_true(slots_count > 0, "战车槽位配置有效 (共 %d 个)" % slots_count)
	var cur_type: String = GameState.chassis_slots[0]
	var ok_mod: bool = GameState.cycle_chassis_slot_type(0)
	assert_true(ok_mod, "战车底盘改孔执行成功")
	assert_true(GameState.chassis_slots[0] != cur_type, "槽位类型已成功循环切换")

	# 测试羁绊激活字典统计
	assert_true(GameState.synergy_counts is Dictionary, "羁绊系统统计正常存在")

# ============================================================================
# 3. 局外养成系统、原核晶片与设置持久化测试
# ============================================================================
func test_suite_3_meta_and_settings() -> void:
	print("\n--- [Suite 3] 局外养成科技树与存档测试 ---")

	GameState.reset_meta_save()
	GameState.noah_chips = 5000

	# 猎人与底盘解锁
	assert_true(GameState.is_hunter_unlocked("bounty_hunter"), "初始猎人默认解锁: bounty_hunter")
	var ok_unlock_h: bool = GameState.unlock_hunter("lone_wolf")
	assert_true(ok_unlock_h, "成功解锁猎人: lone_wolf")
	assert_true(GameState.is_hunter_unlocked("lone_wolf"), "状态机确认已解锁: lone_wolf")

	var ok_unlock_c: bool = GameState.unlock_chassis("r_wolf")
	assert_true(ok_unlock_c, "成功修复解锁战车底盘: r_wolf")
	assert_true(GameState.is_chassis_unlocked("r_wolf"), "状态机确认已解锁底盘: r_wolf")

	# 局外基础特性解锁
	var ok_feat: bool = GameState.unlock_feature("shop_lock")
	assert_true(ok_feat or GameState.is_feature_unlocked("shop_lock"), "解锁商品锁定器特性成功")

	# 数值科技升级
	var test_stat_id: String = "meta_dmg"
	var prev_lv: int = GameState.get_meta_level(test_stat_id)
	var ok_up: bool = GameState.upgrade_meta_stat(test_stat_id)
	assert_true(ok_up, "科技树升级成功: %s" % test_stat_id)
	assert_true(GameState.get_meta_level(test_stat_id) == prev_lv + 1, "科技树等级提升正确")

	# 存档与读档验证
	GameState.save_meta_data()
	GameState.load_meta_save()
	assert_true(GameState.is_hunter_unlocked("lone_wolf"), "读档后猎人解锁状态保留")
	assert_true(GameState.is_chassis_unlocked("r_wolf"), "读档后战车解锁状态保留")

	# 游戏设置测试
	GameState.set_setting("screen_shake_mult", 0.5)
	assert_true(float(GameState.get_setting("screen_shake_mult")) == 0.5, "设置项读取正常")
	GameState.set_setting("screen_shake_mult", 1.0)

# ============================================================================
# 4. 车库多拉姆商店与交互逻辑测试
# ============================================================================
func test_suite_4_garage_ui() -> void:
	print("\n--- [Suite 4] 车库整备与商店交互逻辑 ---")

	var garage_script: Script = load("res://scripts/ui/GarageUI.gd")
	assert_true(garage_script != null, "成功加载 GarageUI.gd")

	var garage_ui: Control = Control.new()
	garage_ui.set_script(garage_script)
	add_child(garage_ui)

	# 触发车库进入
	GameState.start_new_run("bounty_hunter", "buggy", 0, "normal")
	GameState.add_gold(300)
	garage_ui.open_garage()

	assert_true(garage_ui.shop_items.size() >= 4, "车库商店成功刷新出 4 格以上商品展柜 (当前 %d 格)" % garage_ui.shop_items.size())

	# 测试商品锁定机制
	if garage_ui.shop_items.size() > 0:
		garage_ui.shop_items[0]["locked"] = true
		var locked_id: String = garage_ui.shop_items[0]["id"]
		garage_ui._roll_shop_items()
		assert_true(garage_ui.shop_items[0]["id"] == locked_id, "锁定商品跨刷新保留成功: %s" % locked_id)

	garage_ui.queue_free()

# ============================================================================
# 5. 主菜单与全子界面分级流转测试
# ============================================================================
func test_suite_5_main_screen_navigation() -> void:
	print("\n--- [Suite 5] 主菜单与多全屏子界面流转 ---")

	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	assert_true(main_scene != null, "成功加载 Main.tscn 场景")

	var main_node: Node = main_scene.instantiate()
	add_child(main_node)

	assert_true(main_node.title_screen != null, "主菜单 title_screen 节点存在")
	assert_true(main_node.view_select_hunter != null, "猎人选择子界面节点存在")
	assert_true(main_node.view_select_chassis != null, "战车整备子界面节点存在")
	assert_true(main_node.view_select_map != null, "战区选择子界面节点存在")
	assert_true(main_node.view_meta_lab != null, "科技实验室子界面节点存在")
	assert_true(main_node.view_bounties != null, "赏金首通缉令图鉴节点存在")
	assert_true(main_node.view_settings != null, "设置界面节点存在")

	# 流转到猎人界面
	main_node._switch_to_screen(main_node.ScreenState.SELECT_HUNTER)
	assert_true(main_node.view_select_hunter.visible, "成功流转至猎人选择界面")
	assert_true(main_node.hunter_cards_container.get_child_count() == 6, "猎人名册完整生成 6 张猎人卡")

	# 流转至战车底盘界面
	main_node._switch_to_screen(main_node.ScreenState.SELECT_CHASSIS)
	assert_true(main_node.view_select_chassis.visible, "成功流转至战车整备界面")
	assert_true(main_node.chassis_cards_container.get_child_count() == 8, "底盘网格完整生成 8 台载具卡")

	# 流转至战区章节界面
	main_node._switch_to_screen(main_node.ScreenState.SELECT_MAP)
	assert_true(main_node.view_select_map.visible, "成功流转至战区章节界面")
	assert_true(main_node.maps_cards_container.get_child_count() == 5, "战区列表完整生成 5 大战区卡")

	main_node.queue_free()

# ============================================================================
# 6. 战斗核心循环模拟测试
# ============================================================================
func test_suite_6_combat_simulation() -> void:
	print("\n--- [Suite 6] 战场实体与战斗循环压力模拟 ---")

	var bf_scene: PackedScene = load("res://scenes/Battlefield.tscn")
	assert_true(bf_scene != null, "成功加载 Battlefield.tscn 场景")

	var bf_node: Node2D = bf_scene.instantiate()
	add_child(bf_node)

	GameState.start_new_run("bounty_hunter", "buggy", 0, "normal")
	bf_node.start_wave()

	assert_true(bf_node.wave_active, "波次战斗已成功激活")
	assert_true(bf_node.player_tank != null, "玩家战车成功生成并在场")

	var p_tank = bf_node.player_tank
	assert_true(p_tank.current_sp > 0.0, "战车装甲片SP已充能: %.1f" % p_tank.current_sp)

	# 模拟开火逻辑
	p_tank._process_tank_weapons(0.05, bf_node)
	assert_true(bf_node.projectiles_container != null, "弹幕容器正常运作")

	# 模拟生成敌怪
	bf_node._do_spawn_enemy("bio_ant", Vector2(400, 300))
	assert_true(bf_node.enemies_container.get_child_count() > 0, "成功在战场生成敌怪")
	var enemy_node = bf_node.enemies_container.get_child(0)

	# 模拟敌怪受伤
	var initial_hp: float = enemy_node.hp
	enemy_node.take_damage(20.0, false, "none", enemy_node.global_position)
	assert_true(enemy_node.hp < initial_hp, "敌怪受击扣血结算正常: 原 %.1f -> 现 %.1f" % [initial_hp, enemy_node.hp])

	# 模拟生成赏金首
	bf_node._spawn_wanted_boss("boss_killdozer")
	var has_boss: bool = false
	for e in bf_node.enemies_container.get_children():
		if e.is_boss:
			has_boss = true
			break
	assert_true(has_boss, "赏金首【杀人推土机】成功登场并激活血条")

	# 模拟战车SP受击扣减
	var initial_sp: float = p_tank.current_sp
	p_tank.take_damage(15.0)
	assert_true(p_tank.current_sp < initial_sp, "战车SP成功承受伤害: 原 %.1f -> 现 %.1f" % [initial_sp, p_tank.current_sp])

	# 模拟大破下车逻辑
	p_tank.invuln_timer = 0.0
	p_tank.current_sp = 0.0
	p_tank.take_damage(10.0)
	assert_true(p_tank.is_human_mode, "SP归零后成功紧急脱离战车进入【步兵肉搏状态】")

	# 步兵修复重回战车
	p_tank.human_pos = p_tank.global_position
	p_tank.repair_progress = p_tank.repair_time_needed
	p_tank._process_human_mode(0.1, bf_node, Vector2.ZERO)
	assert_true(not p_tank.is_human_mode, "完成抢修后成功重回战车！")
	assert_true(p_tank.current_sp > 0.0, "重回战车后装甲SP恢复: %.1f" % p_tank.current_sp)

	bf_node.queue_free()

# ============================================================================
# 7. 超武合成体系与战场掉落物吸附测试
# ============================================================================
func test_suite_7_super_weapons_and_drops() -> void:
	print("\n--- [Suite 7] 超武合成体系与战场掉落物 ---")

	GameState.start_new_run("bounty_hunter", "mammoth", 0, "normal")
	GameState.equipped_weapons.clear()

	# 装配两件达到 ★4 (rarity=3) 的合成组件
	GameState.equipped_weapons.append({"id": "cannon_105mm", "rarity": 3})
	GameState.equipped_weapons.append({"id": "mg_vulcan", "rarity": 3})

	var evos: Array = GameState.try_trigger_super_evolutions(false)
	assert_true(evos.size() == 1, "超武合成成功触发: %s" % (evos[0]["evo_name"] if evos.size() > 0 else "无"))
	var has_super: bool = false
	for w in GameState.equipped_weapons:
		if w["id"] == "evo_red_wolf":
			has_super = true
			break
	assert_true(has_super, "神话超武【绯红双星·超重歼灭炮】已装配至战车！")

	# 测试武器出售与赏金折现返还
	var pre_gold: int = GameState.gold
	var sold_val: int = GameState.sell_weapon_at(0)
	assert_true(sold_val > 0, "武器成功出售折算赏金: +%d G" % sold_val)

	# 测试战场掉落物与磁吸
	var drop_scene: PackedScene = load("res://scenes/DropItem.tscn")
	assert_true(drop_scene != null, "成功加载 DropItem.tscn 场景")
	var drop_item = drop_scene.instantiate()
	add_child(drop_item)
	drop_item.setup("scrap", 5, Vector2(100, 100))
	assert_true(drop_item.drop_type == "scrap" and drop_item.value == 5, "掉落物初始化数据正确")
	drop_item.queue_free()

# ============================================================================
# 8. 全部 10 名「赏金首」登场与击杀奖励闭环测试
# ============================================================================
func test_suite_8_all_wanted_bosses() -> void:
	print("\n--- [Suite 8] 全 10 名赏金首召唤与击杀结算循环 ---")

	var bf_scene: PackedScene = load("res://scenes/Battlefield.tscn")
	var bf_node: Node2D = bf_scene.instantiate()
	add_child(bf_node)

	GameState.start_new_run("bounty_hunter", "abrams", 0, "normal")
	bf_node.start_wave()

	for b_def in GameData.WANTED_BOSSES:
		var b_id: String = b_def["id"]
		bf_node._spawn_wanted_boss(b_id)

		var spawned_boss: Node2D = null
		for e in bf_node.enemies_container.get_children():
			if e.enemy_id == b_id:
				spawned_boss = e
				break

		assert_true(spawned_boss != null, "赏金首【%s】在战场成功生成" % b_def["name"])

		# 模拟击杀该赏金首
		var pre_hunted: int = GameState.bounties_hunted
		bf_node.on_wanted_boss_defeated(spawned_boss)
		assert_true(GameState.bounties_hunted == pre_hunted + 1, "赏金首击杀计数自增正确")
		assert_true(b_id in GameState.defeated_wanted_ids, "赏金首已收录至已讨伐通缉档案: %s" % b_id)

		spawned_boss.queue_free()

	bf_node.queue_free()

# ============================================================================
# 9. 狂潮压迫感与战车履带碾压、连击割草测试
# ============================================================================
func test_suite_9_swarm_and_crush_mechanics() -> void:
	print("\n--- [Suite 9] 狂潮合围、履带碾压与连击割草机制测试 ---")

	var bf_scene: PackedScene = load("res://scenes/Battlefield.tscn")
	var bf_node: Node2D = bf_scene.instantiate()
	add_child(bf_node)

	GameState.start_new_run("iron_fist", "mammoth", 0, "normal")
	bf_node.start_wave()

	# 1. 验证敌人容量扩展与狂潮判定
	assert_true(bf_node.current_max_enemies >= 90, "怪物波次动态容量扩展正常 (初始 %d)" % bf_node.current_max_enemies)
	bf_node.is_horde_active = true
	assert_true(bf_node.is_horde_active == true, "机械狂潮暴动状态正常激活")

	# 2. 验证小队与360°环形包围刷怪
	var pre_telegraphs: int = bf_node.spawn_telegraphs.size()
	bf_node._queue_squad_spawn(4)
	assert_true(bf_node.spawn_telegraphs.size() == pre_telegraphs + 4, "战术小队集群冲锋生成队列正常 (+4)")

	bf_node._queue_ring_spawn(8)
	assert_true(bf_node.spawn_telegraphs.size() == pre_telegraphs + 12, "360° 环形铁桶包围圈生成队列正常 (+8)")

	# 3. 验证战车重型物理履带碾压 (Crush)
	var p_tank = bf_node.player_tank
	p_tank.current_sp = 500.0
	p_tank.current_velocity = Vector2(240.0, 0.0) # 高速巡航
	p_tank.invuln_timer = 0.0

	var dummy_enemy := Node2D.new()
	dummy_enemy.set_script(load("res://scripts/combat/Enemy.gd"))
	bf_node.enemies_container.add_child(dummy_enemy)
	dummy_enemy.setup_regular(GameData.ENEMIES["bio_ant"], 1, p_tank.global_position + Vector2(10, 0))
	dummy_enemy.hp = 20.0 # 极低HP轻量小怪

	var sp_before: float = p_tank.current_sp
	p_tank.on_enemy_collision(dummy_enemy, 0.016)

	assert_true(p_tank.current_sp == sp_before, "高速猛犸战车物理碾碎轻甲小怪，战车毫发无损 (0 SP损耗)")
	assert_true(dummy_enemy.hp <= 0.0, "小怪受到重型履带吨位直接碾碎致死")

	# 4. 验证狂飙连击与战术急速增益
	for i in range(35):
		bf_node.on_enemy_killed(dummy_enemy)
	assert_true(bf_node.combo_count >= 35, "连击杀戮计数器累加正常 (当前 %d Combo)" % bf_node.combo_count)
	bf_node._process(0.016)
	assert_true(float(GameState.bonus_stats.get("combo_reload_pct", 0.0)) >= 0.15, "达到 30+ Combo 触发 +15% 极速装填割草增益")

	# 5. 验证波次结束全图战利品全域磁暴吸附
	var drop1 := Node2D.new()
	drop1.set_script(load("res://scripts/combat/DropItem.gd"))
	bf_node.drops_container.add_child(drop1)
	drop1.setup("gold", 50, Vector2(1000, 1000))

	var gold_before: int = GameState.gold
	bf_node._finish_wave_success()
	assert_true(GameState.gold >= gold_before + 50, "波次结束全域磁暴回收全场掉落物，零资源浪费")

	# 6. 验证车库激光打孔与底盘换乘
	GameState.chassis_slots = ["MAIN", "SUB", "SE", "SE"]
	GameState.gold = 500
	var slots_pre: int = GameState.chassis_slots.size()
	var drill_ok: bool = GameState.drill_new_chassis_slot("MAIN")
	assert_true(drill_ok and GameState.chassis_slots.size() == slots_pre + 1, "车库激光打孔扩充槽位成功: 当前 %d 孔" % GameState.chassis_slots.size())

	var switch_ok: bool = GameState.switch_chassis("r_wolf")
	assert_true(switch_ok and GameState.selected_chassis_id == "r_wolf", "车库底盘换乘至【绯红之狼】成功")

	# 7. 验证战时升级EMP冲击波与绝境翻盘注能（仅简单模式生效）
	GameState.selected_difficulty_id = "easy"
	bf_node.start_wave()
	p_tank.current_sp = 20.0 # 濒死
	var test_e1 := Node2D.new()
	test_e1.set_script(load("res://scripts/combat/Enemy.gd"))
	bf_node.enemies_container.add_child(test_e1)
	test_e1.setup_regular(GameData.ENEMIES["bio_ant"], 1, p_tank.global_position + Vector2(50, 0))
	test_e1.stun_timer = 0.0

	bf_node._close_or_next_level_modal()
	assert_true(test_e1.stun_timer >= 1.0, "【简单模式】战时升级关闭触发战地EMP震荡波并眩晕敌怪 (眩晕时长 %.1fs)" % test_e1.stun_timer)

	# 验证在困难模式(normal)下不触发EMP冲击波与绝境翻盘注能
	GameState.selected_difficulty_id = "normal"
	test_e1.global_position = p_tank.global_position + Vector2(50, 0)
	test_e1.stun_timer = 0.0
	bf_node._close_or_next_level_modal()
	assert_true(test_e1.stun_timer == 0.0, "【困难/地狱模式】战时升级严格禁用EMP震荡波，保持硬核废土战斗节奏")

	bf_node.queue_free()
