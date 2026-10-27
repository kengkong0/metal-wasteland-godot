extends Node2D
## 废土机械兽与十大【赏金首 (Wanted Boss)】AI及部位破坏状态机

var enemy_id: String = "bio_ant"
var enemy_name: String = "钳甲机械蚁"
var is_boss: bool = false
var is_elite: bool = false
var boss_mechanic: String = ""
var reward_weapon_id: String = ""
var bounty_gold: int = 0

var max_hp: float = 40.0
var hp: float = 40.0
var max_shield: float = 0.0
var shield: float = 0.0
var armor: float = 5.0
var move_speed: float = 120.0
var contact_dmg: float = 12.0
var radius: float = 16.0
var xp_val: int = 1
var gold_val: int = 2
var base_color: Color = Color(0.8, 0.3, 0.2)
var behavior: String = "melee"
var sniper_aim_timer: float = 0.0
var sniper_aim_dir: Vector2 = Vector2.RIGHT
var elite_pulse: float = 0.0

# --- 状态异常与计时器 ---
var burn_stacks: int = 0
var burn_timer: float = 0.0
var cement_slow_timer: float = 0.0
var stun_timer: float = 0.0
var hit_flash_timer: float = 0.0
var attack_timer: float = 1.5
var skill_timer: float = 3.0
var facing_angle: float = 0.0

# --- 赏金首专属机制变量 ---
var is_charging: bool = false
var charge_dir: Vector2 = Vector2.ZERO
var charge_windup: float = 0.0
var is_burrowed: bool = false
var is_stealthed: bool = false
var train_segments_left: int = 4
var segment_trail: Array = []
var battleship_parts: Array = [] # 沙漠之舟三部位破坏

func setup_regular(def: Dictionary, wave_num: int, pos: Vector2) -> void:
	is_boss = false
	is_elite = bool(def.get("is_elite", false))
	enemy_id = def["id"]
	enemy_name = def["name"]
	global_position = pos

	var hp_scale: float = (1.0 + 0.25 * float(wave_num - 1) + 0.045 * pow(float(wave_num - 1), 2.0)) * GameState.get_enemy_hp_multiplier()
	var dmg_scale: float = (1.0 + 0.12 * float(wave_num - 1)) * GameState.get_enemy_dmg_multiplier()

	max_hp = roundf(float(def["hp"]) * hp_scale)
	hp = max_hp
	max_shield = roundf(float(def.get("shield", 0.0)) * hp_scale)
	shield = max_shield
	armor = float(def["armor"]) + float(wave_num - 1) * 1.2 + float(GameState.selected_map_idx) * 4.0
	move_speed = float(def["speed"]) * GameState.get_enemy_speed_multiplier()
	contact_dmg = roundf(float(def["dmg"]) * dmg_scale)
	radius = float(def["radius"])
	xp_val = int(def["xp"])
	gold_val = int(def["gold"])
	base_color = def["color"]
	behavior = def["behavior"]
	attack_timer = randf_range(0.8, 2.0)
	skill_timer = randf_range(1.8, 3.2)

func setup_boss(boss_def: Dictionary, wave_num: int, pos: Vector2) -> void:
	is_boss = true
	enemy_id = boss_def["id"]
	enemy_name = boss_def["name"]
	boss_mechanic = boss_def["mechanic"]
	reward_weapon_id = boss_def.get("reward_weapon", "cannon_205_peony")
	var b_mult: float = float(GameState.get_current_difficulty_def().get("bounty_mult", 1.0))
	bounty_gold = int(float(boss_def.get("bounty", 500)) * b_mult)
	global_position = pos

	var wave_factor: float = maxf(0.85, 1.0 + (wave_num - 4) * 0.10) * GameState.get_enemy_hp_multiplier()
	max_hp = roundf(float(boss_def["hp"]) * wave_factor)
	hp = max_hp
	armor = float(boss_def["armor"])
	move_speed = float(boss_def["speed"]) * GameState.get_enemy_speed_multiplier()
	contact_dmg = roundf(float(boss_def["dmg"]) * GameState.get_enemy_dmg_multiplier())
	radius = float(boss_def["radius"])
	base_color = boss_def["color"]
	xp_val = 25
	gold_val = bounty_gold

	if boss_mechanic == "multi_segment":
		train_segments_left = 4
		segment_trail.clear()
		for i in range(4):
			segment_trail.append(pos - Vector2(i * 46.0, 0))
	elif boss_mechanic == "battleship_parts":
		battleship_parts = [
			{"name": "左舷副炮群", "offset": Vector2(-38, -28), "hp": max_hp * 0.25, "max_hp": max_hp * 0.25, "alive": true},
			{"name": "右舷导弹舱", "offset": Vector2(-38, 28), "hp": max_hp * 0.25, "max_hp": max_hp * 0.25, "alive": true},
			{"name": "中央300mm大和炮", "offset": Vector2(18, 0), "hp": max_hp * 0.32, "max_hp": max_hp * 0.32, "alive": true}
		]

