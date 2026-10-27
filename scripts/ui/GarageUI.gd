extends Control
## 《重装废土：赏金狂飙》 - 多拉姆战车整备车库 & 猎人办事处悬赏面板
## 核心功能：载重=SP实时博弈仪表盘、军火商店刷店、同名武器二合一升星、底盘改孔、撕取赏金首通缉令、售货机/金属探测奇遇。

signal start_next_wave

var shop_items: Array = []
var reroll_count: int = 0
var waxed_this_wave: bool = false
var dig_used_this_wave: bool = false

# --- UI 节点引用 ---
var lbl_header: Label
var lbl_weight_sp_formula: Label
var lbl_synergy_bar: Label
var lbl_event_toast: Label

var perk_panel: PanelContainer
var perk_hbox: HBoxContainer

var slots_vbox: VBoxContainer
var equipped_vbox: VBoxContainer
var shop_vbox: VBoxContainer
var wanted_vbox: VBoxContainer
var btn_reroll: Button
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
	bg.color = Color(0.08, 0.07, 0.06, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# 1. 顶部仪表盘：波次、赏金、引擎载重与SP实时转化公式
	var top_panel := _make_styled_panel(Color(0.16, 0.14, 0.12), Color(0.85, 0.55, 0.22))
	main_vbox.add_child(top_panel)

	var top_vbox := VBoxContainer.new()
	top_panel.add_child(top_vbox)

	lbl_header = Label.new()
	lbl_header.add_theme_font_size_override("font_size", 22)
	lbl_header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	top_vbox.add_child(lbl_header)

	lbl_weight_sp_formula = Label.new()
	lbl_weight_sp_formula.add_theme_font_size_override("font_size", 15)
	lbl_weight_sp_formula.add_theme_color_override("font_color", Color(0.40, 0.98, 0.60))
	top_vbox.add_child(lbl_weight_sp_formula)

	lbl_synergy_bar = Label.new()
	lbl_synergy_bar.add_theme_font_size_override("font_size", 13)
	lbl_synergy_bar.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	top_vbox.add_child(lbl_synergy_bar)

	# 2. 猎人升级天赋选择栏 (有未分配等级时显示)
	perk_panel = _make_styled_panel(Color(0.22, 0.16, 0.10), Color(1.0, 0.82, 0.20))
	main_vbox.add_child(perk_panel)
	var perk_outer := VBoxContainer.new()
	perk_panel.add_child(perk_outer)
	var perk_title := Label.new()
	perk_title.text = "🎖️ 猎人等级提升！请选择一项驾驶/改装专精天赋："
	perk_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	perk_outer.add_child(perk_title)
	perk_hbox = HBoxContainer.new()
	perk_hbox.add_theme_constant_override("separation", 14)
	perk_outer.add_child(perk_hbox)

	# 3. 中部三栏核心区：左(战车改装&改孔) | 中(多拉姆军火商店&废土奇遇) | 右(猎人办事处悬赏通缉令)
	var center_hbox := HBoxContainer.new()
	center_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_hbox.add_theme_constant_override("separation", 14)
	main_vbox.add_child(center_hbox)

	# --- 左栏：战车底盘孔位改造与已装备武器 ---
	var left_panel := _make_styled_panel(Color(0.14, 0.13, 0.12), Color(0.45, 0.65, 0.85))
	left_panel.custom_minimum_size = Vector2(430, 0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_scroll)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	left_scroll.add_child(left_vbox)

	var lbl_left_t := Label.new()
	lbl_left_t.text = "🔧 【当前战车配装 & 底盘改孔工坊】"
	lbl_left_t.add_theme_font_size_override("font_size", 17)
	lbl_left_t.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	left_vbox.add_child(lbl_left_t)

	slots_vbox = VBoxContainer.new()
	slots_vbox.add_theme_constant_override("separation", 4)
	left_vbox.add_child(slots_vbox)

	var sep := HSeparator.new()
	left_vbox.add_child(sep)

	equipped_vbox = VBoxContainer.new()
	equipped_vbox.add_theme_constant_override("separation", 6)
	left_vbox.add_child(equipped_vbox)

	# --- 中栏：多拉姆军火商店 & 废土奇遇设施 ---
	var mid_panel := _make_styled_panel(Color(0.15, 0.14, 0.12), Color(0.85, 0.68, 0.25))
	mid_panel.custom_minimum_size = Vector2(500, 0)
	mid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.add_child(mid_panel)

	var mid_vbox := VBoxContainer.new()
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_vbox.add_theme_constant_override("separation", 8)
	mid_panel.add_child(mid_vbox)

	var shop_top_hbox := HBoxContainer.new()
	mid_vbox.add_child(shop_top_hbox)

	var lbl_mid_t := Label.new()
	lbl_mid_t.text = "🛒 【多拉姆军火商店】(同名同星自动二合一升星!)"
	lbl_mid_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_mid_t.add_theme_font_size_override("font_size", 17)
	lbl_mid_t.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	shop_top_hbox.add_child(lbl_mid_t)

	btn_reroll = Button.new()
	btn_reroll.custom_minimum_size = Vector2(140, 34)
	btn_reroll.pressed.connect(_on_reroll_pressed)
	shop_top_hbox.add_child(btn_reroll)

	var mid_scroll := ScrollContainer.new()
	mid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_vbox.add_child(mid_scroll)

	shop_vbox = VBoxContainer.new()
	shop_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_vbox.add_theme_constant_override("separation", 8)
	mid_scroll.add_child(shop_vbox)

	# 废土特色奇遇按钮栏 (自动售货机 / 金属探测器 / 战车打蜡)
	var event_hbox := HBoxContainer.new()
	event_hbox.add_theme_constant_override("separation", 8)
	mid_vbox.add_child(event_hbox)

	var btn_soda := Button.new()
	btn_soda.text = "🥤 售货机抽奖 (15G)"
	btn_soda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_soda.pressed.connect(_on_vending_machine)
	event_hbox.add_child(btn_soda)

	var btn_dig := Button.new()
	btn_dig.text = "📡 金属探测挖掘 (35G)"
	btn_dig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dig.pressed.connect(_on_metal_detector)
	event_hbox.add_child(btn_dig)

	var btn_wax := Button.new()
	btn_wax.text = "✨ 给战车打蜡 (25G)"
	btn_wax.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_wax.pressed.connect(_on_wax_tank)
	event_hbox.add_child(btn_wax)

	var btn_evo_guide := Button.new()
	btn_evo_guide.text = "🌟 隐藏超武配方表"
	btn_evo_guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_evo_guide.pressed.connect(_on_show_evo_recipes)
	event_hbox.add_child(btn_evo_guide)

	lbl_event_toast = Label.new()
	lbl_event_toast.text = "💡 提示：剩余引擎载重会自动100%转化为战车装甲片(SP)！合成高星武器仅增重10%但伤害暴涨65%！"
	lbl_event_toast.add_theme_font_size_override("font_size", 13)
	lbl_event_toast.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	mid_vbox.add_child(lbl_event_toast)

	# --- 右栏：猎人办事处 (赏金首 WANTED 通缉令) ---
	var right_panel := _make_styled_panel(Color(0.18, 0.12, 0.11), Color(0.95, 0.30, 0.22))
	right_panel.custom_minimum_size = Vector2(410, 0)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.add_child(right_panel)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_scroll)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	right_scroll.add_child(right_vbox)

	var lbl_right_t := Label.new()
	lbl_right_t.text = "🎯 【猎人办事处：赏金首通缉令 (WANTED)】"
	lbl_right_t.add_theme_font_size_override("font_size", 17)
	lbl_right_t.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32))
	right_vbox.add_child(lbl_right_t)

	var lbl_right_sub := Label.new()
	lbl_right_sub.text = "主动撕下通缉令后，下一波开战 6 秒该赏金首将强行乱入！击杀必得巨额赏金与专属传奇红武！"
	lbl_right_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_right_sub.add_theme_font_size_override("font_size", 12)
	lbl_right_sub.add_theme_color_override("font_color", Color(0.90, 0.78, 0.70))
	right_vbox.add_child(lbl_right_sub)

	wanted_vbox = VBoxContainer.new()
	wanted_vbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(wanted_vbox)

	# 4. 底部出击按钮
	btn_launch = Button.new()
	btn_launch.custom_minimum_size = Vector2(0, 52)
	btn_launch.add_theme_font_size_override("font_size", 22)
	btn_launch.pressed.connect(_on_launch_pressed)
	main_vbox.add_child(btn_launch)

