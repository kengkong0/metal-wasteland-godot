extends Node2D
## 《重装废土：赏金狂飙》 - 玩家战车与猎人步兵双形态控制器
## 实现：主炮/副炮/S-E三层火力、全弹发射、旋转铁球、宙斯盾拦截、战车大破跳车与读条抢修。

var current_sp: float = 800.0
var human_hp: float = 180.0
var is_human_mode: bool = false
var is_voluntary_unboard: bool = false

# --- 移动、转向与物理状态 ---
var chassis_angle: float = 0.0
var turret_angle: float = 0.0
var current_velocity: Vector2 = Vector2.ZERO
var human_pos: Vector2 = Vector2.ZERO
var dodge_roll_timer: float = 0.0
var invuln_timer: float = 0.0
var emp_slow_timer: float = 0.0
var toxic_tick_timer: float = 0.0
var ram_cooldowns: Dictionary = {}

# --- 武器冷却、弹药与C装置状态 ---
var weapon_timers: Array = []
var weapon_ammo: Array = []
var all_out_timer: float = 0.0
var all_out_max_cd: float = 10.0
var intercept_timers: Dictionary = {}
var nitro_boost_timer: float = 0.0
var overclock_timer: float = 0.0
var smoke_evade_timer: float = 0.0
var iron_dome_timer: float = 0.0
var iron_dome_zap_timer: float = 0.0
var orbit_angle: float = 0.0
var repair_progress: float = 0.0
var repair_time_needed: float = 4.5
var human_fire_timer: float = 0.0
var repair_cores_needed: int = 3
var repair_cores_collected: int = 0
var human_burst_timer: float = 0.0
var chassis_special_timer: float = 0.0
var tread_timer: float = 0.0
var turret_kick_dist: float = 0.0 # 主炮/重炮开火后坐力炮管后缩