func _process(delta: float) -> void:
	var bf: Node = get_parent().get_parent()
	if not bf or not bf.wave_active or not is_instance_valid(bf.player_tank):
		return
	var player: Node2D = bf.player_tank
	var target_pos: Vector2 = player.get_active_position()

	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
	if cement_slow_timer > 0.0:
		cement_slow_timer -= delta

	# 检查是否踩在地面水泥潭或火焰潭上
	for p in bf.fx_layer.puddles:
		if global_position.distance_to(p["pos"]) <= p["radius"] + radius:
			if p["type"] == "cement":
				cement_slow_timer = 0.5
			elif p["type"] == "fire":
				burn_stacks = max(burn_stacks, 2)

	# 灼烧持续伤害
	if burn_stacks > 0:
		burn_timer += delta
		if burn_timer >= 0.5:
			burn_timer = 0.0
			var b_dmg: float = burn_stacks * (8.0 + max_hp * 0.004)
			if GameState.synergy_counts.get("bio", 0) >= 4:
				b_dmg *= 1.8
			hp -= b_dmg
			bf.fx_layer.spawn_text(global_position, "-%d 灼烧" % int(b_dmg), Color(1.0, 0.5, 0.15), 0.85)
			if hp <= 0.0:
				_die(bf, false)
				return

	if stun_timer > 0.0:
		stun_timer -= delta
		queue_redraw()
		return

	var spd_mult: float = 0.42 if cement_slow_timer > 0.0 else 1.0
	var to_player: Vector2 = target_pos - global_position
	var dist: float = to_player.length()
	var dir: Vector2 = to_player.normalized() if dist > 1.0 else Vector2.RIGHT

	if is_boss:
		_process_boss_ai(delta, bf, player, target_pos, dir, dist, spd_mult)
	else:
		_process_regular_ai(delta, bf, player, target_pos, dir, dist, spd_mult)

	# 保持在竞技场边界内
	global_position.x = clampf(global_position.x, bf.arena_rect.position.x + radius, bf.arena_rect.end.x - radius)
	global_position.y = clampf(global_position.y, bf.arena_rect.position.y + radius, bf.arena_rect.end.y - radius)

	# 近身接触伤害与战车碾压判定
	var hit_dist: float = radius + (16.0 if player.is_human_mode else 30.0)
	if global_position.distance_to(target_pos) <= hit_dist:
		player.on_enemy_collision(self, delta)

	queue_redraw()

