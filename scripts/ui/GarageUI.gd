extends Control
## 《重装废土：赏金狂飙》 - 多拉姆整备车库 (1:1 参考《土豆兄弟 Brotato》商店布局)
## 布局：
## - 顶部栏：波次标题 + 大号金币/晶片图标 + 废土奇遇胶囊按钮 + 【刷新商店】大按钮
## - 左上方：4~5 张并排【立式军火商品卡片】(品质色边框、图标属性、合成角标、购买/锁定)
## - 左下方：土豆兄弟式【战车武器与底盘槽位网格 (Weapons & Slots)】+ 流派羁绊胶囊
## - 右侧栏：可视化【SP装甲条 & 载重条】+ 土豆兄弟式【双列属性表】+【赏金首通缉卡】+ 右下角【🚀出击】主按钮

signal start_next_wave

var shop_items: Array = []
var reroll_count: int = 0
var waxed_this_wave: bool = false
var dig_used_this_wave: bool = false

# --- 顶部栏引用 ---
var lbl_shop_title: Label
var lbl_gold_big: Label
var lbl_chips_big: Label
var lbl_event_toast: Label
var btn_reroll: Button

# --- 升级天赋浮层 (如有未领升级) ---
var perk_panel: PanelContainer
var perk_hbox: HBoxContainer

# --- 左上：立式商店卡片行 ---
var shop_cards_hbox: HBoxContainer

# --- 左下：底盘槽位与已装武器网格 ---
var lbl_slots_header: Label
var synergy_pills_hbox: HBoxContainer
var slots_cards_hbox: HBoxContainer