func init_for_wave(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	human_pos = spawn_pos
	is_human_mode = false
	is_voluntary_unboard = false
	repair_progress = 0.0

	GameState.recalculate_stats()
	current_sp = GameState.max_sp
	human_hp = GameState.max_human_hp
	var base_rep: float = 2.0 if GameState.bonus_stats.get("fast_repair", false) else 4.5
	repair_time_needed = maxf(1.0, base_rep * (1.0 - GameState.get_meta_level("meta_repair") * 0.12))

	var cu: Dictionary = GameData.C_UNITS.get(GameState.equipped_c_unit_id, GameData.C_UNITS["cu_type66"])
	all_out_max_cd = float(cu.get("all_out_cd", 10.0))
	all_out_timer = 0.0
	intercept_timers.clear()
	nitro_boost_timer = 0.0
	overclock_timer = 0.0
	smoke_evade_timer = 0.0
	iron_dome_timer = 0.0
	iron_dome_zap_timer = 0.0

	var ammo_mult: float = 1.0 + GameState.get_meta_level("meta_reload") * 0.15
	sync_weapons_from_state(ammo_mult)

func sync_weapons_from_state(ammo_mult: float = 1.0) -> void:
	weapon_timers.clear()
	weapon_ammo.clear()
	for w in GameState.equipped_weapons:
		weapon_timers.append(randf_range(0.05, 0.25))
		var w_def: Dictionary = GameData.WEAPONS.get(w["id"], {})
		var base_ammo: int = int(w_def.get("ammo", 999))
		weapon_ammo.append(999 if base_ammo > 500 else int(ceil(base_ammo * ammo_mult)))

func apply_emp_slow(duration: float) -> void:
	emp_slow_timer = maxf(emp_slow_timer, duration)
	var bf: Node = get_parent()
	if bf and bf.get("fx_layer"):
		bf.fx_layer.spawn_text(get_active_position(), "⚡ 磁暴电网减速!", Color(0.55, 0.85, 1.0), 1.1)

func get_active_position() -> Vector2:
	return human_pos if is_human_mode else global_position

func heal_sp(amount: float) -> void:
	if is_human_mode and not is_voluntary_unboard:
		human_hp = minf(GameState.max_human_hp, human_hp + amount * 0.35)
	else:
		current_sp = minf(GameState.max_sp, current_sp + amount)

func refill_all_ammo(add_amount: int) -> void:
	for i in range(weapon_ammo.size()):
		var w_id: String = GameState.equipped_weapons[i]["id"]
		var max_a: int = int(GameData.WEAPONS[w_id].get("ammo", 999))
		weapon_ammo[i] = mini(max_a, weapon_ammo[i] + add_amount)

func _process(delta: float) -> void:
	var bf: Node = get_parent()
	if not bf or not bf.wave_active:
		return

	orbit_angle += delta * 3.8
	turret_kick_dist = maxf(0.0, turret_kick_dist - delta * 38.0)
	if invuln_timer > 0.0:
		invuln_timer -= delta
	if dodge_roll_timer > 0.0:
		dodge_roll_timer -= delta
	if emp_slow_timer > 0.0:
		emp_slow_timer -= delta
	if nitro_boost_timer > 0.0:
		nitro_boost_timer -= delta
	if overclock_timer > 0.0:
		overclock_timer -= delta
	if smoke_evade_timer > 0.0:
		smoke_evade_timer -= delta
	if iron_dome_timer > 0.0:
		iron_dome_timer -= delta

	# 检查是否踩在毒气铁桶留下的强酸毒池上
	toxic_tick_timer += delta
	if toxic_tick_timer >= 0.55:
		toxic_tick_timer = 0.0
		for p in bf.fx_layer.puddles:
			if p["type"] == "toxic" and get_active_position().distance_to(p["pos"]) <= p["radius"] + 16.0:
				take_damage(14.0 + GameState.current_wave * 2.0, p["pos"])
				break
	if all_out_timer > 0.0:
		all_out_timer = maxf(0.0, all_out_timer - delta)

	# 清理碰撞冷却表
	for k in ram_cooldowns.keys():
		ram_cooldowns[k] -= delta
		if ram_cooldowns[k] <= 0.0:
			ram_cooldowns.erase(k)

	# 切换主炮自动/手动索敌
	if Input.is_action_just_pressed("toggle_auto_main"):
		GameState.auto_main_cannon = not GameState.auto_main_cannon
		bf.fx_layer.spawn_text(get_active_position(), "主炮模式: %s" % ("自动索敌" if GameState.auto_main_cannon else "鼠标手动"), Color(1.0, 0.9, 0.3), 1.15)

	# [E] 键主动跳车 / 核爆自爆卡车 / 重新登车
	if Input.is_action_just_pressed("eject_tank"):
		_handle_eject_key(bf)

	# 移动控制
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_human_mode:
		_process_human_mode(delta, bf, move_input)
	else:
		_process_tank_mode(delta, bf, move_input)

	# 如果在战车中，或者搭载了【瓦尔基里自律战斗AI】，战车武器持续开火
	var cu: Dictionary = GameData.C_UNITS.get(GameState.equipped_c_unit_id, {})
	if not is_human_mode or cu.get("auto_turret_wreck", false):
		_process_interception_system(delta, bf)
		_process_tank_weapons(delta, bf)

	queue_redraw()

func get_human_effective_weapon_damage() -> float:
	var base_dmg: float = 65.0 + GameState.level * 16.0 + (GameState.max_sp * 0.03)
	var eng: Dictionary = GameData.ENGINES.get(GameState.equipped_engine_id, {})
	var mult: float = 1.0 + float(eng.get("all_dmg_bonus", 0.0)) + float(GameState.bonus_stats.get("weapon_dmg_all_pct", 0.0))
	mult += float(GameState.bonus_stats.get("main_dmg_pct", 0.0)) * 0.5
	var h_dmg_mult: float = float(GameState.bonus_stats.get("human_damage_mult", 1.0))
	return base_dmg * mult * h_dmg_mult

func on_collect_repair_core() -> void:
	if not is_human_mode or is_voluntary_unboard:
		return
	repair_cores_collected += 1
	var bf: Node = get_parent()
	human_hp = minf(GameState.max_human_hp, human_hp + GameState.max_human_hp * 0.30)
	invuln_timer = maxf(invuln_timer, 1.2)
	SoundManager.play("upgrade", 0.05, 1.5)
	if is_instance_valid(bf) and is_instance_valid(bf.fx_layer):
		bf.fx_layer.spawn_text(human_pos, "🔧 应急动力核心就位 (%d/3)!" % repair_cores_collected, Color(0.35, 1.0, 0.65), 1.25)
		bf.fx_layer.spawn_shockwave(human_pos, 85.0, Color(0.3, 1.0, 0.5))
	if repair_cores_collected >= repair_cores_needed:
		reboot_tank(0.50, "⚡ 动力核心全部就位! 战车绝境重装重启! ⚡")

func reboot_tank(sp_ratio: float, msg: String = "⚡ 战车抢修完毕，重返战场! ⚡") -> void:
	is_human_mode = false
	is_voluntary_unboard = false
	current_sp = GameState.max_sp * sp_ratio
	human_hp = GameState.max_human_hp
	invuln_timer = 2.0
	repair_progress = 0.0
	repair_cores_collected = 0
	global_position = human_pos
	chassis_angle = turret_angle
	GameState.report_metric("repair_success_count", 1, true)
	GameState.report_metric("total_repaired_sp", current_sp, true)
	var bf: Node = get_parent()
	if is_instance_valid(bf):
		bf.trigger_screen_shake(14.0, 0.4)
		if is_instance_valid(bf.fx_layer):
			bf.fx_layer.spawn_explosion(global_position, 220.0, Color(0.35, 1.0, 0.75))
			bf.fx_layer.spawn_text(global_position, msg, Color(0.35, 1.0, 0.65), 1.65)
		for e in bf.enemies_container.get_children():
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= 240.0:
				e.take_damage(200.0 + GameState.level * 25.0, true, "electric", global_position, false)
				if not e.is_boss:
					e.global_position += (e.global_position - global_position).normalized() * 120.0
	SoundManager.play("upgrade", 0.05, 3.0)

func _handle_eject_key(bf: Node) -> void:
	if not is_human_mode:
		# 废土武道家：主动引爆战车造成 8倍最大SP 全屏核爆！
		if GameState.bonus_stats.get("self_destruct_nuke", false):
			var nuke_dmg: float = GameState.max_sp * 8.0
			current_sp = 0.0
			is_human_mode = true
			is_voluntary_unboard = false
			human_pos = global_position
			invuln_timer = 1.5
			bf.trigger_screen_shake(18.0, 0.5)
			bf.fx_layer.spawn_explosion(global_position, 360.0, Color(1.0, 0.35, 0.1))
			bf.fx_layer.spawn_text(global_position, "武道家战车自爆核弹!!", Color(1.0, 0.25, 0.2), 1.65)
			SoundManager.play("explosion_large", 0.05, 3.0)
			for e in bf.enemies_container.get_children():
				if is_instance_valid(e):
					e.take_damage(nuke_dmg, true, "cluster", global_position, true)
		else:
			is_human_mode = true
			is_voluntary_unboard = true
			human_pos = global_position + Vector2(36, 0)
			bf.fx_layer.spawn_text(human_pos, "猎人下车作战!", Color(0.4, 0.95, 1.0), 1.15)
	elif is_voluntary_unboard and human_pos.distance_to(global_position) <= 85.0:
		is_human_mode = false
		is_voluntary_unboard = false
		bf.fx_layer.spawn_text(global_position, "重新登车!", Color(0.4, 1.0, 0.5), 1.15)

func _process_tank_mode(delta: float, bf: Node, move_input: Vector2) -> void:
	# SP 自动修复
	if GameState.sp_regen_per_sec > 0.0:
		current_sp = minf(GameState.max_sp, current_sp + GameState.sp_regen_per_sec * delta)

	var combo_spd_boost: float = float(GameState.bonus_stats.get("combo_speed_pct", 0.0)) + (0.42 if nitro_boost_timer > 0.0 else 0.0)
	var eff_spd: float = GameState.move_speed * (0.58 if emp_slow_timer > 0.0 else 1.0) * (1.0 + combo_spd_boost)
	var target_vel: Vector2 = move_input * eff_spd
	current_velocity = current_velocity.lerp(target_vel, 10.0 * delta)
	global_position += current_velocity * delta

	if current_velocity.length() > 15.0:
		chassis_angle = lerp_angle(chassis_angle, current_velocity.angle(), 10.0 * delta)
		tread_timer += delta
		if tread_timer >= 0.07:
			tread_timer = 0.0
			bf.add_tread_mark(global_position, chassis_angle)

	global_position.x = clampf(global_position.x, bf.arena_rect.position.x + 32.0, bf.arena_rect.end.x - 32.0)
	global_position.y = clampf(global_position.y, bf.arena_rect.position.y + 32.0, bf.arena_rect.end.y - 32.0)
	human_pos = global_position

	# 底盘专属被动（救护车毒雾 / 武装大巴车窗齐射）
	chassis_special_timer += delta
	if chassis_special_timer >= 0.5:
		chassis_special_timer = 0.0
		if GameState.selected_chassis_id == "ambulance":
			var acid_dmg: float = 25.0 + GameState.sp_regen_per_sec * 1.5
			for e in bf.enemies_container.get_children():
				if is_instance_valid(e) and global_position.distance_to(e.global_position) <= 155.0 + e.radius:
					e.take_damage(acid_dmg, false, "acid", global_position, false)
		elif GameState.selected_chassis_id == "bus":
			var nearest: Node2D = bf.get_nearest_enemy(global_position, 420.0)
			if is_instance_valid(nearest):
				for i in range(2):
					var dir: Vector2 = (nearest.global_position - global_position).normalized().rotated(randf_range(-0.18, 0.18))
					bf.spawn_player_projectile(global_position, dir, 720.0, 22.0 + GameState.level * 4.0, 0.0, "", false, false, 1)

func _process_human_mode(delta: float, bf: Node, move_input: Vector2) -> void:
	if human_burst_timer > 0.0:
		human_burst_timer -= delta

	# 1. 检查是否逃入休整小镇安全区 (小镇拖车救援机制)
	if not is_voluntary_unboard and is_instance_valid(bf) and bool(bf.get("is_player_in_safe_zone")):
		reboot_tank(0.65, "🏰 麦卡小镇应急拖车救援生效! 战车重装复原!")
		return

	# 2. [Space] 步兵战术翻滚 (无敌帧 + 高速位移)
	if Input.is_action_just_pressed("dodge_roll") and dodge_roll_timer <= 0.0:
		dodge_roll_timer = 0.28
		invuln_timer = 0.45
		bf.fx_layer.spawn_text(human_pos, "战术翻滚!", Color(0.5, 0.95, 1.0), 0.95)

	var h_spd: float = (GameState.move_speed + 45.0) * (1.0 + GameState.bonus_stats.get("human_speed_pct", 0.0)) + (55.0 if human_burst_timer > 0.0 else 0.0)
	if dodge_roll_timer > 0.0:
		h_spd *= 2.2
	var dir: Vector2 = move_input if move_input.length() > 0.1 else (Vector2.from_angle(chassis_angle) if dodge_roll_timer > 0.0 else Vector2.ZERO)
	human_pos += dir * h_spd * delta
	human_pos.x = clampf(human_pos.x, bf.arena_rect.position.x + 18.0, bf.arena_rect.end.x - 18.0)
	human_pos.y = clampf(human_pos.y, bf.arena_rect.position.y + 18.0, bf.arena_rect.end.y - 18.0)

	# 3. 步兵自动手持反装甲微型火箭/高能暴风手枪 (伤害与攻速全面继承战车构筑)
	var h_right_stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.25)
	human_fire_timer -= delta
	var reload_bonus: float = 1.0 + float(GameState.bonus_stats.get("reload_speed_pct", 0.0))
	var fire_cd: float = 0.24 / (reload_bonus * (1.0 + float(GameState.bonus_stats.get("human_speed_pct", 0.0))))
	if GameState.synergy_counts.get("lone_cub", 0) >= 2:
		fire_cd *= 0.72
	if human_fire_timer <= 0.0:
		var target: Node2D = bf.get_nearest_enemy(human_pos, 420.0)
		if h_right_stick.length() > 0.25 or is_instance_valid(target):
			human_fire_timer = fire_cd
			var aim: Vector2 = h_right_stick.normalized() if h_right_stick.length() > 0.25 else (target.global_position - human_pos).normalized()
			turret_angle = aim.angle()
			var h_dmg: float = get_human_effective_weapon_damage()
			var is_crit: bool = randf() < (GameState.crit_chance + 0.20)
			for i in range(-1, 2):
				bf.spawn_player_projectile(human_pos, aim.rotated(i * 0.10), 750.0, h_dmg, 0.0, "", is_crit, false, 1, "human_handgun", 0)
			if is_instance_valid(bf.fx_layer):
				bf.fx_layer.spawn_muzzle_flash(human_pos + aim * 14.0, aim, "machinegun", 0.85)
				bf.fx_layer.spawn_casing(human_pos, -aim.rotated(randf_range(0.7, 1.4)), false)
			SoundManager.play("subgun_mg", 0.15, -4.0)

	# 4. 战地抢修战车判定 (靠近战车残骸快速抢修，所需时间随捡到核心数大幅减少)
	if not is_voluntary_unboard:
		if human_pos.distance_to(global_position) <= 125.0:
			repair_progress += delta * 1.5
			var time_req: float = maxf(0.8, 2.2 - float(repair_cores_collected) * 0.6)
			if repair_progress >= time_req or repair_progress >= repair_time_needed:
				reboot_tank(0.45, "🔧 现场抢修完成! 重返战车!")
				return