func _process_regular_ai(delta: float, bf: Node, _player: Node2D, target_pos: Vector2, dir: Vector2, dist: float, spd_mult: float) -> void:
	elite_pulse += delta * 4.0
	facing_angle = dir.angle()
	attack_timer -= delta
	skill_timer -= delta

	match behavior:
		"leap_hound": # 狂暴生化猎犬：接近玩家时红眼加速扑咬冲刺
			var leap_mult: float = 2.15 if dist < 175.0 else 1.0
			global_position += dir * move_speed * leap_mult * spd_mult * delta

		"shooter": # 沙漠机枪塔 / 酸液蜗牛
			if dist > 260.0:
				global_position += dir * move_speed * spd_mult * delta
			elif dist < 150.0:
				global_position -= dir * move_speed * 0.6 * spd_mult * delta
			if attack_timer <= 0.0:
				attack_timer = 2.1
				var col: Color = Color(0.45, 0.95, 0.25) if enemy_id == "acid_snail" else Color(1.0, 0.35, 0.25)
				bf.spawn_enemy_projectile(global_position, dir, 350.0, contact_dmg, col, 6.0)

		"sniper": # 远程狙击自行炮：拉出1.0秒红线瞄准后发射超高速穿甲弹
			if sniper_aim_timer > 0.0:
				sniper_aim_timer -= delta
				sniper_aim_dir = dir
				if sniper_aim_timer <= 0.0:
					SoundManager.play("cannon_light", 0.1, -2.0)
					bf.spawn_enemy_projectile(global_position, sniper_aim_dir, 720.0, contact_dmg * 1.35, Color(1.0, 0.15, 0.35), 7.5)
					attack_timer = 2.8
			else:
				if dist > 380.0:
					global_position += dir * move_speed * spd_mult * delta
				elif dist < 240.0:
					global_position -= dir * move_speed * 0.8 * spd_mult * delta
				if attack_timer <= 0.0:
					sniper_aim_timer = 0.95
					sniper_aim_dir = dir

		"mortar": # 迫击炮机械蟹：在玩家脚下呼叫高空轰炸预警圈
			var side_dir: Vector2 = dir.orthogonal() * 0.55 + (dir * 0.45 if dist > 280.0 else -dir * 0.3)
			global_position += side_dir.normalized() * move_speed * spd_mult * delta
			if attack_timer <= 0.0:
				attack_timer = 2.7
				var strike_pos: Vector2 = target_pos + Vector2(randf_range(-35, 35), randf_range(-35, 35))
				bf.fx_layer.spawn_mortar_strike(strike_pos, 68.0, contact_dmg * 1.25, 1.25)

		"shield_guard": # 电磁护盾卫士：顶盾推进并点射
			global_position += dir * move_speed * spd_mult * delta
			if attack_timer <= 0.0:
				attack_timer = 2.3
				bf.spawn_enemy_projectile(global_position, dir, 340.0, contact_dmg, Color(0.35, 0.80, 1.0), 6.5)

		"healer": # 诺亚战地维修蜂：寻找场上受伤的精英怪/Boss并为其回血！
			var heal_target: Node2D = null
			var best_score: float = -1.0
			for other in bf.enemies_container.get_children():
				if is_instance_valid(other) and other != self and other.hp < other.max_hp:
					var s: float = (5000.0 if other.is_boss else (1500.0 if other.is_elite else 200.0)) - global_position.distance_to(other.global_position)
					if s > best_score:
						best_score = s
						heal_target = other
			if is_instance_valid(heal_target):
				var to_ally: Vector2 = heal_target.global_position - global_position
				if to_ally.length() > 110.0:
					global_position += to_ally.normalized() * move_speed * spd_mult * delta
				else:
					global_position += to_ally.normalized().orthogonal() * move_speed * 0.7 * delta
				if attack_timer <= 0.0:
					attack_timer = 1.5
					var heal_amt: float = heal_target.max_hp * (0.04 if heal_target.is_boss else 0.12)
					heal_target.hp = minf(heal_target.max_hp, heal_target.hp + heal_amt)
					bf.fx_layer.spawn_laser_beam(global_position, heal_target.global_position, Color(0.3, 1.0, 0.5), 3.5)
					bf.fx_layer.spawn_text(heal_target.global_position, "+%d 维修!" % int(heal_amt), Color(0.35, 1.0, 0.55), 0.9)
			else:
				global_position += dir * move_speed * 0.7 * spd_mult * delta

		"emp_shooter": # 磁暴捕猎蛛：发射EMP减速电网弹
			if dist > 250.0:
				global_position += dir * move_speed * spd_mult * delta
			if attack_timer <= 0.0:
				attack_timer = 2.4
				bf.spawn_enemy_projectile(global_position, dir, 390.0, contact_dmg, Color(0.45, 0.85, 1.0), 7.5, "emp_web")

		"suicide", "toxic_suicide": # 自爆滚雷车 & 毒气自爆铁桶
			global_position += dir * move_speed * spd_mult * delta
			if dist <= radius + 32.0:
				if behavior == "toxic_suicide":
					bf.fx_layer.spawn_puddle(global_position, 85.0, "toxic", 4.5)
				bf.fx_layer.spawn_explosion(global_position, 72.0, base_color)
				SoundManager.play("explosion_small", 0.1, -2.0)
				_player.take_damage(contact_dmg, global_position)
				queue_free()

		"elite_tank": # ⚡【精英】自律杀戮重坦：扇形三连发主炮
			global_position += dir * move_speed * spd_mult * delta
			if attack_timer <= 0.0:
				attack_timer = 2.2
				for k in range(-1, 2):
					bf.spawn_enemy_projectile(global_position, dir.rotated(k * 0.20), 420.0, contact_dmg * 1.2, Color(1.0, 0.55, 0.15), 8.5)

		"elite_flamer": # ⚡【精英】炼狱喷火装甲车：高速追击+扇形火海
			global_position += dir * move_speed * spd_mult * delta
			if attack_timer <= 0.0:
				attack_timer = 0.95
				for k in range(-1, 2):
					bf.spawn_enemy_projectile(global_position, dir.rotated(k * 0.16), 340.0, contact_dmg * 0.85, Color(1.0, 0.38, 0.10), 8.0)

		"elite_mortar": # ⚡【精英】双联装导弹巨兽：三连迫击轰炸圈 + 自卫弹幕
			global_position += dir * move_speed * spd_mult * delta
			if attack_timer <= 0.0:
				attack_timer = 2.6
				for k in range(2):
					var m_pos: Vector2 = target_pos + Vector2(randf_range(-75, 75), randf_range(-75, 75))
					bf.fx_layer.spawn_mortar_strike(m_pos, 72.0, contact_dmg * 1.35, 1.3)
				for i in range(6):
					bf.spawn_enemy_projectile(global_position, Vector2.from_angle(TAU * i / 6.0), 310.0, contact_dmg * 0.9, Color(1.0, 0.75, 0.25), 7.0)

		"elite_blinker": # ⚡【精英】诺亚量子处决者：周期瞬移闪烁到玩家附近释放十字激光
			global_position += dir * move_speed * spd_mult * delta
			if skill_timer <= 0.0:
				skill_timer = 3.4
				var blink_pos: Vector2 = target_pos + Vector2.from_angle(randf() * TAU) * 145.0
				blink_pos.x = clampf(blink_pos.x, bf.arena_rect.position.x + 40, bf.arena_rect.end.x - 40)
				blink_pos.y = clampf(blink_pos.y, bf.arena_rect.position.y + 40, bf.arena_rect.end.y - 40)
				bf.fx_layer.spawn_laser_beam(global_position, blink_pos, Color(0.95, 0.3, 1.0), 5.0)
				global_position = blink_pos
				bf.fx_layer.spawn_text(global_position, "⚡量子跃迁!", Color(0.95, 0.4, 1.0), 1.1)
				for i in range(4):
					var ang: float = dir.angle() + i * (PI * 0.5)
					bf.spawn_enemy_projectile(global_position, Vector2.from_angle(ang), 460.0, contact_dmg * 1.15, Color(0.95, 0.3, 1.0), 8.0)

		_:
			global_position += dir * move_speed * spd_mult * delta