# --- 右侧栏：可视化进度条 + 属性表 + 通缉令 + 出发按钮 ---
var bar_garage_sp: ProgressBar
var lbl_garage_sp: Label
var bar_garage_weight: ProgressBar
var style_weight_fill: StyleBoxFlat
var lbl_garage_weight: Label
var stats_list_vbox: VBoxContainer
var wanted_box_vbox: VBoxContainer
var btn_launch: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg_tex := TextureRect.new()
	bg_tex.texture = GameData.get_tex("terrain_garage")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_TILE
	bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_tex)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.10, 0.90)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# =========================================================================
	# 1. 顶部导航与货币刷新栏 (土豆兄弟商店顶部风格)
	# =========================================================================
	var top_panel := _make_styled_panel(Color(0.14, 0.14, 0.17), Color(0.85, 0.58, 0.22), 8)
	root_vbox.add_child(top_panel)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 4)
	top_panel.add_child(top_vbox)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_vbox.add_child(top_hbox)

	lbl_shop_title = _make_outlined_label("🛒 多拉姆整备商店 (第 1 波)", 22, Color(1.0, 0.90, 0.32))
	top_hbox.add_child(lbl_shop_title)

	lbl_gold_big = _make_outlined_label("💰 0 G", 24, Color(1.0, 0.85, 0.20))
	top_hbox.add_child(lbl_gold_big)

	lbl_chips_big = _make_outlined_label("💎 0", 18, Color(0.42, 0.95, 1.0))
	top_hbox.add_child(lbl_chips_big)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(top_spacer)

	# 奇遇快捷胶囊按钮
	var btn_soda := Button.new()
	btn_soda.text = "🥤冷饮(15G)"
	btn_soda.custom_minimum_size = Vector2(96, 36)
	btn_soda.pressed.connect(_on_vending_machine)
	top_hbox.add_child(btn_soda)

	var btn_dig := Button.new()
	btn_dig.text = "📡挖宝(35G)"
	btn_dig.custom_minimum_size = Vector2(96, 36)
	btn_dig.pressed.connect(_on_metal_detector)
	top_hbox.add_child(btn_dig)

	var btn_wax := Button.new()
	btn_wax.text = "✨打蜡(25G)"
	btn_wax.custom_minimum_size = Vector2(96, 36)
	btn_wax.pressed.connect(_on_wax_tank)
	top_hbox.add_child(btn_wax)

	var btn_evo := Button.new()
	btn_evo.text = "🌟超武配方"
	btn_evo.custom_minimum_size = Vector2(96, 36)
	btn_evo.pressed.connect(_on_show_evo_recipes)
	top_hbox.add_child(btn_evo)

	btn_reroll = Button.new()
	btn_reroll.custom_minimum_size = Vector2(150, 38)
	btn_reroll.add_theme_font_size_override("font_size", 15)
	btn_reroll.pressed.connect(_on_reroll_pressed)
	top_hbox.add_child(btn_reroll)

	lbl_event_toast = _make_outlined_label("💡 提示：同名同星武器购买后自动【二合一升星】！剩余引擎载重100%转化为战车SP装甲！", 13, Color(0.95, 0.88, 0.48))
	lbl_event_toast.clip_text = true
	top_vbox.add_child(lbl_event_toast)

	# 猎人未领升级栏 (平时隐藏)
	perk_panel = _make_styled_panel(Color(0.20, 0.16, 0.10), Color(1.0, 0.82, 0.20), 6)
	perk_panel.visible = false
	root_vbox.add_child(perk_panel)
	perk_hbox = HBoxContainer.new()
	perk_hbox.add_theme_constant_override("separation", 10)
	perk_panel.add_child(perk_hbox)

	# =========================================================================
	# 2. 主体双栏 (左 70%：上方立式商品卡 + 下方武器槽位网格 | 右 30%：属性进度条 + 属性表 + 悬赏 + 出击)
	# =========================================================================
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(body_hbox)

	# --- 左侧主区 (商店卡片 + 武器与孔位网格) ---
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 2.45
	left_vbox.add_theme_constant_override("separation", 10)
	body_hbox.add_child(left_vbox)

	# 左上：4~5 张立式商店商品卡 (像土豆兄弟一样横向排列)
	shop_cards_hbox = HBoxContainer.new()
	shop_cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_cards_hbox.size_flags_stretch_ratio = 1.35
	shop_cards_hbox.add_theme_constant_override("separation", 10)
	left_vbox.add_child(shop_cards_hbox)

	# 左下：战车已装武器 & 底盘槽位网格面板 (像土豆兄弟左下角 Weapons 网格)
	var inv_panel := _make_styled_panel(Color(0.13, 0.13, 0.16), Color(0.42, 0.65, 0.88), 8)
	inv_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_panel.size_flags_stretch_ratio = 1.0
	left_vbox.add_child(inv_panel)

	var inv_vbox := VBoxContainer.new()
	inv_vbox.add_theme_constant_override("separation", 6)
	inv_panel.add_child(inv_vbox)

	var inv_top_row := HBoxContainer.new()
	inv_top_row.add_theme_constant_override("separation", 10)
	inv_vbox.add_child(inv_top_row)

	lbl_slots_header = _make_outlined_label("🔧 战车武器与底盘孔位 (0/4)", 16, Color(0.55, 0.88, 1.0))
	inv_top_row.add_child(lbl_slots_header)

	synergy_pills_hbox = HBoxContainer.new()
	synergy_pills_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	synergy_pills_hbox.alignment = BoxContainer.ALIGNMENT_END
	synergy_pills_hbox.add_theme_constant_override("separation", 6)
	inv_top_row.add_child(synergy_pills_hbox)

	var slots_scroll := ScrollContainer.new()
	slots_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inv_vbox.add_child(slots_scroll)

	slots_cards_hbox = HBoxContainer.new()
	slots_cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_cards_hbox.add_theme_constant_override("separation", 8)
	slots_scroll.add_child(slots_cards_hbox)

	# --- 右侧边栏 (属性进度条 + 土豆兄弟式双列属性表 + 通缉令海报 + 出击按钮) ---
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	right_vbox.add_theme_constant_override("separation", 8)
	body_hbox.add_child(right_vbox)

	# 右上：属性面板 (Stats Panel)
	var stats_panel := _make_styled_panel(Color(0.14, 0.14, 0.17), Color(0.55, 0.75, 0.55), 8)
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_stretch_ratio = 1.25
	right_vbox.add_child(stats_panel)

	var st_outer := VBoxContainer.new()
	st_outer.add_theme_constant_override("separation", 6)
	stats_panel.add_child(st_outer)

	var st_header := _make_outlined_label("📊 战车装甲与属性 (载重=SP)", 16, Color(0.45, 0.95, 0.62))
	st_outer.add_child(st_header)

	# 战车 SP 装甲可视化进度条
	var sp_res: Dictionary = _create_bar(Vector2(0, 22), Color(0.20, 0.80, 0.38), 13)
	bar_garage_sp = sp_res["bar"]
	lbl_garage_sp = sp_res["label"]
	st_outer.add_child(sp_res["container"])

	# 引擎载重可视化进度条
	var wt_res: Dictionary = _create_bar(Vector2(0, 20), Color(0.88, 0.58, 0.18), 12)
	bar_garage_weight = wt_res["bar"]
	style_weight_fill = wt_res["fill_style"]
	lbl_garage_weight = wt_res["label"]
	st_outer.add_child(wt_res["container"])

	var st_scroll := ScrollContainer.new()
	st_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	st_outer.add_child(st_scroll)

	stats_list_vbox = VBoxContainer.new()
	stats_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_list_vbox.add_theme_constant_override("separation", 4)
	st_scroll.add_child(stats_list_vbox)

	# 右中：猎人办事处悬赏通缉令紧凑卡
	var wanted_panel := _make_styled_panel(Color(0.19, 0.12, 0.12), Color(0.95, 0.32, 0.24), 8)
	right_vbox.add_child(wanted_panel)

	wanted_box_vbox = VBoxContainer.new()
	wanted_box_vbox.add_theme_constant_override("separation", 6)
	wanted_panel.add_child(wanted_box_vbox)

	# 右下：土豆兄弟式巨型【出发！】主按钮
	btn_launch = Button.new()
	btn_launch.custom_minimum_size = Vector2(0, 52)
	btn_launch.add_theme_font_size_override("font_size", 20)
	var launch_style := StyleBoxFlat.new()
	launch_style.bg_color = Color(0.18, 0.62, 0.28)
	launch_style.border_color = Color(0.45, 0.98, 0.55)
	launch_style.set_border_width_all(2)
	launch_style.set_corner_radius_all(8)
	btn_launch.add_theme_stylebox_override("normal", launch_style)
	var launch_hover := launch_style.duplicate()
	launch_hover.bg_color = Color(0.24, 0.74, 0.35)
	btn_launch.add_theme_stylebox_override("hover", launch_hover)
	btn_launch.add_theme_stylebox_override("focus", launch_hover)
	btn_launch.pressed.connect(_on_launch_pressed)
	right_vbox.add_child(btn_launch)

