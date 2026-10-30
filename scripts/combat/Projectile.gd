extends Node2D
## 通用弹道与制导导弹脚本
## 支持：主炮高爆弹、子母分裂弹、水泥减速破甲弹、追踪导弹、贯穿激光、火焰、酸液、电弧、敌方弹幕

var is_enemy: bool = false
var velocity: Vector2 = Vector2.ZERO
var speed: float = 650.0
var damage: float = 25.0
var splash_radius: float = 0.0
var pierce_left: int = 1
var effect_type: String = "" # "cement", "cluster", "homing", "burn", "acid", "electric", "laser"
var color: Color = Color(1.0, 0.85, 0.3)
var radius: float = 5.0
var lifetime: float = 2.8
var age: float = 0.0
var is_crit: bool = false
var is_main_cannon: bool = false
var hit_targets: Array = []
var homing_target: Node2D = null
var weapon_id: String = ""

func setup_player_proj(pos: Vector2, dir: Vector2, p_spd: float, p_dmg: float, p_splash: float, p_effect: String, p_crit: bool, p_main: bool = false, p_pierce: int = 1, p_wid: String = "") -> void:
	is_enemy = false
	global_position = pos
	speed = p_spd
	velocity = dir.normalized() * speed
	rotation = velocity.angle()
	damage = p_dmg
	splash_radius = p_splash
	effect_type = p_effect
	is_crit = p_crit
	is_main_cannon = p_main
	pierce_left = p_pierce
	weapon_id = p_wid

	if is_main_cannon:
		radius = 12.0
		color = Color(1.0, 0.55, 0.15) if not is_crit else Color(1.0, 0.25, 0.25)
	elif effect_type == "homing":
		radius = 8.5
		color = Color(0.35, 0.85, 1.0)
	elif effect_type == "acid":
		radius = 8.5
		color = Color(0.45, 1.0, 0.25)
	elif effect_type == "burn":
		radius = 10.0
		color = Color(1.0, 0.42, 0.10)
		lifetime = 0.65
	elif effect_type == "electric":
		radius = 8.5
		color = Color(0.4, 0.85, 1.0)
	else:
		radius = 6.5
		color = Color(1.0, 0.92, 0.45)

func setup_enemy_proj(pos: Vector2, dir: Vector2, p_spd: float, p_dmg: float, p_col: Color = Color(1.0, 0.25, 0.35), p_rad: float = 8.5, p_eff: String = "") -> void:
	is_enemy = true
	global_position = pos
	speed = p_spd
	velocity = dir.normalized() * speed
	rotation = velocity.angle()
	damage = p_dmg
	color = p_col
	radius = p_rad
	effect_type = p_eff
	lifetime = 4.0

func _process(delta: float) -> void:
	var bf: Node = get_parent().get_parent()
	if not bf:
		queue_free()
		return
	if not bf.wave_active:
		return

	age += delta
	if age >= lifetime:
		queue_free()
		return

	# 追踪导弹自动制导转向
	if not is_enemy and effect_type == "homing":
		if not is_instance_valid(homing_target) or homing_target.is_queued_for_deletion():
			homing_target = bf.get_highest_threat_enemy(global_position, 900.0)
		if is_instance_valid(homing_target):
			var desired: Vector2 = (homing_target.global_position - global_position).normalized() * speed
			velocity = velocity.lerp(desired, 7.5 * delta).normalized() * speed
			rotation = velocity.angle()

	global_position += velocity * delta

	# 边界检测
	var rect: Rect2 = bf.arena_rect.grow(80.0)
	if not rect.has_point(global_position):
		queue_free()
		return

	# 碰撞检测
	if is_enemy:
		var pt: Node2D = bf.player_tank
		if is_instance_valid(pt):
			var p_pos: Vector2 = pt.get_active_position()
			var hit_r: float = 16.0 if pt.is_human_mode else 28.0
			if global_position.distance_to(p_pos) <= (radius + hit_r):
				if effect_type == "emp_web":
					pt.apply_emp_slow(2.2)
				pt.take_damage(damage, global_position)
				bf.fx_layer.spawn_explosion(global_position, 22.0, color)
				queue_free()
	else:
		for e in bf.enemies_container.get_children():
			if not is_instance_valid(e) or e in hit_targets:
				continue
			var hit_dist: float = radius + float(e.radius)
			if global_position.distance_to(e.global_position) <= hit_dist:
				_on_hit_enemy(bf, e)
				break

	queue_redraw()