func _process_boss_ai(delta: float, bf: Node, player: Node2D, target_pos: Vector2, dir: Vector2, _dist: float, spd_mult: float) -> void:
	skill_timer -= delta
	attack_timer -= delta

	match boss_mechanic:
		"charge_plow": # ★ 杀人推土机
			if charge_windup > 0.0:
				charge_windup -= delta
				if charge_windup <= 0.0:
					is_charging = true
					skill_timer = 1.15
					SoundManager.play("cannon_light", 0.15, 0.0)
			elif is_charging:
				global_position += charge_dir * (move_speed * 3.1) * delta
				if skill_timer <= 0.0:
					is_charging = false
					skill_timer = 3.2
			else:
				facing_angle = lerp_angle(facing_angle, dir.angle(), 4.5 * delta)
				global_position += Vector2.from_angle(facing_angle) * move_speed * spd_mult * delta
				if skill_timer <= 0.0:
					charge_dir = dir
					facing_angle = charge_dir.angle()
					charge_windup = 0.75

		"bullet_ring": # ★ 加农水母
			facing_angle += delta * 1.8
			global_position += dir * move_speed * spd_mult * delta
			if skill_timer <= 0.0:
				skill_timer = 2.6
				for i in range(10):
					var ang: float = facing_angle + TAU * float(i) / 10.0
					bf.spawn_enemy_projectile(global_position, Vector2.from_angle(ang), 300.0, contact_dmg * 0.85, Color(0.3, 0.85, 1.0), 7.0)

		"burrow_shark": # ★★ 沙漠之鲛·沙鲨
			facing_angle = dir.angle()
			if is_burrowed:
				global_position += dir * (move_speed * 1.85) * delta
				if skill_timer <= 0.0:
					is_burrowed = false
					skill_timer = 4.0
					bf.fx_layer.spawn_explosion(global_position, 90.0, Color(0.85, 0.72, 0.45))
					for i in range(-2, 3):
						var ang: float = dir.angle() + float(i) * 0.22
						bf.spawn_enemy_projectile(global_position, Vector2.from_angle(ang), 420.0, contact_dmg, Color(0.3, 0.65, 1.0), 8.5)
			else:
				global_position += dir * move_speed * spd_mult * delta
				if skill_timer <= 0.0:
					is_burrowed = true
					skill_timer = 2.2
					bf.fx_layer.spawn_text(global_position, "沙鲨潜入沙底!", Color(0.95, 0.82, 0.45), 1.2)

		"flame_circle": # ★★ 臭鼬军团长
			var tangent: Vector2 = dir.orthogonal() * 0.65 + dir * 0.55
			facing_angle = tangent.angle()
			global_position += tangent.normalized() * move_speed * spd_mult * delta
			if skill_timer <= 0.0:
				skill_timer = 1.4
				bf.fx_layer.spawn_puddle(global_position, 65.0, "fire", 4.0)
				bf.spawn_enemy_projectile(global_position, dir, 440.0, contact_dmg * 0.9, Color(1.0, 0.45, 0.1), 7.5)

		"multi_segment": # ★★★ 百足装甲列车
			facing_angle = lerp_angle(facing_angle, dir.angle(), 3.2 * delta)
			var speed_boost: float = 1.0 + float(4 - train_segments_left) * 0.22
			global_position += Vector2.from_angle(facing_angle) * move_speed * speed_boost * spd_mult * delta
			for i in range(segment_trail.size()):
				var leader: Vector2 = global_position if i == 0 else segment_trail[i - 1]
				if segment_trail[i].distance_to(leader) > 44.0:
					segment_trail[i] = leader + (segment_trail[i] - leader).normalized() * 44.0
			if attack_timer <= 0.0:
				attack_timer = 1.6
				for i in range(train_segments_left):
					bf.spawn_enemy_projectile(segment_trail[i], (target_pos - segment_trail[i]).normalized(), 360.0, contact_dmg * 0.75)

		"emp_stealth": # ★★★ 掠夺王·戈麦斯
			facing_angle = dir.angle()
			global_position += dir * move_speed * spd_mult * delta
			if skill_timer <= 0.0:
				is_stealthed = not is_stealthed
				skill_timer = 2.8 if is_stealthed else 4.2
				if not is_stealthed:
					for i in range(-1, 2):
						bf.spawn_enemy_projectile(global_position, Vector2.from_angle(dir.angle() + i * 0.18), 520.0, contact_dmg * 1.35, Color(1.0, 0.85, 0.2), 9.5)

		"regen_acid": # ★★★★ 生化奇美拉
			facing_angle = dir.angle()
			global_position += dir * move_speed * spd_mult * delta
			if burn_stacks <= 0 and armor > -10.0:
				hp = minf(max_hp, hp + max_hp * 0.018 * delta)
			if skill_timer <= 0.0:
				skill_timer = 2.0
				for i in range(8):
					var ang: float = TAU * float(i) / 8.0 + randf_range(-0.1, 0.1)
					bf.spawn_enemy_projectile(global_position, Vector2.from_angle(ang), 340.0, contact_dmg * 0.9, Color(0.5, 1.0, 0.25), 8.0)

		"battleship_parts": # ★★★★ 陆地战舰·沙漠之舟 (三部位独立开火与破坏)
			facing_angle = lerp_angle(facing_angle, dir.angle(), 1.5 * delta)
			global_position += Vector2.from_angle(facing_angle) * move_speed * spd_mult * delta
			if skill_timer <= 0.0:
				skill_timer = 2.2
				for p in battleship_parts:
					if not p["alive"]:
						continue
					var p_world: Vector2 = global_position + p["offset"].rotated(facing_angle)
					if p["name"] == "左舷副炮群":
						for k in range(-1, 2):
							bf.spawn_enemy_projectile(p_world, dir.rotated(k * 0.18), 380.0, contact_dmg * 0.75)
					elif p["name"] == "右舷导弹舱":
						for k in range(4):
							bf.spawn_enemy_projectile(p_world, dir.rotated((k - 1.5) * 0.28), 340.0, contact_dmg * 0.85, Color(0.35, 0.85, 1.0))
					elif p["name"] == "中央300mm大和炮":
						SoundManager.play("cannon_heavy", 0.05, 1.0)
						bf.spawn_enemy_projectile(p_world, dir, 540.0, contact_dmg * 1.6, Color(1.0, 0.35, 0.1), 13.0)

		"magnet_laser", "noah_core": # ★★★★★ 重装帕鲁 & 灭世主脑·诺亚核心
			facing_angle += delta * 1.4
			global_position += dir * move_speed * spd_mult * delta
			# 引力牵引玩家
			if global_position.distance_to(target_pos) < 420.0:
				player.global_position += (global_position - target_pos).normalized() * 55.0 * delta
			if skill_timer <= 0.0:
				skill_timer = 1.8 if boss_mechanic == "noah_core" else 2.4
				var spokes: int = 12 if boss_mechanic == "noah_core" else 8
				for i in range(spokes):
					var ang: float = facing_angle + TAU * float(i) / float(spokes)
					bf.spawn_enemy_projectile(global_position, Vector2.from_angle(ang), 390.0, contact_dmg, Color(1.0, 0.25, 0.65), 8.5)