func _process_tank_weapons(delta: float, bf: Node) -> void:
	# 主炮瞄准方向：支持【手柄右摇杆360°双摇杆瞄准】、【鼠标手动瞄准】与【C装置自动索敌】
	var right_stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.25)
	var stick_aiming: bool = right_stick.length() > 0.25
	var mouse_aiming: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var trigger_firing: bool = Input.is_action_pressed("fire_main")
	var main_target: Node2D = bf.get_highest_threat_enemy(global_position, 820.0)

	var manual_aim: bool = stick_aiming or mouse_aiming or trigger_firing or (not GameState.auto_main_cannon)

	if stick_aiming:
		turret_angle = right_stick.angle()
	elif mouse_aiming or (not GameState.auto_main_cannon and Input.get_connected_joypads().is_empty()):
		turret_angle = (get_global_mouse_position() - global_position).angle()
	elif is_instance_valid(main_target):
		turret_angle = lerp_angle(turret_angle, (main_target.global_position - global_position).angle(), 14.0 * delta)
	else:
		turret_angle = chassis_angle

	# C装置专属战术主动技触发 (按 [Q] / 坦克模式下按 [空格] / 所罗门2型自动触发)
	var cu: Dictionary = GameData.C_UNITS.get(GameState.equipped_c_unit_id, {})
	if all_out_timer <= 0.0:
		var manual_skill_pressed: bool = Input.is_action_just_pressed("all_out_attack") or (not is_human_mode and Input.is_action_just_pressed("dodge_roll"))
		if manual_skill_pressed or (GameState.equipped_c_unit_id == "cu_solomon2" and bf.enemies_container.get_child_count() > 0):
			_trigger_all_out_attack(bf)

	var reload_mult: float = 1.0 + GameState.bonus_stats.get("reload_speed_pct", 0.0) + GameState.bonus_stats.get("combo_reload_pct", 0.0) + (0.35 if overclock_timer > 0.0 else 0.0)
	var is_moving: bool = current_velocity.length() > 25.0

	for i in range(GameState.equipped_weapons.size()):
		if i >= weapon_timers.size():
			break
		var w_entry: Dictionary = GameState.equipped_weapons[i]
		var w_id: String = w_entry["id"]
		var rarity: int = w_entry.get("rarity", 0)
		var w_def: Dictionary = GameData.WEAPONS.get(w_id, {})
		var slot: String = w_def.get("slot", "SUB")

		# 旋转刺球撞角 / 超武·绝对领域神盾粉碎星 持续碰撞判定
		if w_def.get("effect", "") in ["orbit_ball", "evo_orbit_star"]:
			_process_spike_balls(bf, w_id, rarity, w_def.get("effect", "") == "evo_orbit_star")
			continue

		var spd_rate: float = reload_mult
		if slot == "SUB" and GameState.selected_chassis_id == "buggy" and is_moving:
			spd_rate += 0.35
		if slot == "SE":
			if GameState.selected_chassis_id == "missile_carrier":
				spd_rate += 0.25
			if GameState.synergy_counts.get("missile", 0) >= 4:
				spd_rate += 0.30

		weapon_timers[i] -= delta * spd_rate
		if weapon_timers[i] <= 0.0:
			if _try_fire_weapon(bf, i, w_id, rarity, w_def, manual_aim, main_target):
				weapon_timers[i] = float(w_def.get("cooldown", 1.0))
			else:
				weapon_timers[i] = 0.12

