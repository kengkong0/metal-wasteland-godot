extends Node2D
## 战场浮动伤害跳字、爆炸冲击波与地面水泥区域渲染节点

var effects: Array = []
var puddles: Array = []
var mortar_strikes: Array = []

func spawn_mortar_strike(pos: Vector2, radius: float, dmg: float, delay: float = 1.25) -> void:
	mortar_strikes.append({
		"pos": pos,
		"radius": radius,
		"dmg": dmg,
		"age": 0.0,
		"delay": delay
	})

func spawn_text(pos: Vector2, text: String, col: Color = Color.WHITE, scale_factor: float = 1.0) -> void:
	if text.begins_with("-") and not bool(GameState.get_setting("show_damage_numbers", true)):
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
		"type": puddle_type, # "cement" or "fire"
		"age": 0.0,
		"duration": duration
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

	var bf: Node = get_parent()
	if bf and bf.get("wave_active"):
		for i in range(mortar_strikes.size() - 1, -1, -1):
			var ms: Dictionary = mortar_strikes[i]
			ms["age"] += delta
			if ms["age"] >= ms["delay"]:
				spawn_explosion(ms["pos"], ms["radius"], Color(1.0, 0.40, 0.15))
				SoundManager.play("explosion_small", 0.1, -2.0)
				if is_instance_valid(bf.player_tank):
					var p_pos: Vector2 = bf.player_tank.get_active_position()
					if p_pos.distance_to(ms["pos"]) <= ms["radius"] + 18.0:
						bf.player_tank.take_damage(ms["dmg"], ms["pos"])
				mortar_strikes.remove_at(i)

	queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# 1. 绘制地面水泥潭 / 火焰区
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

	# 1.5 绘制迫击炮高空轰炸预警红圈
	for ms in mortar_strikes:
		var prog: float = clampf(ms["age"] / ms["delay"], 0.0, 1.0)
		draw_circle(ms["pos"], ms["radius"], Color(1.0, 0.15, 0.15, 0.18 + prog * 0.25))
		draw_arc(ms["pos"], ms["radius"], 0.0, TAU, 28, Color(1.0, 0.25, 0.20, 0.85), 2.5)
		draw_arc(ms["pos"], ms["radius"] * (1.0 - prog), 0.0, TAU, 24, Color(1.0, 0.88, 0.30, 0.90), 2.0)

	# 2. 绘制爆炸、激光束与跳字
	for e in effects:
		var t: float = clampf(e["age"] / e["duration"], 0.0, 1.0)
		if e["type"] == "explosion":
			var r: float = e["radius"] * pow(t, 0.45)
			var c: Color = e["color"]
			c.a = (1.0 - t) * 0.75
			draw_circle(e["pos"], r, c)
			draw_arc(e["pos"], r, 0.0, TAU, 32, Color(1.0, 0.92, 0.6, 1.0 - t), 3.0)
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