func take_damage(raw_dmg: float, is_crit: bool, effect: String, hit_pos: Vector2, is_main_cannon: bool = false) -> void:
	var bf: Node = get_parent().get_parent()
	if not bf:
		return

	# 1. 推土机正面铲刀减伤 65%
	var mult: float = 1.0
	if is_boss and boss_mechanic == "charge_plow":
		var hit_dir: Vector2 = (hit_pos - global_position).normalized()
		var forward: Vector2 = Vector2.from_angle(facing_angle)
		if hit_dir.dot(forward) > 0.35 and effect != "laser":
			mult *= 0.35
			bf.fx_layer.spawn_text(global_position, "正面铲刀格挡!", Color(0.75, 0.8, 0.85), 0.9)

	# 2. 沙鲨潜沙状态减伤 (声波与高爆主炮除外)
	if is_boss and is_burrowed and effect != "sonic_wave" and not is_main_cannon:
		mult *= 0.30

	# 3. 猎人对赏金首额外增伤
	if is_boss:
		mult *= (1.0 + GameState.bonus_stats.get("boss_dmg_pct", 0.0))

	# 4. 红牡丹残血必暴 & 生化酸火6件暴击加成
	if not is_crit and hp < max_hp * 0.5 and is_main_cannon:
		for w in GameState.equipped_weapons:
			if w["id"] == "cannon_205_peony":
				is_crit = true
				break
	if not is_crit and (burn_stacks > 0 or armor < 0.0 or cement_slow_timer > 0.0) and GameState.synergy_counts.get("bio", 0) >= 6:
		if randf() < 0.30:
			is_crit = true

	if is_crit:
		mult *= 2.1

	# 5. 特殊状态叠加 (水泥破甲、强酸腐蚀、火焰灼烧、超武炼狱黑死病、电击麻痹)
	if effect == "cement" or effect == "gaia_nuke":
		cement_slow_timer = 4.5
		armor -= 28.0
	elif effect == "plague_fire":
		armor = maxf(-60.0, armor - 18.0)
		burn_stacks = min(20, burn_stacks + 3)
	elif effect == "acid":
		var strip: float = 12.0 if GameState.synergy_counts.get("bio", 0) >= 4 else 6.0
		armor = maxf(-45.0, armor - strip)
		bf.fx_layer.spawn_text(global_position + Vector2(0, -16), "酸蚀破甲!", Color(0.5, 1.0, 0.3), 0.85)
	elif effect == "burn":
		burn_stacks = min(15, burn_stacks + 1)
	elif effect == "electric" or effect == "omega_laser":
		if boss_mechanic == "bullet_ring" or effect == "omega_laser":
			stun_timer = maxf(stun_timer, 0.9)
			mult *= 1.35
	elif effect == "sonic_wave":
		stun_timer = 1.2
		is_burrowed = false

	# 6. 护甲减伤公式 (支持负护甲增伤！激光、天谴轨道炮与音波无视正护甲)
	var eff_armor: float = armor
	if effect in ["laser", "omega_laser", "sonic_wave"] and eff_armor > 0.0:
		eff_armor = 0.0
	elif is_main_cannon and eff_armor > 0.0:
		eff_armor *= 0.65 # 主炮自带35%穿甲

	var armor_mitigation: float = eff_armor / (absf(eff_armor) + 50.0)
	var final_dmg: float = maxf(1.0, raw_dmg * mult * (1.0 - armor_mitigation))

	# 6.5 电磁护盾卫士独立护盾条结算 (电击/激光造成 300% 破盾伤害!)
	if shield > 0.0:
		var shield_mult: float = 3.0 if effect in ["electric", "laser", "omega_laser", "sonic_wave"] else 0.55
		var s_dmg: float = final_dmg * shield_mult
		if s_dmg >= shield:
			final_dmg = maxf(0.0, (s_dmg - shield) / shield_mult)
			shield = 0.0
			bf.fx_layer.spawn_text(global_position, "⚡护盾击碎!", Color(0.4, 0.9, 1.0), 1.1)
		else:
			shield -= s_dmg
			hit_flash_timer = 0.06
			bf.fx_layer.spawn_text(global_position, "-%d 护盾" % int(s_dmg), Color(0.35, 0.85, 1.0), 0.9)
			return

	# 7. 沙漠之舟三部位破坏独立结算
	if is_boss and boss_mechanic == "battleship_parts":
		for p in battleship_parts:
			if p["alive"]:
				var p_world: Vector2 = global_position + p["offset"].rotated(facing_angle)
				if hit_pos.distance_to(p_world) <= 32.0:
					p["hp"] -= final_dmg
					if p["hp"] <= 0.0:
						p["alive"] = false
						hp -= max_hp * 0.15
						bf.fx_layer.spawn_explosion(p_world, 85.0, Color(1.0, 0.4, 0.1))
						bf.fx_layer.spawn_text(p_world, "部位破坏：【%s】!" % p["name"], Color(1.0, 0.25, 0.2), 1.4)
						SoundManager.play("explosion_large", 0.05, 2.0)
					break

	hp -= final_dmg
	hit_flash_timer = 0.08

	# 8. 百足装甲列车车厢脱落爆宝箱机制
	if is_boss and boss_mechanic == "multi_segment" and train_segments_left > 0:
		var threshold: float = float(train_segments_left - 1) * 0.25 * max_hp
		if hp <= threshold and segment_trail.size() >= train_segments_left:
			var drop_pos: Vector2 = segment_trail[train_segments_left - 1]
			train_segments_left -= 1
			bf.fx_layer.spawn_explosion(drop_pos, 75.0, Color(1.0, 0.6, 0.2))
			bf.spawn_drop("buried_chest", 1, drop_pos)
			bf.fx_layer.spawn_text(drop_pos, "列车车厢击毁! 掉落宝箱!", Color(1.0, 0.88, 0.2), 1.3)

	var txt_col: Color = Color(1.0, 0.30, 0.22) if is_crit else Color(0.96, 0.96, 0.96)
	var txt_str: String = "%d!" % int(final_dmg) if is_crit else "%d" % int(final_dmg)
	bf.fx_layer.spawn_text(global_position, txt_str, txt_col, 1.28 if is_crit else 0.95)

	if hp <= 0.0:
		_die(bf, is_crit and is_main_cannon)

