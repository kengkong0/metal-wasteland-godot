extends Node2D
## 战场浮动伤害跳字、爆炸冲击波、枪口火光、抛壳、烟雾、火花与地面水泥区域渲染节点

var effects: Array = []
var puddles: Array = []
var mortar_strikes: Array = []
var debris: Array = []

# --- 武器射击与命中粒子系统 ---
var muzzle_flashes: Array = [] # 枪口焰与炮口暴风
var casings: Array = []        # 抛出弹壳
var smoke_puffs: Array = []    # 导弹尾烟与爆炸青烟
var sparks: Array = []         # 击中金属火花
var scorches: Array = []       # 地面焦痕

func spawn_mortar_strike(pos: Vector2, radius: float, dmg: float, delay: float = 1.25) -> void:
	mortar_strikes.append({
		"pos": pos,
		"radius": radius,
		"dmg": dmg,
		"age": 0.0,
		"delay": delay
	})

func spawn_metal_debris(pos: Vector2, col: Color = Color(0.92, 0.78, 0.4), count: int = 6) -> void:
	if debris.size() > 140:
		return
	for i in range(count):
		var ang: float = randf_range(0.0, TAU)
		var spd: float = randf_range(85.0, 260.0)
		debris.append({
			"pos": pos,
			"vel": Vector2.from_angle(ang) * spd,
			"rot": randf_range(0.0, TAU),
			"rot_spd": randf_range(-14.0, 14.0),
			"size": randf_range(3.0, 5.5),
			"color": col.lerp(Color(0.95, 0.95, 0.95), randf_range(0.0, 0.4)),
			"age": 0.0,
			"duration": randf_range(0.42, 0.78)
		})

func spawn_shockwave(pos: Vector2, radius: float, col: Color = Color(0.35, 0.90, 1.0)) -> void:
	effects.append({
		"type": "shockwave",
		"pos": pos,
		"radius": radius,
		"color": col,
		"age": 0.0,
		"duration": 0.35
	})

func spawn_text(pos: Vector2, text: String, col: Color = Color.WHITE, scale_factor: float = 1.0) -> void:
	if text.begins_with("-") and not bool(GameState.get_setting("show_damage_numbers", true)):
		return
	if effects.size() > 95 and scale_factor <= 1.0:
		return
	effects.append({
		"type": "text",
		"pos": pos + Vector2(randf_range(-14.0, 14.0), -10.0),
		"vel": Vector2(randf_range(-25.0, 25.0), -65.0),
		"text": text,
		"color": col,
		"scale": scale_factor,
		"age": 0.0,
		"duration": 0.75
	})

func spawn_explosion(pos: Vector2, radius: float, col: Color = Color(1.0, 0.55, 0.15)) -> void:
	effects.append({
		"type": "explosion",
		"pos": pos,
		"radius": maxf(24.0, radius),
		"color": col,
		"age": 0.0,
		"duration": 0.32
	})

func spawn_laser_beam(from_pos: Vector2, to_pos: Vector2, col: Color = Color(0.3, 0.95, 1.0), width: float = 5.0) -> void:
	effects.append({
		"type": "beam",
		"from": from_pos,
		"to": to_pos,
		"color": col,
		"width": width,
		"age": 0.0,
		"duration": 0.18
	})

func spawn_puddle(pos: Vector2, radius: float, puddle_type: String, duration: float = 4.0) -> void:
	puddles.append({
		"pos": pos,
		"radius": radius,
		"type": puddle_type, # "cement" or "fire" or "toxic"
		"age": 0.0,
		"duration": duration
	})

# --- 武器专属枪口闪光与火光 ---
func spawn_muzzle_flash(pos: Vector2, dir: Vector2, kind: String = "cannon", scale_mul: float = 1.0) -> void:
	if muzzle_flashes.size() > 40:
		return
	var dur: float = 0.08
	match kind:
		"cannon": dur = 0.11
		"missile": dur = 0.14
		"flame": dur = 0.10
		"tesla": dur = 0.09
		"laser": dur = 0.07
		_: dur = 0.07
	muzzle_flashes.append({
		"pos": pos,
		"dir": dir.normalized(),
		"kind": kind,
		"scale": scale_mul,
		"age": 0.0,
		"duration": dur
	})

# --- 抛出金属/黄铜弹壳 ---
func spawn_casing(pos: Vector2, eject_dir: Vector2, is_cannon: bool = false) -> void:
	if casings.size() > 70:
		casings.remove_at(0)
	var ang: float = eject_dir.angle() + randf_range(-0.35, 0.35)
	var spd: float = randf_range(110.0, 210.0) if not is_cannon else randf_range(70.0, 140.0)
	casings.append({
		"pos": pos,
		"vel": Vector2.from_angle(ang) * spd,
		"rot": randf_range(0.0, TAU),
		"rot_spd": randf_range(-24.0, 24.0),
		"is_cannon": is_cannon,
		"age": 0.0,
		"duration": 1.6
	})