func open_garage() -> void:
	visible = true
	reroll_count = 0
	waxed_this_wave = false
	dig_used_this_wave = false
	lbl_event_toast.text = "💡 欢迎回到多拉姆整备车库！(支持手柄十字键/左摇杆选商品，[A]购买，[Y]刷新商店，[Start]出击下一波)"
	_roll_shop_items()
	refresh_all()
	if is_instance_valid(btn_launch):
		btn_launch.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
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
	var ch: Dictionary = GameData.CHASSIS[GameState.selected_chassis_id]
	var hunter: Dictionary = GameData.HUNTERS[GameState.selected_hunter_id]

	lbl_header.text = "⚙️ 多拉姆战车车库 (已完成第 %d/%d 波)  |  猎人: %s  |  座驾: %s  |  💰 赏金: %d G" % [
		GameState.current_wave, GameState.max_waves, hunter["name"], ch["name"], GameState.gold
	]

	var over_str: String = ""
	if GameState.overweight_tons > 0.0:
		over_str = "   ⚠️【超载 %.1f 吨：战车移速降低! 请升级引擎或卸下重武器】" % GameState.overweight_tons
	lbl_weight_sp_formula.text = "🛡️ 【载重=SP 核心公式】 引擎上限 %.1ft - 武器自重 %.1ft = 剩余载重 %.1ft  ➔  转化为战车最大装甲片: %d SP (每秒恢复 +%.0f SP)%s" % [
		GameState.max_weight, GameState.used_weight, GameState.free_weight, int(GameState.max_sp), GameState.sp_regen_per_sec, over_str
	]

	# 流派羁绊统计栏 (仅简单与困难难度显示，地狱模式隐藏提示!)
	if GameState.should_show_build_hints():
		var syn_parts: Array = []
		for tag in GameData.SYNERGIES.keys():
			var cnt: int = GameState.synergy_counts.get(tag, 0)
			if cnt > 0:
				syn_parts.append("【%s: %d/6】" % [GameData.SYNERGIES[tag]["name"], cnt])
		lbl_synergy_bar.text = "🔥 激活流派羁绊: " + ("  ".join(syn_parts) if syn_parts.size() > 0 else "暂无 (购买武器叠加标签可激活 2/4/6 件套强力羁绊)")
	else:
		lbl_synergy_bar.text = "🔴 【地狱难度法则】流派羁绊与超武配件提示已隐藏（效果仍在后台正常生效，全凭老猎人记忆盲配！）"

	_refresh_perk_bar()
	_refresh_left_column()
	_refresh_shop_column()
	_refresh_wanted_column()

	var next_w: int = GameState.current_wave + 1
	var wanted_str: String = ""
	if GameState.active_wanted_boss_id != "":
		for b in GameData.WANTED_BOSSES:
			if b["id"] == GameState.active_wanted_boss_id:
				wanted_str = "  (⚠️ 已接单赏金首：【%s】将在下波乱入!)" % b["name"]
				break
	btn_launch.text = "🚀 [Start] 启动引擎：出击第 %d 波废土战场！%s" % [next_w, wanted_str]
	if visible and get_viewport() and get_viewport().gui_get_focus_owner() == null and is_instance_valid(btn_launch):
		btn_launch.call_deferred("grab_focus")