func _die(bf: Node, crit_main_kill: bool) -> void:
	GameState.total_kills += 1
	# 红狼传人：主炮暴击击杀返还1发弹药
	if crit_main_kill and GameState.selected_hunter_id == "lone_wolf" and is_instance_valid(bf.player_tank):
		bf.player_tank.refill_all_ammo(1)

	# 明奇学徒：元素击杀20%概率生成带电僵尸激光电击周围敌人
	if GameState.bonus_stats.get("zombie_summon", false) and randf() < 0.22:
		bf.trigger_zombie_shock(global_position)

	# 【超武·炼狱黑死病】尸爆传染效果：处于酸蚀或灼烧状态的敌人死亡时引发毒火尸爆！
	if burn_stacks > 0 and armor < 0.0:
		for w in GameState.equipped_weapons:
			if w["id"] == "evo_plague_inferno":
				bf.fx_layer.spawn_explosion(global_position, 95.0, Color(0.45, 1.0, 0.25))
				for other in bf.enemies_container.get_children():
					if is_instance_valid(other) and other != self and global_position.distance_to(other.global_position) <= 105.0:
						other.burn_stacks = min(20, other.burn_stacks + 3)
						other.armor = maxf(-60.0, other.armor - 12.0)
				break

	if is_boss:
		bf.on_wanted_boss_defeated(self)
	else:
		if behavior == "toxic_suicide":
			bf.fx_layer.spawn_puddle(global_position, 85.0, "toxic", 4.5)
		bf.spawn_drop("scrap", xp_val, global_position)
		if is_elite:
			bf.spawn_drop("sp_kit", 1, global_position + Vector2(16, 0))
			if randf() < 0.50:
				bf.spawn_drop("buried_chest", 1, global_position + Vector2(-16, 0))
		elif randf() < 0.12:
			bf.spawn_drop("sp_kit", 1, global_position + Vector2(12, 0))
		if GameState.bonus_stats.get("bio_devour", false) and randf() < 0.16:
			bf.spawn_drop("bio_meat", 1, global_position + Vector2(-12, 0))

	bf.fx_layer.spawn_explosion(global_position, radius * 1.8, base_color)
	queue_free()