func _try_fire_weapon(bf: Node, idx: int, w_id: String, rarity: int, w_def: Dictionary, manual_aim: bool, main_target: Node2D, free_all_out: bool = false) -> bool:
	var slot: String = w_def.get("slot", "SUB")
	var dmg: float = GameState.get_weapon_effective_damage(w_id, rarity)
	var effect: String = w_def.get("effect", "")
	var crit_c: float = GameState.crit_chance + float(w_def.get("crit_bonus", 0.0))
	if slot == "MAIN" and GameState.count_equipped_slot_type("MAIN") == 1:
		crit_c += GameState.bonus_stats.get("lone_main_crit", 0.0)
	var is_crit: bool = randf() < crit_c

	if slot == "MAIN":
		if not free_all_out and weapon_ammo[idx] <= 0:
			return false
		var aim_dir: Vector2 = Vector2.from_angle(turret_angle)
		if not manual_aim and not is_instance_valid(main_target):
			return false
		if not manual_aim and is_instance_valid(main_target):
			aim_dir = (main_target.global_position - global_position).normalized()

		if not free_all_out and int(w_def.get("ammo", 999)) < 900:
			weapon_ammo[idx] -= 1

		var burst: int = int(w_def.get("burst", 1))
		var pierce: int = int(w_def.get("pierce", 1))
		var splash: float = float(w_def.get("splash", 60.0))
		var p_spd: float = float(w_def.get("proj_speed", 650.0))

		# 判定主炮连射 (绯红之狼底盘暴击连射 / 99式神话C装置 / 重炮轰鸣6件)
		var extra_shots: int = 0
		if is_crit and GameState.selected_chassis_id == "r_wolf" and randf() < 0.35:
			extra_shots += 1
		var cu: Dictionary = GameData.C_UNITS.get(GameState.equipped_c_unit_id, {})
		if overclock_timer > 0.0 or randf() < float(cu.get("double_shot_chance", 0.0)):
			extra_shots += 1
		if GameState.synergy_counts.get("artillery", 0) >= 6 and randf() < 0.50:
			extra_shots += 1

		var w_rarity: int = rarity
		var total_volleys: int = 1 + extra_shots
		for v in range(total_volleys):
			for b in range(burst):
				var spread: float = (float(b) - float(burst - 1) * 0.5) * 0.08 + v * 0.05
				bf.spawn_player_projectile(global_position + aim_dir * 26.0, aim_dir.rotated(spread), p_spd, dmg, splash, effect, is_crit, true, pierce, w_id, w_rarity)

		# 炮口火光 + 弹壳抛射 + 炮管后退后坐力动画
		turret_kick_dist = 11.0 + float(w_rarity) * 2.5
		if is_instance_valid(bf.fx_layer):
			var m_kind: String = "laser" if effect == "laser" else "cannon"
			bf.fx_layer.spawn_muzzle_flash(global_position + aim_dir * 34.0, aim_dir, m_kind, 1.0 + 0.18 * float(w_rarity))
			if effect != "laser":
				var eject_d: Vector2 = -aim_dir.rotated(randf_range(0.7, 1.3))
				bf.fx_layer.spawn_casing(global_position, eject_d, true)

		var w_tons: float = float(w_def.get("weight", 5.0))
		if effect == "laser":
			SoundManager.play("laser", 0.06, 0.0)
		else:
			SoundManager.play_cannon_by_caliber(w_tons)
		# 定向后坐力冲量反推与方向性弹簧震屏
		if not free_all_out:
			var recoil_kick: float = clampf(w_tons * 9.5, 24.0, 105.0)
			current_velocity -= aim_dir * recoil_kick
		bf.trigger_screen_shake(4.5 + w_tons * 0.35, 0.14, -aim_dir)
		return true

	elif slot == "SUB":
		var range_lim: float = float(w_def.get("range", 400.0))
		var target: Node2D = bf.get_nearest_enemy(global_position, range_lim)
		if not is_instance_valid(target):
			return false
		var aim_dir: Vector2 = (target.global_position - global_position).normalized()
		var pellets: int = int(w_def.get("pellets", 1)) * (2 if overclock_timer > 0.0 else 1)
		var pierce: int = int(w_def.get("pierce", 1))
		var p_spd: float = float(w_def.get("proj_speed", 720.0))

		var w_rarity: int = rarity
		for p in range(pellets):
			var spread: float = randf_range(-0.18, 0.18) if pellets > 1 else randf_range(-0.04, 0.04)
			bf.spawn_player_projectile(global_position + aim_dir * 18.0, aim_dir.rotated(spread), p_spd, dmg, 0.0, effect, is_crit, false, pierce, w_id, w_rarity)

		if is_instance_valid(bf.fx_layer):
			var s_kind: String = "machinegun"
			if effect == "electric":
				s_kind = "tesla"
			elif effect in ["burn", "acid"]:
				s_kind = "flame"
			bf.fx_layer.spawn_muzzle_flash(global_position + aim_dir * 22.0, aim_dir, s_kind, 0.85 + 0.12 * float(w_rarity))
			if effect not in ["flame", "acid", "electric"]:
				var eject_d: Vector2 = -aim_dir.rotated(randf_range(0.75, 1.4))
				bf.fx_layer.spawn_casing(global_position, eject_d, false)

		if effect == "electric":
			SoundManager.play("subgun_electric", 0.1, -6.0)
		elif effect in ["burn", "acid"]:
			SoundManager.play("subgun_flame", 0.1, -6.0)
		else:
			SoundManager.play("subgun_mg", 0.12, -7.0)
		return true

	elif slot == "SE":
		if effect == "homing":
			if bf.enemies_container.get_child_count() == 0:
				return false
			var salvo: int = int(w_def.get("salvo", 4))
			if GameState.synergy_counts.get("missile", 0) >= 2:
				salvo += 2
			var w_rarity: int = rarity
			for s in range(salvo):
				var ang: float = chassis_angle + (float(s) - float(salvo) * 0.5) * 0.25 + randf_range(-0.1, 0.1)
				bf.spawn_player_projectile(global_position, Vector2.from_angle(ang), 540.0, dmg, 42.0, "homing", is_crit, false, 1, w_id, w_rarity)
			if is_instance_valid(bf.fx_layer):
				bf.fx_layer.spawn_muzzle_flash(global_position, Vector2.from_angle(chassis_angle), "missile", 1.0 + 0.18 * float(w_rarity))
			SoundManager.play("se_missile", 0.08, -2.0)
			return true

		elif effect == "intercept": # 宙斯盾迎击激光网
			for p in bf.projectiles_container.get_children():
				if is_instance_valid(p) and p.is_enemy and global_position.distance_to(p.global_position) <= 175.0:
					bf.fx_layer.spawn_laser_beam(global_position, p.global_position, Color(0.3, 1.0, 0.65), 3.0)
					p.queue_free()
					heal_sp(6.0)
					SoundManager.play("subgun_electric", 0.15, -5.0)
					return true
			return false

		elif effect == "repair_drone":
			var drone_pos: Vector2 = global_position + Vector2.from_angle(orbit_angle * 1.4) * 52.0
			var t: Node2D = bf.get_nearest_enemy(drone_pos, 380.0)
			if is_instance_valid(t):
				bf.fx_layer.spawn_laser_beam(drone_pos, t.global_position, Color(0.4, 0.95, 1.0), 2.5)
				t.take_damage(dmg, is_crit, "laser", drone_pos, false)
				GameState.record_weapon_damage(w_id, dmg)
				return true
			return false

		elif effect == "sonic_wave":
			if bf.enemies_container.get_child_count() == 0:
				return false
			bf.fx_layer.spawn_explosion(global_position, 220.0, Color(0.45, 0.9, 1.0))
			SoundManager.play("laser", 0.1, 0.0)
			for e in bf.enemies_container.get_children():
				if is_instance_valid(e) and global_position.distance_to(e.global_position) <= 220.0 + e.radius:
					e.take_damage(dmg, is_crit, "sonic_wave", global_position, false)
					GameState.record_weapon_damage(w_id, dmg)
			return true

	return false

func _process_interception_system(delta: float, bf: Node) -> void:
	# 1. 【铁穹电磁力场】主动开启期间：320px 绝对防御圈瞬间蒸发一切敌弹并电击震退近身怪
	if iron_dome_timer > 0.0:
		for p in bf.projectiles_container.get_children():
			if is_instance_valid(p) and p.is_enemy and global_position.distance_to(p.global_position) <= 320.0:
				_execute_interception_hit(bf, p, Color(0.35, 0.95, 1.0), 3.0, 0.0, false)
		iron_dome_zap_timer -= delta
		if iron_dome_zap_timer <= 0.0:
			iron_dome_zap_timer = 0.45
			bf.fx_layer.spawn_shockwave(global_position, 220.0, Color(0.35, 0.95, 1.0))
			for e in bf.enemies_container.get_children():
				if is_instance_valid(e) and global_position.distance_to(e.global_position) <= 210.0 + e.radius:
					var zap_d: float = 45.0 + GameState.level * 10.0
					e.take_damage(zap_d, false, "electric", global_position, false)
					GameState.record_weapon_damage("cu_all_out", zap_d)
					if not e.is_boss:
						e.global_position += (e.global_position - global_position).normalized() * 36.0

	# 2. 统计所有独立迎击源 (神之右手C装置 + 密集阵CIWS + 宙斯盾激光网 + 极星超武)
	var cd_haste: float = 1.0 + float(GameState.bonus_stats.get("intercept_cd_mult", 0.0))
	if GameState.equipped_c_unit_id == "cu_interceptor_ai":
		cd_haste += 0.30

	var sources: Array = []
	var cu: Dictionary = GameData.C_UNITS.get(GameState.equipped_c_unit_id, {})
	if float(cu.get("interception_range", 0.0)) > 0.0:
		sources.append({
			"key": "cu_radar",
			"range": float(cu.get("interception_range", 220.0)),
			"cd": float(cu.get("interception_cd", 0.35)) / cd_haste,
			"col": Color(0.35, 0.95, 1.0),
			"heal": 4.0,
			"splash_dmg": 0.0,
			"reflect": false
		})

	for idx in range(GameState.equipped_weapons.size()):
		var w_entry: Dictionary = GameState.equipped_weapons[idx]
		var wid: String = w_entry["id"]
		var rar: int = int(w_entry.get("rarity", 0))
		if wid == "sub_ciws_phalanx":
			sources.append({
				"key": "ciws_%d" % idx,
				"range": 195.0 + rar * 12.0,
				"cd": maxf(0.10, (0.28 - rar * 0.03) / cd_haste),
				"col": Color(1.0, 0.88, 0.35),
				"heal": 2.0,
				"splash_dmg": GameState.get_weapon_effective_damage(wid, rar) * 1.25,
				"reflect": false
			})
		elif wid == "se_aegis":
			sources.append({
				"key": "aegis_%d" % idx,
				"range": 240.0 + rar * 15.0,
				"cd": maxf(0.12, (0.38 - rar * 0.04) / cd_haste),
				"col": Color(0.30, 1.0, 0.65),
				"heal": 8.0 + rar * 2.0,
				"splash_dmg": 0.0,
				"reflect": false
			})
		elif wid == "evo_aegis_star":
			sources.append({
				"key": "evostar_%d" % idx,
				"range": 320.0,
				"cd": 0.10 / cd_haste,
				"col": Color(0.45, 0.95, 1.0),
				"heal": 10.0,
				"splash_dmg": 85.0 + GameState.level * 12.0,
				"reflect": true
			})

	if sources.is_empty():
		return

	for s in sources:
		var k: String = s["key"]
		var cur_t: float = float(intercept_timers.get(k, 0.0)) - delta
		if cur_t <= 0.0:
			var hit_proj: Node2D = null
			var best_d: float = float(s["range"])
			for p in bf.projectiles_container.get_children():
				if is_instance_valid(p) and p.is_enemy and not p.is_queued_for_deletion():
					var d: float = global_position.distance_to(p.global_position)
					if d <= best_d:
						best_d = d
						hit_proj = p
			if is_instance_valid(hit_proj):
				_execute_interception_hit(bf, hit_proj, s["col"], float(s["heal"]), float(s["splash_dmg"]), bool(s["reflect"]))
				cur_t = float(s["cd"])
			else:
				cur_t = 0.0
		intercept_timers[k] = cur_t