func _refresh_perk_bar() -> void:
	for c in perk_hbox.get_children():
		c.queue_free()
	if GameState.pending_level_ups <= 0:
		perk_panel.visible = false
		return
	perk_panel.visible = true

	var shuffled: Array = GameData.LEVEL_PERKS.duplicate()
	shuffled.shuffle()
	for i in range(min(4, shuffled.size())):
		var p: Dictionary = shuffled[i]
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 44)
		btn.text = "★ %s\n%s" % [p["name"], p["desc"]]
		btn.pressed.connect(func():
			var st: String = p["stat"]
			GameState.bonus_stats[st] = GameState.bonus_stats.get(st, 0.0) + float(p["val"])
			GameState.pending_level_ups -= 1
			SoundManager.play("upgrade", 0.05, 0.0)
			refresh_all()
		)
		perk_hbox.add_child(btn)

func _refresh_left_column() -> void:
	for c in slots_vbox.get_children():
		c.queue_free()
	for c in equipped_vbox.get_children():
		c.queue_free()

	# 1. 当前猎人立绘 + 战车俯视图 + 引擎与C装置
	var eng: Dictionary = GameData.ENGINES[GameState.equipped_engine_id]
	var cu: Dictionary = GameData.C_UNITS[GameState.equipped_c_unit_id]

	var top_showcase := HBoxContainer.new()
	top_showcase.add_theme_constant_override("separation", 10)
	slots_vbox.add_child(top_showcase)

	var h_rect := _make_tex_rect(GameData.get_hunter_tex(GameState.selected_hunter_id), Vector2(58, 58))
	top_showcase.add_child(h_rect)

	var c_rect := _make_tex_rect(GameData.get_chassis_tex(GameState.selected_chassis_id), Vector2(86, 58))
	top_showcase.add_child(c_rect)

	var lbl_ec := Label.new()
	lbl_ec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_ec.text = "• 引擎: %s (载重 %.0ft)\n• C装置: %s\n  %s" % [eng["name"], eng["max_weight"], cu["name"], cu["desc"]]
	lbl_ec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_ec.add_theme_font_size_override("font_size", 12)
	lbl_ec.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	top_showcase.add_child(lbl_ec)

	# 2. 底盘孔位列表与改孔按钮
	var mod_cost: int = 0 if GameState.bonus_stats.get("free_slot_mod", false) else 25
	var slot_title := Label.new()
	slot_title.text = "🔩 底盘武器开孔 (%d孔) — 点击可改孔 (%s):" % [GameState.chassis_slots.size(), "机械师免费!" if mod_cost == 0 else "%dG/次" % mod_cost]
	slot_title.add_theme_font_size_override("font_size", 13)
	slots_vbox.add_child(slot_title)

	var slot_grid := HFlowContainer.new()
	slots_vbox.add_child(slot_grid)

	for i in range(GameState.chassis_slots.size()):
		var s_type: String = GameState.chassis_slots[i]
		var s_btn := Button.new()
		var type_cn: String = "主炮孔(MAIN)" if s_type == "MAIN" else ("副炮孔(SUB)" if s_type == "SUB" else "特殊孔(S-E)")
		s_btn.text = "#%d %s [改]" % [i + 1, type_cn]
		s_btn.pressed.connect(func():
			if GameState.gold < mod_cost:
				lbl_event_toast.text = "❌ 赏金不足，无法改造底盘孔位！"
				return
			GameState.gold -= mod_cost
			GameState.cycle_chassis_slot_type(i)
			SoundManager.play("coin", 0.08, 0.0)
			refresh_all()
		)
		slot_grid.add_child(s_btn)

	# 3. 已安装武器列表
	var eq_title := Label.new()
	eq_title.text = "🔫 已安装战车武器 (%d / %d):" % [GameState.equipped_weapons.size(), GameState.chassis_slots.size()]
	eq_title.add_theme_font_size_override("font_size", 14)
	eq_title.add_theme_color_override("font_color", Color(0.65, 0.95, 0.75))
	equipped_vbox.add_child(eq_title)

	for i in range(GameState.equipped_weapons.size()):
		var w_entry: Dictionary = GameState.equipped_weapons[i]
		var w_id: String = w_entry["id"]
		var rar: int = w_entry.get("rarity", 0)
		var w_def: Dictionary = GameData.WEAPONS[w_id]

		var row := HBoxContainer.new()
		equipped_vbox.add_child(row)

		var w_lbl := Label.new()
		w_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var eff_dmg: float = GameState.get_weapon_effective_damage(w_id, rar)
		var eff_w: float = GameState.get_weapon_effective_weight(w_id, rar)
		w_lbl.text = "[%s] %s %s\n伤害: %.0f | 重量: %.1ft | CD: %.1fs" % [
			w_def["slot"], w_def["name"], GameData.RARITY_NAMES[rar], eff_dmg, eff_w, float(w_def["cooldown"])
		]
		w_lbl.add_theme_font_size_override("font_size", 13)
		w_lbl.add_theme_color_override("font_color", GameData.RARITY_COLORS[rar])
		row.add_child(w_lbl)

		var sell_btn := Button.new()
		var refund: int = int(w_def.get("cost", 50) * pow(1.6, rar) * 0.6)
		sell_btn.text = "拆卸(+%dG)" % refund
		sell_btn.pressed.connect(func():
			GameState.sell_weapon_at(i)
			SoundManager.play("coin", 0.1, -2.0)
			refresh_all()
		)
		row.add_child(sell_btn)