func _draw() -> void:
	var c: Color = Color.WHITE if hit_flash_timer > 0.0 else base_color
	if is_stealthed:
		c.a = 0.32

	if is_boss:
		_draw_boss(c)
	else:
		_draw_regular(c)

	# 绘制敌人血条、护盾条与护甲状态
	if hp < max_hp or shield > 0.0 or is_boss or is_elite:
		var bw: float = maxf(32.0, radius * 1.8)
		var bh: float = 6.0 if (is_boss or is_elite) else 4.0
		var by: float = -radius - 14.0
		draw_rect(Rect2(-bw * 0.5, by, bw, bh), Color(0.1, 0.1, 0.1, 0.85))
		var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
		var bar_col: Color = Color(0.95, 0.22, 0.20) if is_boss else (Color(1.0, 0.78, 0.15) if is_elite else Color(0.95, 0.45, 0.20))
		draw_rect(Rect2(-bw * 0.5, by, bw * ratio, bh), bar_col)
		if shield > 0.0 and max_shield > 0.0:
			var s_ratio: float = clampf(shield / max_shield, 0.0, 1.0)
			draw_rect(Rect2(-bw * 0.5, by - 5.0, bw * s_ratio, 4.0), Color(0.30, 0.85, 1.0))
		if armor < 0.0:
			draw_string(ThemeDB.fallback_font, Vector2(-bw * 0.5, by - 6), "酸蚀%d" % int(armor), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 1.0, 0.3))