# --- 膨胀消散烟雾团 ---
func spawn_smoke_puff(pos: Vector2, radius: float = 6.0, col: Color = Color(0.85, 0.85, 0.85, 0.45), duration: float = 0.45) -> void:
	if smoke_puffs.size() > 110:
		return
	smoke_puffs.append({
		"pos": pos,
		"vel": Vector2(randf_range(-12.0, 12.0), randf_range(-18.0, -4.0)),
		"radius": radius,
		"col": col,
		"age": 0.0,
		"duration": duration
	})

# --- 命中高光飞溅火星 ---
func spawn_spark_shower(pos: Vector2, dir: Vector2, col: Color = Color(1.0, 0.9, 0.4), count: int = 8) -> void:
	if sparks.size() > 140:
		return
	var base_ang: float = dir.angle() + PI
	for i in range(count):
		var a: float = base_ang + randf_range(-0.95, 0.95)
		var spd: float = randf_range(120.0, 340.0)
		sparks.append({
			"pos": pos,
			"vel": Vector2.from_angle(a) * spd,
			"col": col,
			"size": randf_range(1.6, 3.2),
			"age": 0.0,
			"duration": randf_range(0.16, 0.32)
		})

# --- 地面焦黑弹坑痕迹 ---
func spawn_scorch(pos: Vector2, radius: float = 20.0) -> void:
	if scorches.size() > 45:
		scorches.remove_at(0)
	scorches.append({
		"pos": pos,
		"radius": radius,
		"rot": randf_range(0.0, TAU),
		"age": 0.0,
		"duration": 4.5
	})

