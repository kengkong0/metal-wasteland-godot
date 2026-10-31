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

# --- 武器专属弹道视觉 (VFX) ---
# vfx_kind: tracer / shell / missile / flame / acid / scrap / tesla / laser /
#           evo_plasma / evo_omega / evo_nuke / evo_plague / evo_gaia / enemy
var vfx_kind: String = "tracer"
var rarity: int = 0
var vis_scale: float = 1.0
var trail: Array = []          # 世界坐标历史点 (用于曳光 / 激光 / 炮弹尾迹)
var trail_max: int = 6
var smoke_timer: float = 0.0
var spin: float = 0.0
var spin_speed: float = 0.0
var scrap_shape: int = 0

func setup_player_proj(pos: Vector2, dir: Vector2, p_spd: float, p_dmg: float, p_splash: float, p_effect: String, p_crit: bool, p_main: bool = false, p_pierce: int = 1, p_wid: String = "", p_rarity: int = 0) -> void:
	is_enemy = false
	age = 0.0
	lifetime = 2.8
	hit_targets.clear()
	homing_target = null
	visible = true
	set_process(true)
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

	# 武器专属弹道外观 + 星级体积成长 (★1 1.0x ➔ ★5 1.72x)
	rarity = p_rarity
	vis_scale = 1.0 + 0.18 * float(clampi(rarity, 0, 4))
	vfx_kind = _resolve_vfx_kind()
	trail.clear()
	smoke_timer = 0.0
	spin = randf_range(0.0, TAU)
	spin_speed = randf_range(-18.0, 18.0)
	scrap_shape = randi() % 3
	match vfx_kind:
		"tracer":
			trail_max = 4 + mini(rarity, 3)
		"shell", "evo_gaia":
			trail_max = 7
		"laser", "evo_omega":
			trail_max = 6
		"evo_plasma":
			trail_max = 8
		_:
			trail_max = 0
	if vfx_kind in ["flame", "evo_plague"]:
		color = Color(1.0, 0.42, 0.10) if vfx_kind == "flame" else Color(0.45, 1.0, 0.30)
	elif vfx_kind == "evo_plasma":
		color = Color(1.0, 0.20, 0.30)
	elif vfx_kind == "evo_omega":
		color = Color(0.85, 0.55, 1.0)
	elif vfx_kind == "laser":
		color = Color(0.40, 0.95, 1.0)
	elif vfx_kind == "tracer":
		if weapon_id == "sub_ciws_phalanx":
			color = Color(0.45, 1.0, 0.75)
		elif weapon_id == "mg_vulcan":
			color = Color(1.0, 0.70, 0.25)
	if is_crit and not is_main_cannon:
		color = color.lerp(Color(1.0, 0.30, 0.25), 0.45)

func _resolve_vfx_kind() -> String:
	var w_def: Dictionary = GameData.WEAPONS.get(weapon_id, {})
	if w_def.has("vfx"):
		return String(w_def["vfx"])
	match weapon_id:
		"evo_red_wolf":
			return "evo_plasma"
		"evo_omega_railgun":
			return "evo_omega"
		"evo_iron_curtain":
			return "evo_nuke"
		"evo_plague_inferno":
			return "evo_plague"
		"evo_gaia_nuke":
			return "evo_gaia"
		"sub_shotgun":
			return "scrap"
	match effect_type:
		"plasma_cluster":
			return "evo_plasma"
		"omega_laser":
			return "evo_omega"
		"gaia_nuke":
			return "evo_gaia"
		"homing":
			return "missile"
		"burn":
			return "flame"
		"plague_fire":
			return "evo_plague"
		"acid":
			return "shell" if is_main_cannon else "acid"
		"electric":
			return "tesla"
		"laser":
			return "laser"
	if is_main_cannon:
		return "shell"
	return "tracer"

func setup_enemy_proj(pos: Vector2, dir: Vector2, p_spd: float, p_dmg: float, p_col: Color = Color(1.0, 0.25, 0.35), p_rad: float = 8.5, p_eff: String = "") -> void:
	is_enemy = true
	age = 0.0
	hit_targets.clear()
	homing_target = null
	visible = true
	set_process(true)
	global_position = pos
	speed = p_spd
	velocity = dir.normalized() * speed
	rotation = velocity.angle()
	damage = p_dmg
	color = p_col
	radius = p_rad
	effect_type = p_eff
	lifetime = 4.0
	vfx_kind = "enemy"
	trail.clear()
	trail_max = 3
	vis_scale = 1.0