func _execute_interception_hit(bf: Node, proj: Node2D, beam_col: Color, sp_heal: float, splash_dmg: float, reflect_laser: bool) -> void:
	var p_pos: Vector2 = proj.global_position
	bf.fx_layer.spawn_laser_beam(global_position, p_pos, beam_col, 3.5)
	bf.fx_layer.spawn_explosion(p_pos, 22.0, beam_col)
	bf.fx_layer.spawn_metal_debris(p_pos, beam_col, 4)
	bf.fx_layer.spawn_text(p_pos + Vector2(0, -10), "🛡️迎击!", beam_col, 0.92)
	SoundManager.play("interception_chirp", 0.08, -3.0)
	GameState.report_metric("intercept_count", 1, true)
	if sp_heal > 0.0:
		heal_sp(sp_heal)
	if splash_dmg > 0.0:
		for e in bf.enemies_container.get_children():
			if is_instance_valid(e) and p_pos.distance_to(e.global_position) <= 85.0 + e.radius:
				e.take_damage(splash_dmg, false, "electric", p_pos, false)
	if reflect_laser:
		var near_e: Node2D = bf.get_nearest_enemy(p_pos, 480.0)
		if is_instance_valid(near_e):
			bf.fx_layer.spawn_laser_beam(p_pos, near_e.global_position, Color(0.4, 0.95, 1.0), 4.5)
			near_e.take_damage(splash_dmg * 1.5, true, "laser", p_pos, false)
	if bf.has_method("recycle_projectile"):
		bf.recycle_projectile(proj)
	else:
		proj.queue_free()

func _trigger_all_out_attack(bf: Node) -> void:
	all_out_timer = all_out_max_cd
	GameState.report_metric("all_out_count", 1, true)
	var cu: Dictionary = GameData.C_UNITS.get(GameState.equipped_c_unit_id, GameData.C_UNITS["cu_type66"])
	var skill_id: String = cu.get("skill_id", "all_out")
	var main_target: Node2D = bf.get_highest_threat_enemy(global_position, 950.0)

	match skill_id:
		"god_barrage":
			nitro_boost_timer = 3.0
			bf.fx_layer.spawn_text(global_position + Vector2(0, -28), "🔥 所罗门2型：【神之突击齐射 + 氮气突进】!! 🔥", Color(1.0, 0.65, 0.2), 1.45)
			bf.fx_layer.spawn_shockwave(global_position, 180.0, Color(1.0, 0.65, 0.2))
			for i in range(GameState.equipped_weapons.size()):
				var w_entry: Dictionary = GameState.equipped_weapons[i]
				var w_def: Dictionary = GameData.WEAPONS.get(w_entry["id"], {})
				if w_def.get("slot", "") in ["MAIN", "SE"]:
					_try_fire_weapon(bf, i, w_entry["id"], w_entry.get("rarity", 0), w_def, false, main_target, true)
		"overclock":
			overclock_timer = 4.5
			bf.fx_layer.spawn_text(global_position + Vector2(0, -28), "⚡ 99式神话：【超频双发过载 4.5s】!! ⚡", Color(1.0, 0.90, 0.25), 1.45)
			bf.fx_layer.spawn_shockwave(global_position, 210.0, Color(1.0, 0.88, 0.25))
			for i in range(weapon_timers.size()):
				weapon_timers[i] = 0.0
		"smoke_decoy":
			smoke_evade_timer = 2.8
			var decoy_pos: Vector2 = global_position
			bf.fx_layer.spawn_text(decoy_pos + Vector2(0, -28), "💨 幻影全息：【热烟幕100%闪避 + 电磁诱饵】!! 💨", Color(0.45, 0.95, 1.0), 1.45)
			bf.fx_layer.spawn_shockwave(decoy_pos, 220.0, Color(0.45, 0.95, 1.0))
			for e in bf.enemies_container.get_children():
				if is_instance_valid(e) and decoy_pos.distance_to(e.global_position) <= 220.0 + e.radius:
					var emp_d: float = 135.0 + GameState.level * 18.0
					e.take_damage(emp_d, true, "electric", decoy_pos, false)
					e.stun_timer = maxf(e.stun_timer, 1.8)
					GameState.record_weapon_damage("cu_all_out", emp_d)
		"valkyrie_sweep":
			bf.fx_layer.spawn_text(global_position + Vector2(0, -28), "🛰️ 瓦尔基里：【女武神天基死光犁地】!! 🛰️", Color(0.4, 0.95, 1.0), 1.45)
			var base_dir: Vector2 = Vector2.from_angle(turret_angle)
			for beam_i in range(-1, 2):
				var b_dir: Vector2 = base_dir.rotated(beam_i * 0.24)
				var end_pt: Vector2 = global_position + b_dir * 780.0
				bf.fx_layer.spawn_laser_beam(global_position, end_pt, Color(0.35, 0.95, 1.0), 12.0)
				for k in range(1, 7):
					bf.fx_layer.spawn_explosion(global_position + b_dir * (k * 120.0), 75.0, Color(0.35, 0.92, 1.0))
			for e in bf.enemies_container.get_children():
				if is_instance_valid(e):
					var to_e: Vector2 = e.global_position - global_position
					if to_e.length() <= 800.0 and to_e.normalized().dot(base_dir) >= 0.65:
						var sweep_dmg: float = 340.0 + GameState.level * 35.0
						e.take_damage(sweep_dmg, true, "omega_laser", e.global_position, true)
						GameState.record_weapon_damage("cu_all_out", sweep_dmg)
		"iron_dome":
			iron_dome_timer = 3.5
			iron_dome_zap_timer = 0.0
			bf.fx_layer.spawn_text(global_position + Vector2(0, -28), "🛡️ 神之右手：【铁穹电磁防御力场 3.5s】!! 🛡️", Color(0.35, 1.0, 0.85), 1.45)
			bf.fx_layer.spawn_shockwave(global_position, 320.0, Color(0.35, 1.0, 0.85))
		_:
			bf.fx_layer.spawn_text(global_position + Vector2(0, -28), "★ C装置：全弹齐射 (ALL-OUT ATTACK)!! ★", Color(1.0, 0.85, 0.2), 1.45)
			for i in range(GameState.equipped_weapons.size()):
				var w_entry: Dictionary = GameState.equipped_weapons[i]
				var w_def: Dictionary = GameData.WEAPONS.get(w_entry["id"], {})
				if w_def.get("slot", "") in ["MAIN", "SE"]:
					_try_fire_weapon(bf, i, w_entry["id"], w_entry.get("rarity", 0), w_def, false, main_target, true)

	bf.trigger_screen_shake(9.5, 0.28)
	SoundManager.play("c_unit_skill", 0.04, 2.0)

	# 导弹暴雨 (6) 羁绊：额外召唤轨道卫星激光轰炸全场
	if GameState.synergy_counts.get("missile", 0) >= 6:
		for e in bf.enemies_container.get_children():
			if is_instance_valid(e) and randf() < 0.55:
				var sat_dmg: float = 260.0 + GameState.level * 25.0
				bf.fx_layer.spawn_laser_beam(e.global_position + Vector2(0, -400), e.global_position, Color(0.4, 0.95, 1.0), 9.0)
				bf.fx_layer.spawn_explosion(e.global_position, 85.0, Color(0.35, 0.9, 1.0))
				e.take_damage(sat_dmg, true, "laser", e.global_position, true)
				GameState.record_weapon_damage("cu_all_out", sat_dmg)