func _process(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[i]
		e["age"] += delta
		if e["type"] == "text":
			e["pos"] += e["vel"] * delta
			e["vel"] *= 0.92
		if e["age"] >= e["duration"]:
			effects.remove_at(i)

	for i in range(puddles.size() - 1, -1, -1):
		puddles[i]["age"] += delta
		if puddles[i]["age"] >= puddles[i]["duration"]:
			puddles.remove_at(i)

	for i in range(debris.size() - 1, -1, -1):
		var d: Dictionary = debris[i]
		d["age"] += delta
		d["pos"] += d["vel"] * delta
		d["vel"] *= 0.91
		d["rot"] += d["rot_spd"] * delta
		if d["age"] >= d["duration"]:
			debris.remove_at(i)

	for i in range(muzzle_flashes.size() - 1, -1, -1):
		var mf: Dictionary = muzzle_flashes[i]
		mf["age"] += delta
		if mf["age"] >= mf["duration"]:
			muzzle_flashes.remove_at(i)

	for i in range(casings.size() - 1, -1, -1):
		var c: Dictionary = casings[i]
		c["age"] += delta
		if c["age"] < 0.28:
			c["pos"] += c["vel"] * delta
			c["vel"] *= 0.86
			c["rot"] += c["rot_spd"] * delta
			c["rot_spd"] *= 0.88
		if c["age"] >= c["duration"]:
			casings.remove_at(i)

	for i in range(smoke_puffs.size() - 1, -1, -1):
		var sp: Dictionary = smoke_puffs[i]
		sp["age"] += delta
		sp["pos"] += sp["vel"] * delta
		sp["vel"] *= 0.94
		if sp["age"] >= sp["duration"]:
			smoke_puffs.remove_at(i)

	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["age"] += delta
		s["pos"] += s["vel"] * delta
		s["vel"] *= 0.88
		if s["age"] >= s["duration"]:
			sparks.remove_at(i)

	for i in range(scorches.size() - 1, -1, -1):
		scorches[i]["age"] += delta
		if scorches[i]["age"] >= scorches[i]["duration"]:
			scorches.remove_at(i)

	var bf: Node = get_parent()
	if bf and bf.get("wave_active"):
		for i in range(mortar_strikes.size() - 1, -1, -1):
			var ms: Dictionary = mortar_strikes[i]
			ms["age"] += delta
			if ms["age"] >= ms["delay"]:
				spawn_explosion(ms["pos"], ms["radius"], Color(1.0, 0.40, 0.15))
				spawn_scorch(ms["pos"], ms["radius"] * 0.7)
				SoundManager.play("explosion_small", 0.1, -2.0)
				if is_instance_valid(bf.player_tank):
					var p_pos: Vector2 = bf.player_tank.get_active_position()
					if p_pos.distance_to(ms["pos"]) <= ms["radius"] + 18.0:
						bf.player_tank.take_damage(ms["dmg"], ms["pos"])
				mortar_strikes.remove_at(i)

	queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font

	# 0. 地面焦黑弹坑印记 (Scorches)
	for sc in scorches:
		var prog: float = clampf(sc["age"] / sc["duration"], 0.0, 1.0)
		var alpha: float = (1.0 - prog) * 0.42
		draw_set_transform(sc["pos"], sc["rot"], Vector2.ONE)
		draw_circle(Vector2.ZERO, sc["radius"], Color(0.06, 0.05, 0.04, alpha))
		draw_circle(Vector2.ZERO, sc["radius"] * 0.55, Color(0.02, 0.02, 0.02, alpha * 1.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 1. 地面水泥潭 / 火焰区 / 毒液区
	for p in puddles:
		var alpha: float = clampf(1.0 - (p["age"] / p["duration"]) * 0.6, 0.15, 0.85)
		if p["type"] == "cement":
			draw_circle(p["pos"], p["radius"], Color(0.55, 0.56, 0.52, 0.42 * alpha))
			draw_arc(p["pos"], p["radius"], 0.0, TAU, 28, Color(0.75, 0.75, 0.70, 0.7 * alpha), 2.0)
		elif p["type"] == "fire":
			draw_circle(p["pos"], p["radius"], Color(0.95, 0.32, 0.10, 0.38 * alpha))
		elif p["type"] == "toxic":
			draw_circle(p["pos"], p["radius"], Color(0.45, 0.95, 0.20, 0.36 * alpha))
			draw_arc(p["pos"], p["radius"], 0.0, TAU, 24, Color(0.65, 1.0, 0.30, 0.75 * alpha), 2.0)

	# 1.2 废土遗落黄铜弹壳 (Casings)
	for c in casings:
		var dt: float = clampf(c["age"] / c["duration"], 0.0, 1.0)
		var alpha: float = 1.0 if dt < 0.7 else (1.0 - (dt - 0.7) / 0.3)
		var l: float = 8.5 if c["is_cannon"] else 5.2
		var w: float = 4.0 if c["is_cannon"] else 2.2
		draw_set_transform(c["pos"], c["rot"], Vector2.ONE)
		# 阴影
		draw_rect(Rect2(-l * 0.5 + 1.5, -w * 0.5 + 1.5, l, w), Color(0.0, 0.0, 0.0, 0.35 * alpha))
		# 弹壳本体 (黄铜金属质感)
		draw_rect(Rect2(-l * 0.5, -w * 0.5, l, w), Color(0.92, 0.74, 0.25, alpha))
		# 底火凸缘
		draw_rect(Rect2(-l * 0.5, -w * 0.5, l * 0.26, w), Color(0.70, 0.48, 0.12, alpha))
		# 反光高光线
		draw_line(Vector2(-l * 0.35, -w * 0.22), Vector2(l * 0.38, -w * 0.22), Color(1.0, 0.96, 0.70, alpha), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 1.5 迫击炮高空轰炸预警红圈
	for ms in mortar_strikes:
		var prog: float = clampf(ms["age"] / ms["delay"], 0.0, 1.0)
		draw_circle(ms["pos"], ms["radius"], Color(1.0, 0.15, 0.15, 0.18 + prog * 0.25))
		draw_arc(ms["pos"], ms["radius"], 0.0, TAU, 28, Color(1.0, 0.25, 0.20, 0.85), 2.5)
		draw_arc(ms["pos"], ms["radius"] * (1.0 - prog), 0.0, TAU, 24, Color(1.0, 0.88, 0.30, 0.90), 2.0)

	# 1.8 尾焰青烟与漂浮烟雾 (Smoke Puffs)
	for sp in smoke_puffs:
		var t: float = clampf(sp["age"] / sp["duration"], 0.0, 1.0)
		var rad: float = sp["radius"] * (1.0 + t * 1.25)
		var c: Color = sp["col"]
		c.a *= (1.0 - t)
		draw_circle(sp["pos"], rad, c)

	# 2. 爆炸、激光束与跳字 (Effects)
	for e in effects:
		var t: float = clampf(e["age"] / e["duration"], 0.0, 1.0)
		if e["type"] == "explosion":
			var r: float = e["radius"] * pow(t, 0.45)
			var c: Color = e["color"]
			c.a = (1.0 - t) * 0.75
			draw_circle(e["pos"], r, c)
			draw_arc(e["pos"], r, 0.0, TAU, 32, Color(1.0, 0.92, 0.6, 1.0 - t), 3.0)
		elif e["type"] == "shockwave":
			var r: float = e["radius"] * pow(t, 0.4)
			var c: Color = e["color"]
			c.a = (1.0 - t) * 0.90
			draw_arc(e["pos"], r, 0.0, TAU, 32, c, 3.5 * (1.0 - t * 0.4))
		elif e["type"] == "beam":
			var c: Color = e["color"]
			c.a = 1.0 - t
			draw_line(e["from"], e["to"], c, e["width"] * (1.0 - t * 0.5))
			draw_line(e["from"], e["to"], Color(1, 1, 1, 1.0 - t), maxf(1.5, e["width"] * 0.4))
		elif e["type"] == "text":
			var c: Color = e["color"]
			c.a = 1.0 - pow(t, 1.8)
			var fsize: int = int(15.0 * e["scale"])
			draw_string_outline(font, e["pos"], e["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, 4, Color(0, 0, 0, c.a))
			draw_string(font, e["pos"], e["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, c)

	# 3. 飞溅金属碎屑零件与齿轮残片 (Debris)
	for d in debris:
		var dt: float = clampf(d["age"] / d["duration"], 0.0, 1.0)
		var c: Color = d["color"]
		c.a = 1.0 - dt
		var sz: float = d["size"] * (1.0 - dt * 0.3)
		draw_set_transform(d["pos"], d["rot"], Vector2.ONE)
		draw_rect(Rect2(-sz * 0.5, -sz * 0.5, sz, sz), c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 3.5 命中金属火花束 (Sparks)
	for s in sparks:
		var st: float = clampf(s["age"] / s["duration"], 0.0, 1.0)
		var sc_col: Color = s["col"]
		sc_col.a = 1.0 - st
		var v_len: float = s["vel"].length()
		var tail_vec: Vector2 = s["vel"].normalized() * minf(9.0, v_len * 0.035)
		draw_line(s["pos"] - tail_vec, s["pos"], sc_col, s["size"])

	# 4. 枪口暴风闪光 (Muzzle Flashes)
	for mf in muzzle_flashes:
		var t: float = clampf(mf["age"] / mf["duration"], 0.0, 1.0)
		var a: float = 1.0 - t
		var dir: Vector2 = mf["dir"]
		var sc: float = mf["scale"]
		draw_set_transform(mf["pos"], dir.angle(), Vector2.ONE * sc)
		match mf["kind"]:
			"cannon":
				var flame_pts := PackedVector2Array([
					Vector2(0, -7), Vector2(26, -15), Vector2(42, 0), Vector2(26, 15), Vector2(0, 7)
				])
				draw_colored_polygon(flame_pts, Color(1.0, 0.65, 0.15, 0.85 * a))
				var core_pts := PackedVector2Array([
					Vector2(0, -3), Vector2(16, -6), Vector2(26, 0), Vector2(16, 6), Vector2(0, 3)
				])
				draw_colored_polygon(core_pts, Color(1.0, 0.98, 0.85, a))
				draw_line(Vector2(6, -16), Vector2(6, 16), Color(1.0, 0.88, 0.35, a), 2.5)
			"missile":
				draw_circle(Vector2(-10, 0), 10.0 * (1.0 - t * 0.4), Color(1.0, 0.45, 0.15, 0.75 * a))
				draw_circle(Vector2(8, 0), 7.0, Color(1.0, 0.90, 0.45, 0.85 * a))
			"machinegun":
				draw_line(Vector2(-3, 0), Vector2(18, 0), Color(1.0, 0.98, 0.70, a), 3.0)
				draw_line(Vector2(3, -11), Vector2(3, 11), Color(1.0, 0.85, 0.30, a), 2.2)
			"flame":
				var f_pts := PackedVector2Array([
					Vector2(0, -9), Vector2(20, -14), Vector2(32, 0), Vector2(20, 14), Vector2(0, 9)
				])
				draw_colored_polygon(f_pts, Color(1.0, 0.35, 0.06, 0.75 * a))
				draw_circle(Vector2(8, 0), 7.0, Color(1.0, 0.85, 0.20, a))
			"tesla":
				draw_circle(Vector2(5, 0), 13.0, Color(0.35, 0.85, 1.0, 0.55 * a))
				draw_line(Vector2(0, -13), Vector2(16, 0), Color(0.85, 1.0, 1.0, a), 2.2)
				draw_line(Vector2(0, 13), Vector2(16, 0), Color(0.85, 1.0, 1.0, a), 2.2)
			"laser":
				draw_line(Vector2(-4, 0), Vector2(28, 0), Color(1.0, 0.35, 0.90, a), 3.2)
				draw_line(Vector2(4, -8), Vector2(4, 8), Color(0.55, 0.92, 1.0, a), 2.0)
			_:
				draw_circle(Vector2(4, 0), 8.0, Color(1.0, 0.85, 0.3, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