func _roll_shop_items() -> void:
	# 保留已锁定的商品
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

func _refresh_shop_column() -> void:
	for c in shop_vbox.get_children():
		c.queue_free()

	var base_reroll: int = int((12 + GameState.current_wave * 3 + reroll_count * 6) * (1.0 - GameState.bonus_stats.get("reroll_discount", 0.0)))
	btn_reroll.text = "🔄 [Y]刷新军火 (%dG)" % max(2, base_reroll)

	for idx in range(shop_items.size()):
		var item: Dictionary = shop_items[idx]
		if item["bought"]:
			continue

		var card := _make_styled_panel(Color(0.20, 0.18, 0.15), Color(0.55, 0.50, 0.42))
		shop_vbox.add_child(card)
		var hbox := HBoxContainer.new()
		card.add_child(hbox)

		var desc_lbl := Label.new()
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(desc_lbl)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(105, 48)
		hbox.add_child(buy_btn)

		if GameState.is_feature_unlocked("shop_lock"):
			var lock_btn := Button.new()
			lock_btn.custom_minimum_size = Vector2(64, 48)
			lock_btn.text = "🔓已锁" if item.get("locked", false) else "🔒锁定"
			lock_btn.pressed.connect(func():
				item["locked"] = not item.get("locked", false)
				SoundManager.play("coin", 0.15, -4.0)
				_refresh_shop_column()
			)
			hbox.add_child(lock_btn)

		if item["kind"] == "weapon":
			var w_id: String = item["id"]
			var rar: int = item["rarity"]
			var w_def: Dictionary = GameData.WEAPONS[w_id]
			var show_hints: bool = GameState.should_show_build_hints()
			var can_merge: bool = false
			for ew in GameState.equipped_weapons:
				if ew["id"] == w_id and ew.get("rarity", 0) == rar and rar < 4:
					can_merge = true
					break
			var merge_tag: String = " 🔥【可二合一升星!】" if (can_merge and show_hints) else ""
			if show_hints:
				var syn_names: Array = []
				for t in w_def.get("tags", []):
					if GameData.SYNERGIES.has(t):
						syn_names.append(GameData.SYNERGIES[t]["name"])
				if not syn_names.is_empty():
					merge_tag += " [流派:%s]" % "/".join(syn_names)
				var evo_partner: String = GameState.check_super_evolution_partner(w_id)
				if evo_partner != "":
					merge_tag += " 🌟【超武配方➔%s】" % evo_partner
			desc_lbl.text = "[%s孔] %s %s%s\n重量: %.1ft | 基础伤: %.0f | %s" % [
				w_def["slot"], w_def["name"], GameData.RARITY_NAMES[rar], merge_tag,
				float(w_def["weight"]), float(w_def["base_dmg"]) * pow(1.65, rar), w_def["desc"]
			]
			desc_lbl.add_theme_color_override("font_color", GameData.RARITY_COLORS[rar])
			buy_btn.text = "购买\n%d G" % item["price"]
			buy_btn.pressed.connect(func():
				if GameState.gold < item["price"]:
					lbl_event_toast.text = "❌ 赏金 G 不足！"
					return
				if not GameState.can_equip_or_merge(w_id, rar):
					lbl_event_toast.text = "⚠️ 缺少对应的【%s】底盘空闲孔位！请先在左侧拆卸武器或点击【改孔】。" % w_def["slot"]
					return
				GameState.gold -= item["price"]
				item["bought"] = true
				var res: Dictionary = GameState.add_weapon_to_first_valid_slot(w_id, rar, true)
				var evos: Array = res.get("evos", [])
				if not evos.is_empty():
					SoundManager.play("mince_revive", 0.02, 3.0)
					lbl_event_toast.text = "🌟【隐藏超武合成成功！】[%s] + [%s] ➔ 进化为【%s】！！" % [
						evos[0]["comp_a_name"], evos[0]["comp_b_name"], evos[0]["evo_name"]
					]
				elif res.get("merged", false):
					SoundManager.play("upgrade", 0.04, 2.0)
					lbl_event_toast.text = "✨ 二合一升星成功！【%s】晋升为 %s！" % [w_def["name"], GameData.RARITY_NAMES[res["new_rarity"]]]
				else:
					SoundManager.play("coin", 0.08, 0.0)
					lbl_event_toast.text = "🔧 已将【%s】安装至底盘！" % w_def["name"]
				refresh_all()
			)
		elif item["kind"] == "engine":
			var e_def: Dictionary = GameData.ENGINES[item["id"]]
			desc_lbl.text = "⚙️ 【引擎升级】%s\n%s" % [e_def["name"], e_def["desc"]]
			desc_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
			buy_btn.text = "换装引擎\n%d G" % item["price"]
			buy_btn.pressed.connect(func():
				if GameState.gold < item["price"]:
					lbl_event_toast.text = "❌ 赏金 G 不足！"
					return
				GameState.gold -= item["price"]
				GameState.equipped_engine_id = item["id"]
				item["bought"] = true
				SoundManager.play("upgrade", 0.05, 1.0)
				lbl_event_toast.text = "⚙️ 引擎换装完成！最大载重与SP装甲大幅提升！"
				refresh_all()
			)
		elif item["kind"] == "c_unit":
			var c_def: Dictionary = GameData.C_UNITS[item["id"]]
			desc_lbl.text = "💻 【C装置核心】%s\n%s" % [c_def["name"], c_def["desc"]]
			desc_lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 1.0))
			buy_btn.text = "安装核心\n%d G" % item["price"]
			buy_btn.pressed.connect(func():
				if GameState.gold < item["price"]:
					lbl_event_toast.text = "❌ 赏金 G 不足！"
					return
				GameState.gold -= item["price"]
				GameState.equipped_c_unit_id = item["id"]
				item["bought"] = true
				SoundManager.play("upgrade", 0.05, 1.0)
				lbl_event_toast.text = "💻 C装置【%s】已激活！" % c_def["name"]
				refresh_all()
			)