func _process(delta: float) -> void:
	var bf: Node = get_parent().get_parent()
	if not bf:
		queue_free()
		return
	if not bf.wave_active:
		return

	age += delta
	if age >= lifetime:
		_recycle_self(bf)
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
	spin += spin_speed * delta

	# 弹道拖尾历史点 & 导弹翻滚白烟
	if trail_max > 0:
		trail.push_front(global_position)
		while trail.size() > trail_max:
			trail.pop_back()
	if vfx_kind in ["missile", "evo_nuke", "flame", "acid", "evo_plague"]:
		smoke_timer -= delta
		if smoke_timer <= 0.0 and is_instance_valid(bf.fx_layer) and bf.fx_layer.has_method("spawn_smoke_puff"):
			var back: Vector2 = -velocity.normalized()
			match vfx_kind:
				"missile", "evo_nuke":
					smoke_timer = 0.035
					var puff_col: Color = Color(0.55, 1.0, 0.45, 0.55) if vfx_kind == "evo_nuke" else Color(0.92, 0.92, 0.90, 0.55)
					if rarity >= 2 or vfx_kind == "evo_nuke":
						# ★3+ 双股螺旋烟带
						var side: Vector2 = back.orthogonal() * sin(age * 22.0) * 7.0 * vis_scale
						bf.fx_layer.spawn_smoke_puff(global_position + back * 12.0 + side, 5.0 * vis_scale, puff_col, 0.55)
						bf.fx_layer.spawn_smoke_puff(global_position + back * 12.0 - side, 5.0 * vis_scale, puff_col, 0.55)
					else:
						bf.fx_layer.spawn_smoke_puff(global_position + back * 12.0, 5.5 * vis_scale, puff_col, 0.5)
				"acid":
					smoke_timer = 0.09
					bf.fx_layer.spawn_smoke_puff(global_position + back * 6.0, 3.0 * vis_scale, Color(0.55, 1.0, 0.30, 0.55), 0.35)
				_:
					smoke_timer = 0.07
					bf.fx_layer.spawn_smoke_puff(global_position + back * 8.0, 6.0 * vis_scale, Color(0.25, 0.20, 0.18, 0.35), 0.45)

	# 边界检测
	var rect: Rect2 = bf.arena_rect.grow(80.0)
	if not rect.has_point(global_position):
		_recycle_self(bf)
		return

	# 碰撞检测 (使用 2D 空间哈希网格 O(1) 邻域检索)
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
				_recycle_self(bf)
	else:
		var nearby_enemies: Array = bf.get_enemies_in_radius(global_position, radius) if bf.has_method("get_enemies_in_radius") else bf.enemies_container.get_children()
		for e in nearby_enemies:
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
	_spawn_hit_vfx(bf)

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

	# 4. 特斯拉电弧 / Ω泰坦天谴轨道炮 连锁闪电
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
		_recycle_self(bf)

func _recycle_self(bf: Node = null) -> void:
	if is_instance_valid(bf) and bf.has_method("recycle_projectile"):
		bf.recycle_projectile(self)
	else:
		queue_free()

func _spawn_hit_vfx(bf: Node) -> void:
	var fx: Node = bf.get("fx_layer")
	if not is_instance_valid(fx) or not fx.has_method("spawn_spark_shower"):
		return
	var dir: Vector2 = -velocity.normalized()
	match vfx_kind:
		"tracer", "scrap":
			fx.spawn_spark_shower(global_position, dir, Color(1.0, 0.85, 0.45), 3 + mini(rarity, 3))
		"shell", "evo_gaia", "evo_plasma":
			fx.spawn_spark_shower(global_position, dir, Color(1.0, 0.70, 0.30), 8 + rarity * 2)
			fx.spawn_metal_debris(global_position, Color(0.55, 0.42, 0.30), 4 + rarity)
			if splash_radius >= 80.0:
				fx.spawn_scorch(global_position, splash_radius * 0.55)
		"acid":
			fx.spawn_spark_shower(global_position, dir, Color(0.55, 1.0, 0.30), 5)
			if randf() < 0.25:
				fx.spawn_puddle(global_position, 22.0 + rarity * 4.0, "toxic_fx", 1.6)
		"flame", "evo_plague":
			if randf() < 0.12:
				fx.spawn_puddle(global_position, 26.0 + rarity * 4.0, "fire", 1.4)
		"tesla", "laser", "evo_omega":
			fx.spawn_spark_shower(global_position, dir, color.lightened(0.3), 6)
		"missile", "evo_nuke":
			fx.spawn_spark_shower(global_position, dir, Color(1.0, 0.65, 0.25), 6)