func open_garage() -> void:
	visible = true
	reroll_count = 0
	waxed_this_wave = false
	dig_used_this_wave = false
	lbl_event_toast.text = "💡 欢迎来到多拉姆商店！(支持键鼠点击或手柄摇杆选商品，[A]购买，[Y]刷新商店，[Start]出击下一波)"
	_roll_shop_items()
	refresh_all()
	if is_instance_valid(btn_launch):
		btn_launch.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		var mode: int = DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if event.is_action_pressed("gamepad_start"):
		get_viewport().set_input_as_handled()
		_on_launch_pressed()
	elif event.is_action_pressed("toggle_auto_main") and event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		_on_reroll_pressed()
	elif event.is_action_pressed("gamepad_select"):
		get_viewport().set_input_as_handled()
		_on_show_evo_recipes()

func refresh_all() -> void:
	GameState.recalculate_stats()
	lbl_shop_title.text = "🛒 多拉姆整备商店 (第 %d / %d 波)" % [GameState.current_wave, GameState.max_waves]
	lbl_gold_big.text = "💰 %d G" % GameState.gold
	lbl_chips_big.text = "💎 %d" % GameState.noah_chips

	_refresh_perk_bar()
	_refresh_shop_cards()
	_refresh_slots_and_weapons_grid()
	_refresh_right_stats_and_wanted()

	var next_w: int = GameState.current_wave + 1
	var boss_tag: String = " ⚠️[迎战赏金首]" if GameState.active_wanted_boss_id != "" else ""
	btn_launch.text = "🚀 出击第 %d 波 [Start]%s" % [next_w, boss_tag]
	if visible and get_viewport() and get_viewport().gui_get_focus_owner() == null and is_instance_valid(btn_launch):
		btn_launch.call_deferred("grab_focus")

func _refresh_perk_bar() -> void:
	for c in perk_hbox.get_children():
		c.queue_free()
	if GameState.pending_level_ups <= 0:
		perk_panel.visible = false
		return
	perk_panel.visible = true

	var title := _make_outlined_label("🎖️ 升级点(%d):" % GameState.pending_level_ups, 14, Color(1.0, 0.90, 0.30))
	perk_hbox.add_child(title)

	var shuffled: Array = GameData.LEVEL_PERKS.duplicate()
	shuffled.shuffle()
	for i in range(min(4, shuffled.size())):
		var p: Dictionary = shuffled[i]
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		btn.text = "★ %s (%s)" % [p["name"], p["desc"]]
		btn.pressed.connect(func():
			var st: String = p["stat"]
			GameState.bonus_stats[st] = GameState.bonus_stats.get(st, 0.0) + float(p["val"])
			GameState.pending_level_ups -= 1
			SoundManager.play("upgrade", 0.05, 0.0)
			refresh_all()
		)
		perk_hbox.add_child(btn)

func _roll_shop_items() -> void:
	var locked_items: Array = []
	for it in shop_items:
		if it.get("locked", false) and not it.get("bought", false):
			locked_items.append(it)
	shop_items = locked_items

	var total_slots: int = 5 if GameState.is_feature_unlocked("shop_5th_slot") else 4
	var w_keys: Array = GameData.WEAPONS.keys()
	var valid_w: Array = []
	for k in w_keys:
		if GameData.WEAPONS[k].get("is_evo", false):
			continue
		if String(k).begins_with("boss_") and GameState.current_wave < 10:
			continue
		if GameState.bonus_stats.get("no_main_cannon", false) and GameData.WEAPONS[k]["slot"] == "MAIN":
			continue
		valid_w.append(String(k))

	while shop_items.size() < total_slots:
		var is_last_slot: bool = (shop_items.size() == total_slots - 1)
		if not is_last_slot:
			var w_id: String = valid_w[randi() % valid_w.size()]
			var min_r: int = int(GameData.WEAPONS[w_id].get("min_rarity", 0))
			var max_r: int = mini(4, int(GameState.current_wave / 4) + 1)
			var rar: int = clampi(randi_range(min_r, max(min_r, max_r)), 0, 4)
			var base_c: int = int(GameData.WEAPONS[w_id].get("cost", 55))
			var price: int = int(base_c * pow(1.45, rar - min_r) * (1.0 + GameState.current_wave * 0.06) * (1.0 + GameState.bonus_stats.get("shop_price_pct", 0.0)))
			shop_items.append({"kind": "weapon", "id": w_id, "rarity": rar, "price": price, "bought": false, "locked": false})
		else:
			if randf() < 0.55:
				var e_keys: Array = GameData.ENGINES.keys()
				var e_id: String = String(e_keys[randi() % e_keys.size()])
				var price: int = int(GameData.ENGINES[e_id]["cost"] * (1.0 + GameState.current_wave * 0.05))
				shop_items.append({"kind": "engine", "id": e_id, "price": price, "bought": false, "locked": false})
			else:
				var c_keys: Array = GameData.C_UNITS.keys()
				var c_id: String = String(c_keys[randi() % c_keys.size()])
				var price: int = int(GameData.C_UNITS[c_id]["cost"] * (1.0 + GameState.current_wave * 0.05))
				shop_items.append({"kind": "c_unit", "id": c_id, "price": price, "bought": false, "locked": false})