func _process_spike_balls(bf: Node, w_id: String, rarity: int, is_evo_star: bool = false) -> void:
	var ball_cnt: int = 4 if is_evo_star else 2
	var radius_dist: float = 102.0 if is_evo_star else 86.0
	var ball_dmg: float = GameState.get_weapon_effective_damage(w_id, rarity) + GameState.used_weight * 3.5
	if is_evo_star:
		ball_dmg += GameState.max_sp * 0.20

	for b_idx in range(ball_cnt):
		var b_pos: Vector2 = global_position + Vector2.from_angle(orbit_angle * (1.45 if is_evo_star else 1.0) + b_idx * (TAU / float(ball_cnt))) * radius_dist
		# 拦截敌方子弹
		for p in bf.projectiles_container.get_children():
			if is_instance_valid(p) and p.is_enemy and b_pos.distance_to(p.global_position) <= (28.0 if is_evo_star else 22.0):
				p.queue_free()
				if is_evo_star:
					heal_sp(4.0)
		# 碾碎触碰的敌人
		for e in bf.enemies_container.get_children():
			if is_instance_valid(e) and b_pos.distance_to(e.global_position) <= 22.0 + e.radius:
				var key: String = "ball_%d_%d" % [b_idx, e.get_instance_id()]
				if not ram_cooldowns.has(key):
					ram_cooldowns[key] = 0.25 if is_evo_star else 0.32
					e.take_damage(ball_dmg, is_evo_star, "electric" if is_evo_star else "", b_pos, false)
					GameState.record_weapon_damage(w_id, ball_dmg)
					if is_evo_star:
						heal_sp(5.0)

func on_enemy_collision(enemy: Node2D, _delta: float) -> void:
	var bf: Node = get_parent()
	var key: String = "ram_%d" % enemy.get_instance_id()
	if ram_cooldowns.has(key):
		return
	ram_cooldowns[key] = 0.35

	var is_tank_moving_fast: bool = (not is_human_mode) and (current_velocity.length() > 85.0)
	var crushed_enemy: bool = false

	# 1. 战车重型履带高速物理碾压 (基于战车总吨位与行驶速度)
	if is_tank_moving_fast and not enemy.is_boss:
		var eng: Dictionary = GameData.ENGINES.get(GameState.equipped_engine_id, {})
		var ram_mult: float = 1.0 + float(eng.get("ram_bonus", 0.0)) + (0.50 if nitro_boost_timer > 0.0 else 0.0)
		if GameState.selected_chassis_id == "mammoth":
			ram_mult += 2.5
		elif GameState.selected_chassis_id == "tyrannos":
			ram_mult += 1.8
		var speed_factor: float = clampf(current_velocity.length() / 150.0, 0.8, 2.5)
		var ram_dmg: float = (GameState.used_weight * 6.0 + 45.0) * ram_mult * speed_factor

		# 钢铁碾压 (6) 羁绊追加装甲反震爆破
		if GameState.synergy_counts.get("juggernaut", 0) >= 6:
			ram_dmg += current_sp * 0.20
			bf.fx_layer.spawn_explosion(enemy.global_position, 85.0, Color(0.95, 0.75, 0.25))

		# 判定是否致死直接碾碎
		if ram_dmg >= enemy.hp:
			crushed_enemy = true
			enemy.take_damage(ram_dmg, true, "crush", global_position, false)
			GameState.record_weapon_damage("chassis_ram", ram_dmg)
			GameState.report_metric("crushed_enemies", 1, true)
			bf.fx_layer.spawn_explosion(enemy.global_position, 55.0, Color(1.0, 0.45, 0.15))
			bf.fx_layer.spawn_metal_debris(enemy.global_position, enemy.base_color, 7)
			bf.fx_layer.spawn_text(enemy.global_position, "💥 碾碎 CRUSH!", Color(1.0, 0.88, 0.2), 1.2)
			SoundManager.play("ram_metal_crush", 0.08, 1.4)
			bf.trigger_screen_shake(4.2, 0.10, current_velocity.normalized())
			if bf.has_method("trigger_hitstop"):
				bf.trigger_hitstop(0.024, 0.08)
		else:
			enemy.take_damage(ram_dmg, false, "ram", global_position, false)
			GameState.record_weapon_damage("chassis_ram", ram_dmg)
			enemy.global_position += (enemy.global_position - global_position).normalized() * 45.0

	# 2. 钢铁碾压 (4) 荆棘反伤
	if not is_human_mode and GameState.synergy_counts.get("juggernaut", 0) >= 4:
		var thorn_dmg: float = GameState.used_weight * 5.0
		enemy.take_damage(thorn_dmg, false, "", global_position, false)
		GameState.record_weapon_damage("chassis_ram", thorn_dmg)

	# 3. 若成功碾碎小怪，战车毫发无损！仅受微小阻力
	if crushed_enemy:
		current_velocity *= 0.95
		return

	# 4. 未能碾碎（强敌/精英/低速撞击），承受接触伤害（冲撞时获得撞角动量保护减伤）
	var incoming: float = enemy.contact_dmg
	if is_tank_moving_fast:
		incoming *= 0.40 # 高速冲撞撞角保护大幅削减
	if not is_human_mode and GameState.selected_chassis_id == "abrams":
		incoming *= 0.70
	take_damage(incoming, enemy.global_position)