# ============================================================================
# 武器专属弹道绘制 (8 大形态 + 神话超武)
# ============================================================================
func _draw() -> void:
	var s: float = vis_scale
	# ★4+ 元素能量电晕
	if rarity >= 3 and vfx_kind != "enemy":
		var aura: Color = color
		aura.a = 0.22 + 0.08 * sin(age * 18.0)
		draw_circle(Vector2.ZERO, radius * s * 1.9, aura)

	match vfx_kind:
		"enemy":
			_draw_trail_line(radius * 1.1, Color(color.r, color.g, color.b, 0.35))
			draw_circle(Vector2.ZERO, radius * 1.35, Color(color.r, color.g, color.b, 0.30))
			draw_circle(Vector2.ZERO, radius, color)
			draw_circle(Vector2.ZERO, radius * 0.55, Color.WHITE)
		"tracer":
			_draw_tracer(s)
		"shell":
			_draw_shell(s, false)
		"missile":
			_draw_missile(s, false)
		"flame":
			_draw_flame(s, false)
		"acid":
			_draw_acid(s)
		"scrap":
			_draw_scrap(s)
		"tesla":
			_draw_tesla(s)
		"laser":
			_draw_laser(s, false)
		"evo_plasma":
			_draw_plasma(s)
		"evo_omega":
			_draw_laser(s * 1.4, true)
		"evo_nuke":
			_draw_missile(s, true)
		"evo_plague":
			_draw_flame(s, true)
		"evo_gaia":
			_draw_shell(s * 1.15, true)
		_:
			draw_circle(Vector2.ZERO, radius, color)

# 拖尾: 将世界坐标历史点转换为本地坐标绘制渐细光带
func _draw_trail_line(width: float, col: Color) -> void:
	if trail.size() < 2:
		return
	for i in range(trail.size() - 1):
		var t: float = 1.0 - float(i) / float(trail.size())
		var c: Color = col
		c.a = col.a * t
		draw_line(to_local(trail[i]), to_local(trail[i + 1]), c, maxf(1.0, width * t))

func _draw_tracer(s: float) -> void:
	# 高速发光曳光弹 (胶囊形)，中心白热
	var len: float = 14.0 * s
	var w: float = 3.2 * s
	_draw_trail_line(w * 1.6, Color(color.r, color.g, color.b, 0.55))
	if rarity >= 2:
		_draw_trail_line(w * 0.6, Color(1, 1, 1, 0.55))
	draw_line(Vector2(-len, 0), Vector2(len * 0.4, 0), Color(color.r, color.g, color.b, 0.45), w * 2.4)
	draw_line(Vector2(-len * 0.8, 0), Vector2(len * 0.45, 0), color, w)
	draw_line(Vector2(-len * 0.3, 0), Vector2(len * 0.5, 0), Color(1, 1, 0.95), w * 0.55)
	draw_circle(Vector2(len * 0.5, 0), w * 0.6, Color.WHITE)

func _draw_shell(s: float, gaia: bool) -> void:
	# 大口径穿甲炮弹: 合金弹体 + 尖锐弹头 + 紫铜弹带 + 马赫激波尾迹
	var L: float = 15.0 * s
	var H: float = 5.5 * s
	var body_col: Color = Color(0.55, 0.52, 0.48)
	var tip_col: Color = Color(1.0, 0.62, 0.22)
	if effect_type == "cement":
		body_col = Color(0.62, 0.62, 0.58)
		tip_col = Color(0.85, 0.85, 0.80)
	elif effect_type == "cluster":
		body_col = Color(0.42, 0.40, 0.25)
		tip_col = Color(1.0, 0.85, 0.20)
	elif effect_type == "acid":
		body_col = Color(0.25, 0.42, 0.30)
		tip_col = Color(0.55, 1.0, 0.35)
	if gaia:
		body_col = Color(0.30, 0.32, 0.20)
		tip_col = Color(0.65, 1.0, 0.30)
	if is_crit:
		tip_col = Color(1.0, 0.25, 0.25)
	# 尾迹热浪 + 激波环
	_draw_trail_line(H * 1.8, Color(1.0, 0.75, 0.40, 0.40))
	draw_circle(Vector2(-L * 1.1, 0), H * 1.3, Color(1.0, 0.55, 0.15, 0.45))
	draw_circle(Vector2(-L * 1.1, 0), H * 0.7, Color(1.0, 0.95, 0.70, 0.85))
	if rarity >= 2 or gaia:
		var ring_r: float = H * (1.6 + 0.6 * fmod(age * 6.0, 1.0))
		draw_arc(Vector2(-L * 1.5, 0), ring_r, PI * 0.5, PI * 1.5, 12, Color(1.0, 0.90, 0.70, 0.55), 1.5)
	# 弹体
	draw_rect(Rect2(-L, -H, L * 1.3, H * 2.0), body_col)
	draw_rect(Rect2(-L, -H, L * 1.3, H * 0.6), body_col.lightened(0.25))
	draw_rect(Rect2(-L * 0.55, -H, L * 0.18, H * 2.0), Color(0.75, 0.42, 0.20)) # 紫铜弹带
	draw_colored_polygon(PackedVector2Array([Vector2(L * 0.3, -H), Vector2(L * 1.05, 0), Vector2(L * 0.3, H)]), tip_col)
	if gaia:
		# 放射性三叶标志
		for k in range(3):
			var a0: float = k * TAU / 3.0 + age * 4.0
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a0) * H * 0.95, Vector2.from_angle(a0 + 0.7) * H * 0.95]), Color(0.1, 0.1, 0.05))
		draw_circle(Vector2.ZERO, H * 2.6, Color(0.55, 1.0, 0.30, 0.18))