# --- 左上：土豆兄弟风格 4~5 张立式商店商品卡 ---
func _refresh_shop_cards() -> void:
	for c in shop_cards_hbox.get_children():
		c.queue_free()

	var base_reroll: int = int((12 + GameState.current_wave * 3 + reroll_count * 6) * (1.0 - GameState.bonus_stats.get("reroll_discount", 0.0)))
	btn_reroll.text = "🔄 刷新 (%dG) [Y]" % max(2, base_reroll)

	for idx in range(shop_items.size()):
		var item: Dictionary = shop_items[idx]
		if item["bought"]:
			var sold_card := _make_styled_panel(Color(0.11, 0.11, 0.13, 0.6), Color(0.28, 0.28, 0.32), 8)
			sold_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sold_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var sold_lbl := _make_outlined_label("✅ 已购买", 16, Color(0.55, 0.60, 0.55))
			sold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sold_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sold_card.add_child(sold_lbl)
			shop_cards_hbox.add_child(sold_card)
			continue

		var rar: int = int(item.get("rarity", 2))
		var border_col: Color = GameData.RARITY_COLORS[clampi(rar, 0, 5)]
		if item["kind"] == "engine":
			border_col = Color(0.35, 0.90, 1.0)
		elif item["kind"] == "c_unit":
			border_col = Color(0.90, 0.50, 1.0)

		var card := _make_styled_panel(Color(0.17, 0.16, 0.19), border_col, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shop_cards_hbox.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)

		if item["kind"] == "weapon":
			var w_id: String = item["id"]
			var w_def: Dictionary = GameData.WEAPONS[w_id]
			var show_hints: bool = GameState.should_show_build_hints()
			var can_merge: bool = false
			for ew in GameState.equipped_weapons:
				if ew["id"] == w_id and ew.get("rarity", 0) == rar and rar < 4:
					can_merge = true
					break

			var slot_icon: String = "🔴主炮" if w_def["slot"] == "MAIN" else ("🟡副炮" if w_def["slot"] == "SUB" else "🔵S-E")
			var top_tag := _make_outlined_label("%s  ·  %s" % [slot_icon, GameData.RARITY_NAMES[rar]], 12, border_col)
			top_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(top_tag)

			var name_lbl := _make_outlined_label(w_def["name"], 16, border_col)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(name_lbl)

			# 提示角标 (可合成 / 超武配件 / 流派)
			if show_hints:
				var evo_partner: String = GameState.check_super_evolution_partner(w_id)
				if evo_partner != "":
					var evo_lbl := _make_outlined_label("🌟 超武配件 ➔ %s" % evo_partner.substr(0, 8), 12, Color(1.0, 0.88, 0.22))
					evo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					cv.add_child(evo_lbl)
				elif can_merge:
					var m_lbl := _make_outlined_label("🔥 同名同星：购买直接二合一！", 12, Color(0.40, 1.0, 0.55))
					m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					cv.add_child(m_lbl)

				var syn_names: Array = []
				for t in w_def.get("tags", []):
					if GameData.SYNERGIES.has(t):
						syn_names.append(GameData.SYNERGIES[t]["name"])
				if not syn_names.is_empty():
					var s_lbl := _make_outlined_label("🏷️ " + " / ".join(syn_names), 12, Color(0.75, 0.88, 1.0))
					s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					cv.add_child(s_lbl)

			# 核心三项图形化数值框
			var stat_box := _make_styled_panel(Color(0.11, 0.11, 0.13), Color(0.30, 0.30, 0.35), 4)
			cv.add_child(stat_box)
			var sv := VBoxContainer.new()
			sv.add_theme_constant_override("separation", 2)
			stat_box.add_child(sv)
			var dmg_val: float = float(w_def["base_dmg"]) * pow(1.65, rar)
			_add_mini_stat_row(sv, "💥 伤害", "%.0f" % dmg_val, Color(1.0, 0.55, 0.32))
			_add_mini_stat_row(sv, "⚖️ 重量", "%.1f t" % float(w_def["weight"]), Color(0.95, 0.85, 0.40))
			_add_mini_stat_row(sv, "⏱️ 冷却", "%.1f s" % float(w_def["cooldown"]), Color(0.55, 0.90, 1.0))

			var desc_lbl := _make_outlined_label(w_def["desc"], 12, Color(0.82, 0.82, 0.85))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cv.add_child(desc_lbl)

			_add_shop_card_buttons(cv, item, func():
				if GameState.gold < item["price"]:
					lbl_event_toast.text = "❌ 赏金 G 不足！"
					return
				if not GameState.can_equip_or_merge(w_id, rar):
					lbl_event_toast.text = "⚠️ 缺少【%s】空闲孔位！请先在下方点击槽位【改孔】或【拆卸】旧武器。" % w_def["slot"]
					return
				GameState.gold -= item["price"]
				item["bought"] = true
				var res: Dictionary = GameState.add_weapon_to_first_valid_slot(w_id, rar, true)
				var evos: Array = res.get("evos", [])
				if not evos.is_empty():
					SoundManager.play("mince_revive", 0.02, 3.0)
					lbl_event_toast.text = "🌟【隐藏超武合成！】[%s] + [%s] ➔ 进化为【%s】！" % [evos[0]["comp_a_name"], evos[0]["comp_b_name"], evos[0]["evo_name"]]
				elif res.get("merged", false):
					SoundManager.play("upgrade", 0.04, 2.0)
					lbl_event_toast.text = "✨ 二合一升星！【%s】晋升为 %s！" % [w_def["name"], GameData.RARITY_NAMES[res["new_rarity"]]]
				else:
					SoundManager.play("coin", 0.08, 0.0)
					lbl_event_toast.text = "🔧 已安装【%s】！" % w_def["name"]
				refresh_all()
			)

		elif item["kind"] == "engine":
			var e_def: Dictionary = GameData.ENGINES[item["id"]]
			var top_tag := _make_outlined_label("⚙️ 战车引擎核心", 12, border_col)
			top_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(top_tag)

			var name_lbl := _make_outlined_label(e_def["name"], 16, border_col)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(name_lbl)

			var stat_box := _make_styled_panel(Color(0.11, 0.11, 0.13), Color(0.30, 0.30, 0.35), 4)
			cv.add_child(stat_box)
			var sv := VBoxContainer.new()
			stat_box.add_child(sv)
			_add_mini_stat_row(sv, "⚖️ 最大载重", "%.1f t" % float(e_def["max_weight"]), Color(0.40, 1.0, 0.55))

			var desc_lbl := _make_outlined_label(e_def["desc"], 12, Color(0.85, 0.90, 0.95))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cv.add_child(desc_lbl)

			_add_shop_card_buttons(cv, item, func():
				if GameState.gold < item["price"]:
					lbl_event_toast.text = "❌ 赏金 G 不足！"
					return
				GameState.gold -= item["price"]
				GameState.equipped_engine_id = item["id"]
				item["bought"] = true
				SoundManager.play("upgrade", 0.05, 1.0)
				lbl_event_toast.text = "⚙️ 换装【%s】！最大载重与装甲大幅提升！" % e_def["name"]
				refresh_all()
			)

		elif item["kind"] == "c_unit":
			var c_def: Dictionary = GameData.C_UNITS[item["id"]]
			var top_tag := _make_outlined_label("💻 C装置火控电脑", 12, border_col)
			top_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(top_tag)

			var name_lbl := _make_outlined_label(c_def["name"], 16, border_col)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(name_lbl)

			var stat_box := _make_styled_panel(Color(0.11, 0.11, 0.13), Color(0.30, 0.30, 0.35), 4)
			cv.add_child(stat_box)
			var sv := VBoxContainer.new()
			stat_box.add_child(sv)
			_add_mini_stat_row(sv, "🚀 全弹CD", "%.1f s" % float(c_def["all_out_cd"]), Color(0.95, 0.65, 1.0))
			_add_mini_stat_row(sv, "⚖️ 自重", "%.1f t" % float(c_def["weight"]), Color(0.95, 0.85, 0.40))

			var desc_lbl := _make_outlined_label(c_def["desc"], 12, Color(0.92, 0.85, 0.96))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cv.add_child(desc_lbl)

			_add_shop_card_buttons(cv, item, func():
				if GameState.gold < item["price"]:
					lbl_event_toast.text = "❌ 赏金 G 不足！"
					return
				GameState.gold -= item["price"]
				GameState.equipped_c_unit_id = item["id"]
				item["bought"] = true
				SoundManager.play("upgrade", 0.05, 1.0)
				lbl_event_toast.text = "💻 已安装火控电脑【%s】！" % c_def["name"]
				refresh_all()
			)