func _draw_regular(c: Color) -> void:
	# 狙击手激光红线预警
	if sniper_aim_timer > 0.0:
		draw_line(Vector2.ZERO, sniper_aim_dir * 650.0, Color(1.0, 0.12, 0.25, 0.80), 2.5)

	# 精英怪脚下金色脉冲光环与名称
	if is_elite:
		var r_aura: float = radius + 6.0 + sin(elite_pulse) * 2.5
		draw_arc(Vector2.ZERO, r_aura, 0.0, TAU, 24, Color(1.0, 0.82, 0.20, 0.85), 2.5)
		draw_string_outline(ThemeDB.fallback_font, Vector2(-42, -radius - 20), enemy_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(-42, -radius - 20), enemy_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.88, 0.25))

	# 电磁护盾外圈
	if shield > 0.0:
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 20, Color(0.35, 0.85, 1.0, 0.85), 2.5)

	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	var en_tex: Texture2D = GameData.get_enemy_tex(enemy_id)
	if en_tex != null:
		var t_sz: Vector2 = en_tex.get_size()
		var max_d: float = radius * (2.65 if is_elite else 2.55)
		var m_max: float = maxf(1.0, maxf(t_sz.x, t_sz.y))
		var dw: float = max_d * (t_sz.x / m_max)
		var dh: float = max_d * (t_sz.y / m_max)
		var mod_c: Color = Color(2.2, 2.2, 2.2, 1.0) if hit_flash_timer > 0.0 else Color.WHITE
		if cement_slow_timer > 0.0 and hit_flash_timer <= 0.0:
			mod_c = Color(0.65, 0.78, 1.0, 1.0)
		draw_texture_rect(en_tex, Rect2(-dw * 0.5, -dh * 0.5, dw, dh), false, mod_c)
	elif is_elite or behavior in ["sniper", "mortar"]:
		draw_rect(Rect2(-radius, -radius * 0.8, radius * 2.0, radius * 1.6), Color(0.22, 0.22, 0.22))
		draw_rect(Rect2(-radius * 0.82, -radius * 0.65, radius * 1.64, radius * 1.3), c)
		draw_circle(Vector2.ZERO, radius * 0.45, c.darkened(0.25))
		draw_rect(Rect2(0, -4.0, radius * 1.3, 8.0), Color(0.85, 0.85, 0.85))
	elif behavior == "healer":
		draw_circle(Vector2.ZERO, radius, c)
		draw_rect(Rect2(-3, -radius * 0.6, 6, radius * 1.2), Color.WHITE)
		draw_rect(Rect2(-radius * 0.6, -3, radius * 1.2, 6), Color.WHITE)
	elif behavior in ["suicide", "toxic_suicide"]:
		draw_circle(Vector2.ZERO, radius, c)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.9, 0.2))
	else:
		draw_circle(Vector2.ZERO, radius, c)
		draw_rect(Rect2(2, -4, radius * 0.9, 8), c.darkened(0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_boss(c: Color) -> void:
	var boss_tex: Texture2D = GameData.get_boss_tex(enemy_id)

	# 1. 百足列车先绘制后方车厢
	if boss_mechanic == "multi_segment":
		for i in range(train_segments_left):
			var rel: Vector2 = segment_trail[i] - global_position
			if boss_tex != null:
				var seg_r: float = radius * 1.75
				draw_texture_rect(boss_tex, Rect2(rel.x - seg_r * 0.5, rel.y - seg_r * 0.32, seg_r, seg_r * 0.64), false, Color(0.82, 0.82, 0.82))
			else:
				draw_circle(rel, radius * 0.78, c.darkened(0.18))
			draw_arc(rel, radius * 0.78, 0.0, TAU, 20, Color(0.95, 0.85, 0.3, 0.75), 2.0)

	# 2. 沙鲨潜沙效果
	if is_burrowed:
		draw_circle(Vector2.ZERO, radius * 1.1, Color(0.65, 0.52, 0.32, 0.55))
		draw_arc(Vector2.ZERO, radius * 0.8, 0.0, TAU, 24, Color(0.85, 0.72, 0.45, 0.8), 3.0)
		return

	# 3. 推土机冲锋预警红线
	if charge_windup > 0.0:
		draw_line(Vector2.ZERO, charge_dir * 460.0, Color(1.0, 0.15, 0.15, 0.75), 4.0)

	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	if boss_tex != null:
		var b_sz: Vector2 = boss_tex.get_size()
		var max_d: float = radius * (3.25 if enemy_id == "boss_desert_boat" else 2.75)
		var m_max: float = maxf(1.0, maxf(b_sz.x, b_sz.y))
		var bw: float = max_d * (b_sz.x / m_max)
		var bh: float = max_d * (b_sz.y / m_max)
		var mod_b: Color = Color(2.2, 2.2, 2.2, 1.0) if hit_flash_timer > 0.0 else Color.WHITE
		if is_stealthed:
			mod_b.a = 0.35
		draw_texture_rect(boss_tex, Rect2(-bw * 0.5, -bh * 0.5, bw, bh), false, mod_b)
	else:
		# 绘制主体装甲回退几何
		draw_rect(Rect2(-radius, -radius * 0.85, radius * 2.0, radius * 1.7), Color(0.22, 0.20, 0.18))
		draw_rect(Rect2(-radius * 0.88, -radius * 0.72, radius * 1.76, radius * 1.44), c)
		draw_rect(Rect2(-radius * 0.88, -radius * 0.72, radius * 1.76, radius * 1.44), Color(1.0, 0.85, 0.25), false, 2.5)
		if boss_mechanic == "charge_plow":
			draw_rect(Rect2(radius * 0.75, -radius * 1.05, 14.0, radius * 2.1), Color(0.85, 0.88, 0.92))
		draw_circle(Vector2.ZERO, radius * 0.42, c.darkened(0.3))
		draw_rect(Rect2(0, -6, radius * 1.25, 12), Color(0.85, 0.82, 0.78))

	# 沙漠之舟三部位状态圈绘制
	if boss_mechanic == "battleship_parts":
		for p in battleship_parts:
			var p_col: Color = Color(1.0, 0.35, 0.2, 0.45) if p["alive"] else Color(0.15, 0.15, 0.15, 0.75)
			draw_circle(p["offset"], 16.0, p_col)
			draw_arc(p["offset"], 16.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.25) if p["alive"] else Color(0.4, 0.4, 0.4), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 赏金首头顶 WANTED 标识
	draw_string_outline(ThemeDB.fallback_font, Vector2(-60, -radius - 22), "★ WANTED: %s" % enemy_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color.BLACK)
	draw_string(ThemeDB.fallback_font, Vector2(-60, -radius - 22), "★ WANTED: %s" % enemy_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.2))