func _on_hit_enemy(bf: Node, target: Node2D) -> void:
	hit_targets.append(target)
	pierce_left -= 1

	# 1. 高爆溅射或单体伤害
	if splash_radius > 0.0:
		var actual_splash: float = splash_radius
		if GameState.synergy_counts.get("artillery", 0) >= 4:
			actual_splash *= 1.30
		bf.fx_layer.spawn_explosion(global_position, actual_splash, color)
		SoundManager.play("explosion_small" if actual_splash < 110.0 else "explosion_large", 0.1, -3.0)

		for e in bf.enemies_container.get_children():
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= actual_splash + e.radius:
				e.take_damage(damage, is_crit, effect_type, global_position, is_main_cannon)
				if not weapon_id.is_empty():
					GameState.record_weapon_damage(weapon_id, damage)
	else:
		target.take_damage(damage, is_crit, effect_type, global_position, is_main_cannon)
		if not weapon_id.is_empty():
			GameState.record_weapon_damage(weapon_id, damage)

	# 2. 水泥弹泥潭 / 盖亚石化核弹效果
	if effect_type == "cement" or effect_type == "gaia_nuke":
		var p_rad: float = 155.0 if effect_type == "gaia_nuke" else 95.0
		bf.fx_layer.spawn_puddle(global_position, p_rad, "cement", 5.0)

	# 3. 195mm / 盖亚巨炮 / 盖亚石化核弹 子母弹分裂效果
	if effect_type == "cluster" or effect_type == "gaia_nuke":
		var cnt: int = 8 if effect_type == "gaia_nuke" else 5
		for i in range(cnt):
			var ang: float = TAU * float(i) / float(cnt) + randf_range(-0.2, 0.2)
			var sub_pos: Vector2 = global_position + Vector2.from_angle(ang) * 65.0
			bf.fx_layer.spawn_explosion(sub_pos, 60.0, Color(1.0, 0.75, 0.2))
			for e in bf.enemies_container.get_children():
				if is_instance_valid(e) and sub_pos.distance_to(e.global_position) <= 62.0 + e.radius:
					var sub_dmg: float = damage * 0.42
					e.take_damage(sub_dmg, false, "cement" if effect_type == "gaia_nuke" else "cluster_sub", sub_pos, false)
					if not weapon_id.is_empty():
						GameState.record_weapon_damage(weapon_id, sub_dmg)

	# 4. 特斯拉电弧 / Ω诺亚天谴轨道炮 连锁闪电
	if effect_type == "electric" or effect_type == "omega_laser":
		var jumps: int = 10 if effect_type == "omega_laser" else 3
		var max_dist: float = 340.0 if effect_type == "omega_laser" else 210.0
		var last_pos: Vector2 = target.global_position
		for e in bf.enemies_container.get_children():
			if jumps <= 0:
				break
			if is_instance_valid(e) and e != target and last_pos.distance_to(e.global_position) <= max_dist:
				bf.fx_layer.spawn_laser_beam(last_pos, e.global_position, Color(1.0, 0.85, 0.25) if effect_type == "omega_laser" else Color(0.4, 0.9, 1.0), 4.5)
				var arc_dmg: float = damage * 0.80
				e.take_damage(arc_dmg, is_crit, "electric", last_pos, false)
				if not weapon_id.is_empty():
					GameState.record_weapon_damage(weapon_id, arc_dmg)
				last_pos = e.global_position
				jumps -= 1

	if pierce_left <= 0:
		queue_free()

func _draw() -> void:
	if is_enemy:
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.55, Color.WHITE)
	elif effect_type == "homing":
		# 导弹弹体 + 尾焰
		draw_rect(Rect2(-12, -4.5, 24, 9), Color(0.88, 0.92, 0.96))
		draw_circle(Vector2(10, 0), 4.5, Color(1.0, 0.3, 0.2))
		draw_circle(Vector2(-14, 0), 6.0, Color(1.0, 0.65, 0.15, 0.85))
	elif is_main_cannon:
		draw_rect(Rect2(-14, -6.0, 28, 12), color)
		draw_circle(Vector2(11, 0), 6.0, Color(1.0, 0.95, 0.75))
	else:
		draw_circle(Vector2.ZERO, radius, color)