func _add_shop_card_buttons(parent: VBoxContainer, item: Dictionary, on_buy: Callable) -> void:
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	parent.add_child(btn_row)

	var buy_btn := Button.new()
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.custom_minimum_size = Vector2(0, 38)
	buy_btn.text = "💰 %dG 购买" % int(item["price"])
	buy_btn.pressed.connect(on_buy)
	btn_row.add_child(buy_btn)

	if GameState.is_feature_unlocked("shop_lock"):
		var lock_btn := Button.new()
		lock_btn.custom_minimum_size = Vector2(56, 38)
		lock_btn.text = "🔓已锁" if item.get("locked", false) else "🔒锁"
		lock_btn.pressed.connect(func():
			item["locked"] = not item.get("locked", false)
			SoundManager.play("coin", 0.15, -4.0)
			_refresh_shop_cards()
		)
		btn_row.add_child(lock_btn)

# --- 左下：土豆兄弟风格武器与槽位卡片网格 ---
func _refresh_slots_and_weapons_grid() -> void:
	for c in synergy_pills_hbox.get_children():
		c.queue_free()
	for c in slots_cards_hbox.get_children():
		c.queue_free()

	var mod_cost: int = 0 if GameState.bonus_stats.get("free_slot_mod", false) else 25
	var mod_str: String = "免费改孔" if mod_cost == 0 else "改孔 %dG" % mod_cost
	lbl_slots_header.text = "🔧 战车槽位与武装 (%d / %d)  [%s]" % [
		GameState.equipped_weapons.size(), GameState.chassis_slots.size(), mod_str
	]

	# 流派羁绊彩色胶囊徽章
	if GameState.should_show_build_hints():
		for tag in GameData.SYNERGIES.keys():
			var cnt: int = GameState.synergy_counts.get(tag, 0)
			if cnt > 0:
				var s_def: Dictionary = GameData.SYNERGIES[tag]
				var pill := _make_styled_panel(Color(0.18, 0.18, 0.22), s_def["color"] if cnt >= 2 else Color(0.45, 0.45, 0.50), 4)
				var pl := _make_outlined_label("%s %d/6" % [s_def["name"], cnt], 12, s_def["color"] if cnt >= 2 else Color(0.8, 0.8, 0.8))
				pill.add_child(pl)
				synergy_pills_hbox.add_child(pill)
	else:
		var blind_lbl := _make_outlined_label("🔴 地狱盲配模式 (提示已隐藏)", 12, Color(1.0, 0.38, 0.35))
		synergy_pills_hbox.add_child(blind_lbl)

	# 将已安装武器与底盘槽位一一对应展示成直观的方形卡片！
	var total_cards: int = max(GameState.chassis_slots.size(), GameState.equipped_weapons.size())
	for i in range(total_cards):
		var s_type: String = GameState.chassis_slots[i] if i < GameState.chassis_slots.size() else "SE"
		var has_weapon: bool = (i < GameState.equipped_weapons.size())
		var type_badge: String = "🔴主炮孔" if s_type == "MAIN" else ("🟡副炮孔" if s_type == "SUB" else "🔵S-E孔")

		if has_weapon:
			var w_entry: Dictionary = GameState.equipped_weapons[i]
			var w_id: String = w_entry["id"]
			var rar: int = int(w_entry.get("rarity", 0))
			var w_def: Dictionary = GameData.WEAPONS[w_id]
			var r_col: Color = GameData.RARITY_COLORS[clampi(rar, 0, 5)]

			var w_card := _make_styled_panel(Color(0.18, 0.18, 0.22), r_col, 6)
			w_card.custom_minimum_size = Vector2(142, 0)
			w_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			w_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slots_cards_hbox.add_child(w_card)

			var wv := VBoxContainer.new()
			wv.add_theme_constant_override("separation", 4)
			w_card.add_child(wv)

			var top_r := HBoxContainer.new()
			wv.add_child(top_r)
			var sl_lbl := _make_outlined_label("#%d [%s]" % [i + 1, w_def["slot"]], 11, Color(0.8, 0.85, 0.9))
			sl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_r.add_child(sl_lbl)
			var star_lbl := _make_outlined_label("★%d" % (rar + 1), 12, r_col)
			top_r.add_child(star_lbl)

			var wn_lbl := _make_outlined_label(w_def["name"], 13, r_col)
			wn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wn_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			wv.add_child(wn_lbl)

			var eff_dmg: float = GameState.get_weapon_effective_damage(w_id, rar)
			var eff_w: float = GameState.get_weapon_effective_weight(w_id, rar)
			var st_lbl := _make_outlined_label("💥%.0f  |  ⚖️%.1ft" % [eff_dmg, eff_w], 11, Color(0.92, 0.90, 0.82))
			wv.add_child(st_lbl)

			var b_row := HBoxContainer.new()
			b_row.add_theme_constant_override("separation", 4)
			wv.add_child(b_row)

			if i < GameState.chassis_slots.size():
				var mod_btn := Button.new()
				mod_btn.text = "改孔"
				mod_btn.custom_minimum_size = Vector2(44, 26)
				mod_btn.add_theme_font_size_override("font_size", 11)
				mod_btn.pressed.connect(func(): _try_mod_slot(i, mod_cost))
				b_row.add_child(mod_btn)

			var sell_btn := Button.new()
			sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sell_btn.custom_minimum_size = Vector2(0, 26)
			sell_btn.add_theme_font_size_override("font_size", 11)
			var refund: int = int(w_def.get("cost", 50) * pow(1.6, rar) * 0.6)
			sell_btn.text = "卖+%dG" % refund
			sell_btn.pressed.connect(func():
				GameState.sell_weapon_at(i)
				SoundManager.play("coin", 0.1, -2.0)
				refresh_all()
			)
			b_row.add_child(sell_btn)
		else:
			var empty_card := _make_styled_panel(Color(0.11, 0.11, 0.14), Color(0.32, 0.35, 0.42), 6)
			empty_card.custom_minimum_size = Vector2(132, 0)
			empty_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slots_cards_hbox.add_child(empty_card)

			var ev := VBoxContainer.new()
			ev.alignment = BoxContainer.ALIGNMENT_CENTER
			ev.add_theme_constant_override("separation", 6)
			empty_card.add_child(ev)

			var e_title := _make_outlined_label("空槽 #%d\n%s" % [i + 1, type_badge], 13, Color(0.65, 0.72, 0.80))
			e_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ev.add_child(e_title)

			var mod_btn := Button.new()
			mod_btn.custom_minimum_size = Vector2(0, 30)
			mod_btn.add_theme_font_size_override("font_size", 12)
			mod_btn.text = "🔩 切换孔位"
			mod_btn.pressed.connect(func(): _try_mod_slot(i, mod_cost))
			ev.add_child(mod_btn)