func _refresh_wanted_column() -> void:
	for c in wanted_vbox.get_children():
		c.queue_free()

	if GameState.is_feature_unlocked("black_market_wanted"):
		var btn_bm := Button.new()
		btn_bm.text = "🔄 黑市悬赏网：切换其他通缉犯名单 (免费)"
		btn_bm.pressed.connect(func():
			GameState.wanted_poster_offset += 1
			SoundManager.play("coin", 0.1, -3.0)
			_refresh_wanted_column()
		)
		wanted_vbox.add_child(btn_bm)

	var posters: Array = GameState.get_available_wanted_posters()
	if posters.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "当前区域所有通缉犯已被肃清！继续推进波次迎战终局主脑【诺亚】！"
		wanted_vbox.add_child(empty_lbl)
		return

	var bounty_mult: float = 1.25 if GameState.is_feature_unlocked("black_market_wanted") else 1.0
	for boss in posters:
		var is_selected: bool = (GameState.active_wanted_boss_id == boss["id"])
		var border_col: Color = Color(1.0, 0.88, 0.20) if is_selected else Color(0.85, 0.28, 0.22)
		var card := _make_styled_panel(Color(0.24, 0.14, 0.12), border_col)
		wanted_vbox.add_child(card)

		var vbox := VBoxContainer.new()
		card.add_child(vbox)

		var poster_hbox := HBoxContainer.new()
		poster_hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(poster_hbox)

		var boss_portrait := _make_tex_rect(GameData.get_boss_tex(String(boss["id"])), Vector2(96, 68))
		poster_hbox.add_child(boss_portrait)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		poster_hbox.add_child(info_vbox)

		var disp_bounty: int = int(float(boss["bounty"]) * bounty_mult)
		var title := Label.new()
		title.text = "🚨 WANTED: %s\n💰 悬赏金: %d G  (+25💎 诺亚晶片)" % [boss["name"], disp_bounty]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
		info_vbox.add_child(title)

		var rw_name: String = GameData.WEAPONS.get(boss["reward_weapon"], {}).get("name", "传奇红武")
		var desc := Label.new()
		desc.text = "%s\n🎁 专属掉落: 【%s (★5红武)】" % [boss["desc"], rw_name]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.95, 0.85, 0.80))
		info_vbox.add_child(desc)

		var btn := Button.new()
		btn.text = "✅ 已撕下通缉令 (点击可暂缓)" if is_selected else "📌 撕下通缉令：下一波迎战！"
		btn.pressed.connect(func():
			if is_selected:
				GameState.active_wanted_boss_id = ""
				lbl_event_toast.text = "已暂缓通缉令挑战。"
			else:
				GameState.active_wanted_boss_id = boss["id"]
				SoundManager.play("wanted_siren", 0.05, -2.0)
				lbl_event_toast.text = "⚠️ 你撕下了【%s】的通缉令！下一波开战 6 秒后它将强行乱入！" % boss["name"]
			refresh_all()
		)
		vbox.add_child(btn)

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
		lbl_event_toast.text = "🔒 【废土自动售货机】尚未通电！请在局外【废铁镇基建】中用 80💎 解锁售货机特权卡。"
		return
	if GameState.gold < 15:
		lbl_event_toast.text = "❌ 需要 15 G 才能投币买废土冷饮！"
		return
	GameState.gold -= 15
	GameState.bonus_stats["flat_sp_bonus"] = GameState.bonus_stats.get("flat_sp_bonus", 0.0) + 25.0
	if randf() < 0.35:
		GameState.bonus_stats["crit_chance"] = GameState.bonus_stats.get("crit_chance", 0.08) + 0.05
		GameState.gold += 30
		SoundManager.play("upgrade", 0.04, 2.0)
		lbl_event_toast.text = "🎉 叮叮叮！【中奖啦！再来一瓶！】额外获得 +30G、+5%暴击率与 +25最大SP！"
	else:
		SoundManager.play("coin", 0.1, 0.0)
		lbl_event_toast.text = "🥤 畅饮冰镇废土可乐！最大装甲片永久 +25 SP！"
	refresh_all()

