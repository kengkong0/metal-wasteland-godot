extends Node2D
## 战场掉落物节点：废铁零件(XP)、赏金金币(G)、装甲维修包(SP)、战犬基因肉块、埋藏金属宝箱

var drop_type: String = "scrap" # "scrap", "gold", "sp_kit", "bio_meat", "buried_chest"
var value: int = 1
var magnetized: bool = false
var pulse_time: float = 0.0

func setup(p_type: String, p_val: int, pos: Vector2) -> void:
	drop_type = p_type
	value = p_val
	magnetized = false
	visible = true
	set_process(true)
	global_position = pos
	pulse_time = randf() * TAU

func _process(delta: float) -> void:
	var bf: Node = get_parent().get_parent()
	if not bf or not bf.wave_active or not bf.get("player_tank"):
		return
	pulse_time += delta * 4.5
	var player: Node2D = bf.player_tank
	var target_pos: Vector2 = player.get_active_position()
	var dist: float = global_position.distance_to(target_pos)

	var magnet_radius: float = GameState.pickup_range
	if drop_type == "buried_chest":
		magnet_radius = 52.0 # 宝箱需靠近开启

	if dist < magnet_radius:
		magnetized = true

	if magnetized:
		var pull_spd: float = 620.0 + (dist * 1.5)
		global_position = global_position.move_toward(target_pos, pull_spd * delta)
		if dist < 28.0:
			_collect(bf, player)
	queue_redraw()

func _collect(bf: Node, player: Node2D) -> void:
	match drop_type:
		"scrap":
			GameState.add_xp(value)
			GameState.add_gold(1)
		"gold":
			GameState.add_gold(value)
			SoundManager.play("coin", 0.12, -5.0)
		"sp_kit":
			player.heal_sp(GameState.max_sp * 0.12 + 18.0)
			bf.fx_layer.spawn_text(global_position, "+SP 装甲修复!", Color(0.3, 1.0, 0.5), 1.15)
			SoundManager.play("coin", 0.05, -2.0)
		"bio_meat":
			GameState.bonus_stats["flat_sp_bonus"] = GameState.bonus_stats.get("flat_sp_bonus", 0.0) + 4.0
			GameState.bonus_stats["reload_speed_pct"] = GameState.bonus_stats.get("reload_speed_pct", 0.0) + 0.008
			GameState.recalculate_stats()
			player.heal_sp(15.0)
			bf.fx_layer.spawn_text(global_position, "基因吞噬 SP+4!", Color(1.0, 0.45, 0.75), 1.1)
			SoundManager.play("coin", 0.08, -2.0)
		"buried_chest":
			var bonus_g: int = 22 + GameState.current_wave * 6
			GameState.add_gold(bonus_g)
			player.refill_all_ammo(5)
			var evos: Array = GameState.try_trigger_super_evolutions(true)
			if not evos.is_empty():
				player.sync_weapons_from_state()
			else:
				bf.fx_layer.spawn_text(global_position, "挖出埋藏箱 +%dG & 弹药!" % bonus_g, Color(1.0, 0.88, 0.2), 1.35)
			SoundManager.play("upgrade", 0.04, 1.0)
	if is_instance_valid(bf) and bf.has_method("recycle_drop"):
		bf.recycle_drop(self)
	else:
		queue_free()

func _draw() -> void:
	var s: float = 1.0 + sin(pulse_time) * 0.12
	match drop_type:
		"scrap":
			draw_circle(Vector2.ZERO, 9.0 * s, Color(0.55, 0.78, 0.98))
			draw_circle(Vector2.ZERO, 5.0 * s, Color(0.9, 0.98, 1.0))
		"gold":
			draw_circle(Vector2.ZERO, 10.0 * s, Color(0.98, 0.80, 0.15))
			draw_arc(Vector2.ZERO, 10.0 * s, 0.0, TAU, 16, Color(0.55, 0.35, 0.05), 2.0)
		"sp_kit":
			draw_rect(Rect2(-11, -11, 22, 22), Color(0.2, 0.78, 0.35))
			draw_rect(Rect2(-3, -8, 6, 16), Color.WHITE)
			draw_rect(Rect2(-8, -3, 16, 6), Color.WHITE)
		"bio_meat":
			draw_circle(Vector2.ZERO, 12.0 * s, Color(0.92, 0.32, 0.52))
			draw_circle(Vector2(3, -3), 4.5, Color.WHITE)
		"buried_chest":
			# 金属探测器雷达圈 + 黄金军火宝箱贴图
			var radar_r: float = 26.0 + fmod(pulse_time * 6.0, 24.0)
			draw_arc(Vector2.ZERO, radar_r, 0.0, TAU, 24, Color(1.0, 0.85, 0.2, 0.55), 2.2)
			var chest_tex: Texture2D = GameData.get_tex("drop_chest")
			if chest_tex != null:
				draw_texture_rect(chest_tex, Rect2(-24 * s, -18 * s, 48 * s, 36 * s), false)
			else:
				draw_rect(Rect2(-16, -12, 32, 24), Color(0.75, 0.52, 0.15))
				draw_rect(Rect2(-16, -12, 32, 24), Color(1.0, 0.90, 0.35), false, 2.5)
				draw_rect(Rect2(-4, -4, 8, 8), Color(1.0, 0.95, 0.5))