func _try_mod_slot(slot_idx: int, mod_cost: int) -> void:
	if GameState.gold < mod_cost:
		lbl_event_toast.text = "❌ 赏金不足，改孔需要 %d G！" % mod_cost
		return
	GameState.gold -= mod_cost
	GameState.cycle_chassis_slot_type(slot_idx)
	SoundManager.play("coin", 0.08, 0.0)
	refresh_all()

# --- 右侧边栏：SP条 + 载重条 + 土豆兄弟双列属性表 + 悬赏海报 ---
func _refresh_right_stats_and_wanted() -> void:
	# 1. 更新 SP 装甲进度条 & 引擎载重进度条
	bar_garage_sp.max_value = maxf(1.0, GameState.max_sp)
	bar_garage_sp.value = bar_garage_sp.max_value
	lbl_garage_sp.text = "🛡️ 战车装甲: %d SP  (+%.0f/秒)" % [int(GameState.max_sp), GameState.sp_regen_per_sec]

	bar_garage_weight.max_value = maxf(1.0, GameState.max_weight)
	bar_garage_weight.value = clampf(GameState.used_weight, 0.0, bar_garage_weight.max_value)
	if GameState.overweight_tons > 0.0:
		style_weight_fill.bg_color = Color(0.95, 0.25, 0.22)
		lbl_garage_weight.text = "⚠️ 超载 %.1ft! (%.1f / %.1ft)" % [GameState.overweight_tons, GameState.used_weight, GameState.max_weight]
	else:
		style_weight_fill.bg_color = Color(0.88, 0.58, 0.18)
		lbl_garage_weight.text = "⚖️ 载重: %.1f / %.1ft (余 %.1ft ➔ SP)" % [GameState.used_weight, GameState.max_weight, GameState.free_weight]

	# 2. 更新土豆兄弟式双列属性表
	for c in stats_list_vbox.get_children():
		c.queue_free()

	var ch: Dictionary = GameData.CHASSIS[GameState.selected_chassis_id]
	var hunter: Dictionary = GameData.HUNTERS[GameState.selected_hunter_id]
	var eng: Dictionary = GameData.ENGINES[GameState.equipped_engine_id]
	var cu: Dictionary = GameData.C_UNITS[GameState.equipped_c_unit_id]

	# 顶部猎人+战车小图标展示行
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 8)
	stats_list_vbox.add_child(icon_row)
	icon_row.add_child(_make_tex_rect(GameData.get_hunter_tex(GameState.selected_hunter_id), Vector2(38, 38)))
	icon_row.add_child(_make_tex_rect(GameData.get_chassis_tex(GameState.selected_chassis_id), Vector2(56, 38)))
	var hc_lbl := _make_outlined_label("%s (Lv.%d)\n%s" % [hunter["name"].split(" ")[0], GameState.level, ch["name"].split(" ")[0]], 12, Color(0.95, 0.90, 0.78))
	icon_row.add_child(hc_lbl)

	_add_mini_stat_row(stats_list_vbox, "⚙️ 当前引擎", eng["name"].substr(0, 9), Color(0.45, 0.92, 1.0))
	_add_mini_stat_row(stats_list_vbox, "💻 火控C装置", cu["name"].substr(0, 9), Color(0.92, 0.60, 1.0))
	_add_mini_stat_row(stats_list_vbox, "💥 暴击几率", "%d%%" % int(GameState.crit_chance * 100.0), Color(0.40, 1.0, 0.55))
	_add_mini_stat_row(stats_list_vbox, "💨 闪避几率", "%d%%" % int(GameState.dodge_chance * 100.0), Color(0.45, 0.92, 1.0))
	_add_mini_stat_row(stats_list_vbox, "⚡ 装填加速", "+%d%%" % int(GameState.bonus_stats.get("reload_speed_pct", 0.0) * 100.0), Color(1.0, 0.85, 0.32))
	_add_mini_stat_row(stats_list_vbox, "🚜 战车移速", "%.0f" % GameState.move_speed, Color.WHITE)

	# 3. 刷新猎人办事处悬赏通缉令紧凑卡
	for c in wanted_box_vbox.get_children():
		c.queue_free()

	var w_header_row := HBoxContainer.new()
	wanted_box_vbox.add_child(w_header_row)
	var w_title := _make_outlined_label("🎯 赏金首通缉令 (WANTED)", 14, Color(1.0, 0.45, 0.35))
	w_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_header_row.add_child(w_title)

	if GameState.is_feature_unlocked("black_market_wanted"):
		var btn_bm := Button.new()
		btn_bm.text = "🔄换单"
		btn_bm.custom_minimum_size = Vector2(58, 24)
		btn_bm.add_theme_font_size_override("font_size", 11)
		btn_bm.pressed.connect(func():
			GameState.wanted_poster_offset += 1
			SoundManager.play("coin", 0.1, -3.0)
			_refresh_right_stats_and_wanted()
		)
		w_header_row.add_child(btn_bm)

	var posters: Array = GameState.get_available_wanted_posters()
	if posters.is_empty():
		wanted_box_vbox.add_child(_make_outlined_label("✅ 本区悬赏已肃清，准备决战关底统帅！", 12, Color(0.45, 1.0, 0.55)))
		return

	var boss: Dictionary = posters[0]
	var is_selected: bool = (GameState.active_wanted_boss_id == boss["id"])
	var bounty_mult: float = 1.25 if GameState.is_feature_unlocked("black_market_wanted") else 1.0
	var disp_bounty: int = int(float(boss["bounty"]) * bounty_mult)
	var rw_name: String = GameData.WEAPONS.get(boss["reward_weapon"], {}).get("name", "传奇红武")

	var p_row := HBoxContainer.new()
	p_row.add_theme_constant_override("separation", 8)
	wanted_box_vbox.add_child(p_row)

	p_row.add_child(_make_tex_rect(GameData.get_boss_tex(String(boss["id"])), Vector2(68, 50)))

	var p_info := VBoxContainer.new()
	p_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_row.add_child(p_info)
	p_info.add_child(_make_outlined_label(boss["name"].split(" ")[0], 14, Color(1.0, 0.88, 0.28)))
	p_info.add_child(_make_outlined_label("💰 %dG  |  🎁 %s" % [disp_bounty, rw_name.substr(0, 8)], 11, Color(0.95, 0.82, 0.78)))

	var btn_w := Button.new()
	btn_w.custom_minimum_size = Vector2(0, 32)
	btn_w.add_theme_font_size_override("font_size", 13)
	btn_w.text = "✅ 已接单：下波乱入 (点击取消)" if is_selected else "📌 撕下通缉令：下波迎战！"
	btn_w.pressed.connect(func():
		if is_selected:
			GameState.active_wanted_boss_id = ""
			lbl_event_toast.text = "已暂缓通缉令挑战。"
		else:
			GameState.active_wanted_boss_id = boss["id"]
			SoundManager.play("wanted_siren", 0.05, -2.0)
			lbl_event_toast.text = "⚠️ 已撕下【%s】通缉令！下一波开战 6 秒后乱入！" % boss["name"]
		refresh_all()
	)
	wanted_box_vbox.add_child(btn_w)