func _on_metal_detector() -> void:
	if not GameState.is_feature_unlocked("detector_unlock"):
		lbl_event_toast.text = "🔒 【高敏金属探测器】尚未解锁！请在局外【废铁镇基建】中用 120💎 解锁探测器执照。"
		return
	if dig_used_this_wave:
		lbl_event_toast.text = "📡 本波次附近沙地已经探测过了，等下一波再来吧！"
		return
	if GameState.gold < 35:
		lbl_event_toast.text = "❌ 需要 35 G 启动高敏金属探测器！"
		return
	GameState.gold -= 35
	dig_used_this_wave = true
	if randf() < 0.55:
		var bonus: int = randi_range(55, 110)
		GameState.gold += bonus
		SoundManager.play("upgrade", 0.05, 1.0)
		lbl_event_toast.text = "📡 哔哔哔！在沙层下挖出一箱旧时代金条，卖得 +%d G！" % bonus
	else:
		GameState.bonus_stats["max_weight_pct"] = GameState.bonus_stats.get("max_weight_pct", 0.0) + 0.10
		SoundManager.play("upgrade", 0.05, 1.0)
		lbl_event_toast.text = "📡 挖出【古代超导轴承】！引擎最大载重永久 +10%！"
	refresh_all()

func _on_wax_tank() -> void:
	if waxed_this_wave:
		lbl_event_toast.text = "✨ 战车已经打过蜡，装甲锃亮！"
		return
	if GameState.gold < 25:
		lbl_event_toast.text = "❌ 需要 25 G 给战车打蜡！"
		return
	GameState.gold -= 25
	waxed_this_wave = true
	GameState.bonus_stats["dodge"] = GameState.bonus_stats.get("dodge", 0.0) + 0.06
	GameState.bonus_stats["flat_sp_bonus"] = GameState.bonus_stats.get("flat_sp_bonus", 0.0) + 60.0
	SoundManager.play("upgrade", 0.08, 0.0)
	lbl_event_toast.text = "✨ 给战车打上特级防弹蜡！闪避率永久 +6%，最大装甲 +60 SP！"
	refresh_all()

func _on_show_evo_recipes() -> void:
	if not GameState.should_show_build_hints():
		lbl_event_toast.text = "🔴 【地狱难度限制】地狱模式下禁止查阅超武合成配方与流派提示，请凭在简单/困难模式积累的经验盲配！"
		return
	var lines: Array = []
	for r in GameData.SUPER_EVOLUTIONS:
		lines.append("%s = %s" % [r["name"], r["formula_text"]])
	lbl_event_toast.text = "🌟【6大超武配方(任一组件达★2或拾取战场宝箱自动融合)】：\n" + "   |   ".join(lines.slice(0, 3)) + "\n" + "   |   ".join(lines.slice(3, 6))

func _on_launch_pressed() -> void:
	visible = false
	emit_signal("start_next_wave")

func _make_styled_panel(bg_col: Color, border_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
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