func take_damage(amount: float, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if invuln_timer > 0.0:
		return
	var bf: Node = get_parent()
	if is_instance_valid(bf) and bool(bf.get("is_player_in_safe_zone")):
		return

	# 闪避判定 (含热烟幕 100% 绝对闪避) + 步兵小型目标高机动闪避 (+15%)
	var eff_dodge: float = GameState.dodge_chance + (0.15 if is_human_mode else 0.0)
	if smoke_evade_timer > 0.0 or randf() < eff_dodge:
		GameState.report_metric("dodge_count", 1, true)
		bf.fx_layer.spawn_text(get_active_position(), "闪避 MISS!", Color(0.45, 0.95, 1.0), 1.05)
		if GameState.equipped_c_unit_id == "cu_mirage":
			bf.fx_layer.spawn_explosion(get_active_position(), 95.0, Color(0.4, 0.85, 1.0))
			for e in bf.enemies_container.get_children():
				if is_instance_valid(e) and get_active_position().distance_to(e.global_position) <= 105.0:
					e.take_damage(65.0 + GameState.level * 12.0, false, "electric", get_active_position(), false)
		return

	invuln_timer = 0.35 if is_human_mode else 0.22
	if is_human_mode:
		human_hp -= amount
		bf.fx_layer.spawn_text(human_pos, "-%d HP" % int(amount), Color(1.0, 0.2, 0.25), 1.15)
		if human_hp <= 0.0:
			if GameState.field_defib_available:
				GameState.field_defib_available = false
				GameState.report_metric("defib_revive_count", 1, true)
				is_human_mode = false
				is_voluntary_unboard = false
				global_position = human_pos
				current_sp = GameState.max_sp * 0.60
				human_hp = GameState.max_human_hp
				invuln_timer = 2.0
				SoundManager.play("mince_revive", 0.02, 3.0)
				bf.trigger_screen_shake(14.0, 0.4)
				bf.fx_layer.spawn_laser_beam(human_pos + Vector2(0, -450), human_pos, Color(0.35, 0.95, 1.0), 16.0)
				bf.fx_layer.spawn_explosion(human_pos, 240.0, Color(0.35, 0.95, 1.0))
				bf.fx_layer.spawn_text(human_pos, "⚡ 特斯拉轨道除颤卫星触发! 原地满血复苏! ⚡", Color(0.35, 1.0, 0.95), 1.55)
				for e in bf.enemies_container.get_children():
					if is_instance_valid(e):
						e.take_damage(350.0, true, "electric", human_pos, false)
				return
			human_hp = 0.0
			bf.on_player_total_defeat()
	else:
		current_sp -= amount
		GameState.report_metric("tank_absorbed_dmg", amount, true)
		bf.fx_layer.spawn_text(global_position, "-%d SP" % int(amount), Color(1.0, 0.65, 0.2), 1.05)
		if current_sp <= 0.0:
			current_sp = 0.0
			_trigger_tank_wreck(bf)

func _trigger_tank_wreck(bf: Node) -> void:
	GameState.report_metric("tank_wreck_count", 1, true)
	is_human_mode = true
	is_voluntary_unboard = false
	human_pos = global_position + Vector2(0, 28)
	repair_progress = 0.0
	repair_cores_needed = 3
	repair_cores_collected = 0
	human_hp = GameState.max_human_hp
	invuln_timer = 3.0
	human_burst_timer = 4.5
	bf.trigger_screen_shake(16.0, 0.45)
	bf.fx_layer.spawn_explosion(global_position, 160.0, Color(1.0, 0.45, 0.15))
	bf.fx_layer.spawn_smoke_puff(global_position, 65.0, Color(0.3, 0.3, 0.3, 0.8), 3.0)
	bf.fx_layer.spawn_text(global_position, "★ 战车大破! 紧急脱险弹射! 拾取3枚动力核心或逃往休整小镇! ★", Color(1.0, 0.30, 0.20), 2.0)
	SoundManager.play("eject_alarm", 0.04, 2.0)

	# 全向强力 EMP 冲击波：震飞 180px 并定身 3.5s
	for e in bf.enemies_container.get_children():
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= 280.0:
			e.take_damage(120.0 + GameState.level * 18.0, false, "electric", global_position, false)
			if not e.is_boss:
				e.global_position += (e.global_position - global_position).normalized() * 180.0
			if "freeze_timer" in e:
				e.freeze_timer = maxf(e.freeze_timer, 3.5)

	# 向四周散落 3 枚应急动力核心
	var base_ang: float = randf() * TAU
	for i in range(3):
		var c_ang: float = base_ang + float(i) * (TAU / 3.0) + randf_range(-0.25, 0.25)
		var c_dist: float = randf_range(150.0, 230.0)
		var c_pos: Vector2 = global_position + Vector2.from_angle(c_ang) * c_dist
		c_pos.x = clampf(c_pos.x, bf.arena_rect.position.x + 40.0, bf.arena_rect.end.x - 40.0)
		c_pos.y = clampf(c_pos.y, bf.arena_rect.position.y + 40.0, bf.arena_rect.end.y - 40.0)
		bf.spawn_drop("repair_core", 1, c_pos)

func get_effective_paint() -> Dictionary:
	var ch_id: String = GameState.selected_chassis_id
	var custom_paint: Dictionary = GameState.get_custom_chassis_paint(ch_id)
	if not custom_paint.is_empty():
		return custom_paint
	var skin_id: String = GameState.get_chassis_skin(ch_id)
	if skin_id != "default" and skin_id != "":
		var skin_def: Dictionary = GameData.get_chassis_skin_def(ch_id, skin_id)
		if not skin_def.is_empty():
			return {
				"body": skin_def.get("body", Color.WHITE),
				"turret": skin_def.get("turret", Color.WHITE),
				"treads": skin_def.get("treads", Color.WHITE),
				"decal": skin_def.get("decal", Color.WHITE)
			}
	var ch: Dictionary = GameData.CHASSIS.get(ch_id, GameData.CHASSIS["buggy"])
	var base_col: Color = ch.get("color", Color(0.8, 0.25, 0.2))
	return {
		"body": base_col,
		"turret": base_col.darkened(0.2),
		"treads": Color(0.22, 0.20, 0.18),
		"decal": Color(0.95, 0.85, 0.35)
	}

func _draw() -> void:
	var paint: Dictionary = get_effective_paint()
	var hull_col: Color = paint.get("body", Color(0.8, 0.25, 0.2))
	var turret_col: Color = paint.get("turret", hull_col.darkened(0.2))
	var treads_col: Color = paint.get("treads", Color(0.22, 0.20, 0.18))
	var decal_col: Color = paint.get("decal", Color(0.95, 0.85, 0.35))
	if is_human_mode and not is_voluntary_unboard:
		hull_col = hull_col.darkened(0.55) # 大破残骸变暗冒烟

	# 1. 救护车生化毒雾光环
	if not is_human_mode and GameState.selected_chassis_id == "ambulance":
		draw_circle(Vector2.ZERO, 155.0, Color(0.4, 0.95, 0.3, 0.12))
		draw_arc(Vector2.ZERO, 155.0, 0.0, TAU, 36, Color(0.4, 0.95, 0.3, 0.4), 2.0)

	# 2. 绘制战车大破抢修圈与条形抢修进度条
	if is_human_mode and not is_voluntary_unboard:
		draw_arc(Vector2.ZERO, 125.0, 0.0, TAU, 36, Color(0.25, 1.0, 0.45, 0.75), 3.0)
		draw_string_outline(ThemeDB.fallback_font, Vector2(-65, -82), "⚡ 核心: %d/3 | 快速抢修" % repair_cores_collected, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(-65, -82), "⚡ 核心: %d/3 | 快速抢修" % repair_cores_collected, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 1.0, 0.65))
		var rep_ratio: float = clampf(repair_progress / repair_time_needed, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 95.0, -PI * 0.5, -PI * 0.5 + TAU * rep_ratio, 36, Color(1.0, 0.92, 0.25), 7.0)
		var rbw: float = 82.0
		draw_rect(Rect2(-rbw * 0.5, -62.0, rbw, 10.0), Color(0.08, 0.08, 0.08, 0.92))
		draw_rect(Rect2(-rbw * 0.5, -62.0, rbw * rep_ratio, 10.0), Color(0.25, 1.0, 0.45))
		draw_rect(Rect2(-rbw * 0.5, -62.0, rbw, 10.0), Color(1.0, 0.92, 0.25), false, 1.5)
		draw_string_outline(ThemeDB.fallback_font, Vector2(-42, -68), "🔧 抢修 %d%%" % int(rep_ratio * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(-42, -68), "🔧 抢修 %d%%" % int(rep_ratio * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.95, 0.35))

	# 3. 绘制战车底盘与履带 (优先使用高精度 2D 废土战车俯视贴图，支持自由涂装部位渲染)
	draw_set_transform(Vector2.ZERO, chassis_angle, Vector2.ONE)
	var ch_tex: Texture2D = GameData.get_chassis_tex(GameState.selected_chassis_id)
	if ch_tex != null:
		var tex_sz: Vector2 = ch_tex.get_size()
		var disp_w: float = 118.0 if GameState.selected_chassis_id in ["mammoth", "bus", "tyrannos"] else 104.0
		var disp_h: float = disp_w * (tex_sz.y / maxf(1.0, tex_sz.x))
		var mod_col: Color = Color(0.42, 0.42, 0.42, 0.92) if (is_human_mode and not is_voluntary_unboard) else Color.WHITE
		mod_col = mod_col * Color.WHITE.lerp(hull_col, 0.58)
		draw_texture_rect(ch_tex, Rect2(-disp_w * 0.5, -disp_h * 0.5, disp_w, disp_h), false, mod_col)
		# 履带边缘与战术荧光车标
		draw_rect(Rect2(-disp_w * 0.46, -disp_h * 0.38, 4.0, disp_h * 0.76), treads_col)
		draw_rect(Rect2(disp_w * 0.46 - 4.0, -disp_h * 0.38, 4.0, disp_h * 0.76), treads_col)
		draw_circle(Vector2(0, -disp_h * 0.42), 4.5, decal_col)
		draw_circle(Vector2(0, -disp_h * 0.42), 2.0, Color.WHITE)
	else:
		draw_rect(Rect2(-38, -32, 76, 14), treads_col)
		draw_rect(Rect2(-38, 18, 76, 14), treads_col)
		draw_rect(Rect2(-32, -24, 64, 48), hull_col)
		draw_rect(Rect2(-32, -24, 64, 48), decal_col, false, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 3.8 绘制 C 装置主动技光环与迎击警戒圈
	if iron_dome_timer > 0.0:
		draw_circle(Vector2.ZERO, 320.0, Color(0.25, 0.95, 0.85, 0.10))
		draw_arc(Vector2.ZERO, 320.0, 0.0, TAU, 48, Color(0.35, 1.0, 0.90, 0.75), 3.0)
	elif smoke_evade_timer > 0.0:
		draw_circle(Vector2.ZERO, 85.0, Color(0.55, 0.85, 1.0, 0.25))
		draw_arc(Vector2.ZERO, 85.0, 0.0, TAU, 32, Color(0.55, 0.95, 1.0, 0.85), 2.5)
	elif overclock_timer > 0.0:
		draw_arc(Vector2.ZERO, 68.0, 0.0, TAU, 28, Color(1.0, 0.88, 0.25, 0.85), 3.0)

	# 4. 绘制独立旋转主炮瞄准指示与双摇杆/手动远程红外激光引导线
	draw_set_transform(Vector2.ZERO, turret_angle, Vector2.ONE)
	var main_cnt: int = GameState.count_equipped_slot_type("MAIN")
	if main_cnt > 0 and not is_human_mode:
		var r_stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.25)
		var is_manual_sight: bool = (not GameState.auto_main_cannon) or r_stick.length() > 0.25 or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if is_manual_sight:
			draw_line(Vector2(28 - turret_kick_dist, 0), Vector2(540, 0), Color(1.0, 0.22, 0.25, 0.38), 1.8)
			draw_arc(Vector2(540, 0), 14.0, 0.0, TAU, 20, Color(1.0, 0.28, 0.28, 0.78), 2.0)
			draw_line(Vector2(520, 0), Vector2(560, 0), Color(1.0, 0.35, 0.35, 0.85), 1.5)
			draw_line(Vector2(540, -18), Vector2(540, 18), Color(1.0, 0.35, 0.35, 0.85), 1.5)
		draw_line(Vector2(28 - turret_kick_dist, 0), Vector2(88 - turret_kick_dist, 0), decal_col.lightened(0.2), 2.5)
		draw_circle(Vector2(88 - turret_kick_dist, 0), 4.5, decal_col)
	if ch_tex == null:
		draw_circle(Vector2.ZERO, 18.0, turret_col)
		draw_circle(Vector2.ZERO, 18.0, decal_col, false, 2.0)
		if main_cnt == 1:
			draw_rect(Rect2(6 - turret_kick_dist, -5, 38, 10), turret_col.lightened(0.35))
		elif main_cnt >= 2:
			draw_rect(Rect2(6 - turret_kick_dist, -10, 38, 6), turret_col.lightened(0.35))
			draw_rect(Rect2(6 - turret_kick_dist, 4, 38, 6), turret_col.lightened(0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 5. 绘制旋转刺球撞角、神盾粉碎星超武与浮游无人机
	for w in GameState.equipped_weapons:
		var eff: String = GameData.WEAPONS[w["id"]].get("effect", "")
		if eff == "orbit_ball":
			for b_idx in range(2):
				var b_rel: Vector2 = Vector2.from_angle(orbit_angle + b_idx * PI) * 86.0
				draw_line(Vector2.ZERO, b_rel, Color(0.6, 0.6, 0.6, 0.6), 2.5)
				draw_circle(b_rel, 18.0, Color(0.35, 0.38, 0.42))
				draw_arc(b_rel, 18.0, 0.0, TAU, 8, Color(0.95, 0.85, 0.35), 2.5)
		elif eff == "evo_orbit_star":
			for b_idx in range(4):
				var b_rel: Vector2 = Vector2.from_angle(orbit_angle * 1.45 + b_idx * (TAU / 4.0)) * 102.0
				draw_line(Vector2.ZERO, b_rel, Color(0.35, 0.95, 1.0, 0.75), 3.0)
				draw_circle(b_rel, 21.0, Color(1.0, 0.85, 0.20))
				draw_arc(b_rel, 23.0, 0.0, TAU, 6, Color(0.35, 0.98, 1.0), 3.0)
		elif eff == "repair_drone":
			var d_rel: Vector2 = Vector2.from_angle(orbit_angle * 1.4) * 66.0
			draw_circle(d_rel, 10.0, Color(0.3, 0.95, 0.85))
			draw_circle(d_rel, 5.0, Color.WHITE)

	# 6. 土豆兄弟风格：战车头顶实时 SP 血条 + 全弹发射充能进度条
	if not is_human_mode:
		var sp_w: float = 76.0
		var sp_h: float = 9.0
		var sp_y: float = -54.0
		var sp_ratio: float = clampf(current_sp / maxf(1.0, GameState.max_sp), 0.0, 1.0)
		draw_rect(Rect2(-sp_w * 0.5 - 1.5, sp_y - 1.5, sp_w + 3.0, sp_h + 3.0), Color(0.05, 0.05, 0.05, 0.94))
		var sp_col: Color = Color(0.22, 0.92, 0.42) if sp_ratio > 0.35 else Color(1.0, 0.32, 0.22)
		draw_rect(Rect2(-sp_w * 0.5, sp_y, sp_w * sp_ratio, sp_h), sp_col)
		var cd_ratio: float = clampf(1.0 - (all_out_timer / maxf(0.1, all_out_max_cd)), 0.0, 1.0)
		draw_rect(Rect2(-sp_w * 0.5, sp_y + sp_h + 2.5, sp_w, 4.0), Color(0.1, 0.1, 0.1, 0.88))
		draw_rect(Rect2(-sp_w * 0.5, sp_y + sp_h + 2.5, sp_w * cd_ratio, 4.0), Color(1.0, 0.85, 0.20) if cd_ratio >= 1.0 else Color(0.35, 0.75, 1.0))

	# 7. 如果处于步兵模式，绘制猎人步兵俯视贴图与头顶鲜红生命条
	if is_human_mode:
		var rel_h: Vector2 = human_pos - global_position
		var h_commando_tex: Texture2D = GameData.get_tex("human_commando")
		draw_arc(rel_h, 22.0, 0.0, TAU, 24, Color(0.35, 1.0, 0.55, 0.85), 2.5)
		if invuln_timer > 0.0:
			draw_circle(rel_h, 30.0, Color(0.35, 0.95, 1.0, 0.20))
			draw_arc(rel_h, 30.0, 0.0, TAU, 24, Color(0.4, 1.0, 0.85, 0.85), 2.5)
		var h_skin_id: String = GameState.get_hunter_skin(GameState.selected_hunter_id)
		var h_skin_def: Dictionary = GameData.get_hunter_skin_def(GameState.selected_hunter_id, h_skin_id)
		var h_tint: Color = h_skin_def.get("tint", Color.WHITE)
		if h_commando_tex != null:
			draw_set_transform(rel_h, turret_angle, Vector2.ONE)
			draw_texture_rect(h_commando_tex, Rect2(-31, -23, 62, 46), false, h_tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(rel_h, 16.0, Color(0.95, 0.75, 0.25))
			draw_circle(rel_h, 11.0, Color(0.92, 0.28, 0.22))
		var h_bw: float = 58.0
		var h_bh: float = 7.5
		var h_by: float = rel_h.y - 34.0
		var h_ratio: float = clampf(human_hp / maxf(1.0, GameState.max_human_hp), 0.0, 1.0)
		draw_rect(Rect2(rel_h.x - h_bw * 0.5 - 1.5, h_by - 1.5, h_bw + 3.0, h_bh + 3.0), Color(0.05, 0.05, 0.05, 0.94))
		draw_rect(Rect2(rel_h.x - h_bw * 0.5, h_by, h_bw * h_ratio, h_bh), Color(1.0, 0.28, 0.25))