func _on_reroll_pressed() -> void:
	var cost: int = int((12 + GameState.current_wave * 3 + reroll_count * 6) * (1.0 - GameState.bonus_stats.get("reroll_discount", 0.0)))
	cost = max(2, cost)
	if GameState.gold < cost:
		lbl_event_toast.text = "❌ 赏金不足，无法刷新商店！"
		return
	GameState.gold -= cost
	reroll_count += 1
	SoundManager.play("coin", 0.12, -2.0)
	_roll_shop_items()
	refresh_all()

func _on_vending_machine() -> void:
	if not GameState.is_feature_unlocked("vending_unlock"):
		lbl_event_toast.text = "🔒 【自动售货机】未解锁！可在大本营【局外养成】中用 80💎 解锁。"
		return
	if GameState.gold < 15:
		lbl_event_toast.text = "❌ 需要 15 G 投币买冷饮！"
		return
	GameState.gold -= 15
	GameState.bonus_stats["flat_sp_bonus"] = GameState.bonus_stats.get("flat_sp_bonus", 0.0) + 25.0
	if randf() < 0.35:
		GameState.bonus_stats["crit_chance"] = GameState.bonus_stats.get("crit_chance", 0.08) + 0.05
		GameState.gold += 30
		SoundManager.play("upgrade", 0.04, 2.0)
		lbl_event_toast.text = "🎉 【再来一瓶大奖！】额外 +30G、+5%暴击率、+25最大SP！"
	else:
		SoundManager.play("coin", 0.1, 0.0)
		lbl_event_toast.text = "🥤 畅饮冰镇可乐！最大装甲永久 +25 SP！"
	refresh_all()