func _draw_missile(s: float, nuke: bool) -> void:
	# 巡航导弹: 圆柱弹身 + 尖头 + 尾翼 + 摇曳尾焰
	var L: float = 11.0 * s
	var H: float = 3.6 * s
	var body: Color = Color(0.32, 0.36, 0.30) if nuke else Color(0.90, 0.92, 0.95)
	var flick: float = 0.75 + 0.35 * sin(age * 60.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-L, -H * 0.8), Vector2(-L - 9.0 * s * flick, 0), Vector2(-L, H * 0.8)]), Color(1.0, 0.55, 0.15, 0.9))
	draw_circle(Vector2(-L - 1.5, 0), H * 0.75, Color(1.0, 0.95, 0.65))
	draw_rect(Rect2(-L, -H, L * 1.6, H * 2.0), body)
	draw_colored_polygon(PackedVector2Array([Vector2(L * 0.6, -H), Vector2(L * 1.2, 0), Vector2(L * 0.6, H)]), Color(0.95, 0.85, 0.10) if nuke else Color(0.95, 0.25, 0.20))
	# 尾翼
	draw_colored_polygon(PackedVector2Array([Vector2(-L, -H), Vector2(-L * 0.55, -H), Vector2(-L * 1.05, -H * 2.2)]), body.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-L, H), Vector2(-L * 0.55, H), Vector2(-L * 1.05, H * 2.2)]), body.darkened(0.3))
	if nuke:
		draw_circle(Vector2.ZERO, H * 3.0, Color(0.55, 1.0, 0.30, 0.20))

func _draw_flame(s: float, plague: bool) -> void:
	# 翻滚膨胀火球团: 白炽 ➔ 炽橙 ➔ 暗红焦黑
	var t: float = clampf(age / maxf(0.05, lifetime), 0.0, 1.0)
	var r: float = radius * s * (0.55 + t * 1.7)
	var core: Color
	var mid: Color
	var outer: Color
	if plague:
		core = Color(0.92, 1.0, 0.80)
		mid = Color(0.45, 1.0, 0.25)
		outer = Color(0.10, 0.35, 0.08)
	else:
		core = Color(1.0, 0.97, 0.80)
		mid = Color(1.0, 0.55, 0.10)
		outer = Color(0.45, 0.10, 0.05)
	var a: float = 1.0 - t * 0.75
	var c_out: Color = mid.lerp(outer, t)
	c_out.a = 0.55 * a
	for k in range(3):
		var off: Vector2 = Vector2.from_angle(spin + k * 2.1) * r * 0.35
		draw_circle(off, r * (0.75 + 0.1 * k), c_out)
	var c_mid: Color = core.lerp(mid, clampf(t * 1.6, 0.0, 1.0))
	c_mid.a = 0.85 * a
	draw_circle(Vector2.ZERO, r * 0.65, c_mid)
	if t < 0.45:
		draw_circle(Vector2.ZERO, r * 0.32, Color(core.r, core.g, core.b, a))

func _draw_acid(s: float) -> void:
	# 剧毒强酸凝胶团 (半透明 + 气泡 + 高光)
	var r: float = radius * s
	var wob: float = 1.0 + 0.12 * sin(age * 30.0)
	draw_circle(Vector2(-r * 0.6, 0), r * 0.7, Color(0.35, 0.90, 0.20, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.25 * wob, 0.85 / wob))
	draw_circle(Vector2.ZERO, r, Color(0.40, 1.0, 0.25, 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(r * 0.25, -r * 0.3), r * 0.28, Color(0.90, 1.0, 0.85, 0.85))
	draw_arc(Vector2(-r * 0.3, r * 0.25), r * 0.22, 0.0, TAU, 8, Color(0.85, 1.0, 0.75, 0.8), 1.2)

func _draw_scrap(s: float) -> void:
	# 不规则旋转废铁破片 / 钢钉 / 滚珠
	var r: float = 4.5 * s
	_draw_trail_line(2.0 * s, Color(1.0, 0.75, 0.35, 0.35))
	draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
	var metal: Color = Color(0.62, 0.58, 0.52) if not is_crit else Color(1.0, 0.45, 0.35)
	match scrap_shape:
		0:
			draw_colored_polygon(PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(r * 0.8, -r), Vector2(r, r * 0.5), Vector2(-r * 0.4, r)]), metal)
		1:
			draw_line(Vector2(-r * 1.4, 0), Vector2(r * 1.4, 0), metal.lightened(0.2), 2.2 * s)
			draw_circle(Vector2(-r * 1.4, 0), 1.8 * s, metal)
		_:
			draw_circle(Vector2.ZERO, r * 0.8, metal)
			draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.3, Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 0.70, 0.30, 0.6))

func _draw_tesla(s: float) -> void:
	# 蓝紫高压分叉电弧 (每帧随机重绘的折线)
	var L: float = 18.0 * s
	var pts: PackedVector2Array = PackedVector2Array()
	var segs: int = 6
	for i in range(segs + 1):
		var x: float = -L + 2.0 * L * float(i) / float(segs)
		var jitter: float = 0.0 if (i == 0 or i == segs) else randf_range(-5.0, 5.0) * s
		pts.append(Vector2(x, jitter))
	draw_circle(Vector2(L, 0), 7.0 * s, Color(0.45, 0.70, 1.0, 0.30))
	draw_polyline(pts, Color(0.55, 0.65, 1.0, 0.55), 5.0 * s)
	draw_polyline(pts, Color(0.85, 0.95, 1.0), 1.8 * s)
	if rarity >= 2:
		var br: Vector2 = pts[3]
		draw_line(br, br + Vector2(randf_range(-6, 6), randf_range(-12, 12)) * s, Color(0.75, 0.85, 1.0, 0.8), 1.2)
	draw_circle(Vector2(L, 0), 3.5 * s, Color.WHITE)

func _draw_laser(s: float, omega: bool) -> void:
	# 高能光子光矛 / Ω 泰坦金紫天谴光柱
	var L: float = 46.0 * s
	var outer: Color = Color(0.75, 0.40, 1.0, 0.45) if omega else Color(color.r, color.g, color.b, 0.40)
	var mid: Color = Color(1.0, 0.85, 0.30) if omega else color
	_draw_trail_line(6.0 * s, outer)
	draw_line(Vector2(-L, 0), Vector2(L * 0.3, 0), outer, 11.0 * s)
	draw_line(Vector2(-L, 0), Vector2(L * 0.3, 0), mid, 5.0 * s)
	draw_line(Vector2(-L * 0.9, 0), Vector2(L * 0.32, 0), Color.WHITE, 2.0 * s)
	draw_circle(Vector2(L * 0.3, 0), 5.5 * s, Color(1, 1, 1, 0.9))
	if omega:
		for k in range(3):
			var x: float = -L + fmod(age * 900.0 + k * 30.0, L * 1.3)
			draw_arc(Vector2(x, 0), 9.0 * s, 0.0, TAU, 14, Color(1.0, 0.85, 0.35, 0.75), 1.6)

func _draw_plasma(s: float) -> void:
	# 绯红双星: 两颗深红等离子光球相互旋绕
	var r: float = 7.5 * s
	_draw_trail_line(r * 1.4, Color(1.0, 0.20, 0.30, 0.45))
	for k in range(2):
		var off: Vector2 = Vector2(0, sin(age * 28.0 + k * PI) * r * 1.1)
		draw_circle(off, r * 1.5, Color(1.0, 0.15, 0.25, 0.30))
		draw_circle(off, r, Color(1.0, 0.25, 0.30))
		draw_circle(off, r * 0.45, Color(1.0, 0.92, 0.90))