func _on_metal_detector() -> void:
	if not GameState.is_feature_unlocked("detector_unlock"):
		lbl_event_toast.text = "🔒 【金属探测器】未解锁！可在大本营【局外养成】中用 120💎 解锁。"
		return
	if dig_used_this_wave:
		lbl_event_toast.text = "📡 本波次已探测过，等下一波再来吧！"
		return
	if GameState.gold < 35:
		lbl_event_toast.text = "❌ 需要 35 G 启动金属探测器！"
		return
	GameState.gold -= 35
	dig_used_this_wave = true
	if randf() < 0.55:
		var bonus: int = randi_range(55, 110)
		GameState.gold += bonus
		SoundManager.play("upgrade", 0.05, 1.0)
		lbl_event_toast.text = "📡 挖出旧时代金条，获得 +%d G！" % bonus
	else:
		GameState.bonus_stats["max_weight_pct"] = GameState.bonus_stats.get("max_weight_pct", 0.0) + 0.10
		SoundManager.play("upgrade", 0.05, 1.0)
		lbl_event_toast.text = "📡 挖出【古代超导轴承】！引擎最大载重永久 +10%！"
	refresh_all()

func _on_wax_tank() -> void:
	if waxed_this_wave:
		lbl_event_toast.text = "✨ 本波战车已打过蜡！"
		return
	if GameState.gold < 25:
		lbl_event_toast.text = "❌ 需要 25 G 给战车打蜡！"
		return
	GameState.gold -= 25
	waxed_this_wave = true
	GameState.bonus_stats["dodge"] = GameState.bonus_stats.get("dodge", 0.0) + 0.06
	GameState.bonus_stats["flat_sp_bonus"] = GameState.bonus_stats.get("flat_sp_bonus", 0.0) + 60.0
	SoundManager.play("upgrade", 0.08, 0.0)
	lbl_event_toast.text = "✨ 防弹打蜡完成！闪避率 +6%，最大装甲 +60 SP！"
	refresh_all()

func _on_show_evo_recipes() -> void:
	if not GameState.should_show_build_hints():
		lbl_event_toast.text = "🔴 【地狱模式限制】地狱难度下隐藏超武合成配方提示！"
		return
	var lines: Array = []
	for r in GameData.SUPER_EVOLUTIONS:
		lines.append("%s=%s" % [r["name"].replace("★【超武】", ""), r["formula_text"]])
	lbl_event_toast.text = "🌟 超武配方(组件达★2或捡宝箱自动合成): " + " | ".join(lines.slice(0, 3))

func _on_launch_pressed() -> void:
	visible = false
	emit_signal("start_next_wave")

# --- UI 辅助构造函数 ---
func _create_bar(min_sz: Vector2, fill_col: Color, font_sz: int) -> Dictionary:
	var container := Control.new()
	container.custom_minimum_size = min_sz

	var bar := ProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.10, 0.95)
	bg_style.border_color = Color(0.02, 0.02, 0.03, 1.0)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(4)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_col
	fill_style.border_color = Color(0.02, 0.02, 0.03, 1.0)
	fill_style.set_border_width_all(2)
	fill_style.set_corner_radius_all(4)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	container.add_child(bar)

	var lbl := _make_outlined_label("", font_sz, Color.WHITE)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(lbl)

	return {"container": container, "bar": bar, "fill_style": fill_style, "label": lbl}

func _add_mini_stat_row(parent: VBoxContainer, k_txt: String, v_txt: String, v_col: Color) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var kl := _make_outlined_label(k_txt, 12, Color(0.78, 0.80, 0.84))
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kl)
	var vl := _make_outlined_label(v_txt, 12, v_col)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(vl)

func _make_outlined_label(txt: String, f_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", f_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	l.add_theme_constant_override("outline_size", 3)
	return l

func _make_styled_panel(bg_col: Color, border_col: Color, radius: int = 6) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_tex_rect(tex: Texture2D, min_sz: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = min_sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr
