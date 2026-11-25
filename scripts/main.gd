extends Node3D

const SAVE_PATH := "user://life_tycoon_save.json"
const MAX_OFFLINE_SECONDS := 604800
const BUSINESS := [
	{"name":"Pertanian", "cost":2500000, "income":180000, "icon":"🌾"},
	{"name":"Kuliner", "cost":5000000, "income":420000, "icon":"🍔"},
	{"name":"Perdagangan", "cost":8500000, "income":760000, "icon":"📦"},
	{"name":"Transportasi", "cost":15000000, "income":1350000, "icon":"🚚"},
	{"name":"Properti", "cost":30000000, "income":2900000, "icon":"🏢"},
	{"name":"Industri", "cost":60000000, "income":6200000, "icon":"🏭"},
	{"name":"Investasi", "cost":100000000, "income":11500000, "icon":"📈"}
]

var cash: float = 25000000.0
var owned: Array[int] = []
var levels: Dictionary = {}
var last_saved: int = 0
var income_per_second: float = 0.0
var cash_label: Label
var income_label: Label
var status_label: Label
var business_list: VBoxContainer
var scene_root: Node3D

func _ready() -> void:
	_load_game()
	_build_world()
	_build_interface()
	_recalculate_income()
	_apply_offline_income()
	_refresh_ui()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_tick)
	add_child(timer)
	timer.start()

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#101c30")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9bb7d8")
	env.ambient_light_energy = 0.65
	world_env.environment = env
	add_child(world_env)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 4.2, 9.5)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	camera.current = true
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -28, 0)
	light.light_energy = 1.25
	add_child(light)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18, 14)
	floor.mesh = floor_mesh
	floor.position.y = -0.12
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#182a40")
	floor_mat.roughness = 0.85
	floor.material_override = floor_mat
	add_child(floor)

	_add_building(Vector3(-3.3, 1.0, -1.0), Vector3(2.2, 2.0, 2.0), Color("#315c80"))
	_add_building(Vector3(0.0, 1.7, -1.2), Vector3(2.5, 3.4, 2.1), Color("#3b7890"))
	_add_building(Vector3(3.2, 1.25, -1.0), Vector3(2.1, 2.5, 2.0), Color("#4b668c"))
	_add_building(Vector3(-1.7, 0.45, 2.1), Vector3(1.3, 0.9, 1.3), Color("#b18a50"))
	_add_building(Vector3(2.0, 0.55, 2.0), Vector3(1.5, 1.1, 1.4), Color("#527b69"))

func _add_building(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.12
	mat.roughness = 0.5
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var header := PanelContainer.new()
	header.position = Vector2(20, 16)
	header.size = Vector2(1240, 92)
	root.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 26)
	header.add_child(header_row)

	var title := Label.new()
	title.text = "LIFE TYCOON 3D"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 24)
	header_row.add_child(cash_label)
	income_label = Label.new()
	income_label.add_theme_font_size_override("font_size", 18)
	header_row.add_child(income_label)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 128)
	panel.size = Vector2(410, 555)
	root.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	var heading := Label.new()
	heading.text = "KEMBANGKAN BISNIS"
	heading.add_theme_font_size_override("font_size", 23)
	content.add_child(heading)
	var sub := Label.new()
	sub.text = "Beli usaha, tingkatkan level, kumpulkan keuntungan."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	business_list = VBoxContainer.new()
	business_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	business_list.add_theme_constant_override("separation", 8)
	scroll.add_child(business_list)

	status_label = Label.new()
	status_label.text = "Selamat datang, CEO!"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)

	var save_button := Button.new()
	save_button.text = "SIMPAN PERMAINAN"
	save_button.custom_minimum_size.y = 48
	save_button.pressed.connect(_save_game)
	content.add_child(save_button)

	_rebuild_business_buttons()

func _rebuild_business_buttons() -> void:
	for child in business_list.get_children():
		child.queue_free()
	for i in range(BUSINESS.size()):
		var item: Dictionary = BUSINESS[i]
		var level: int = int(levels.get(str(i), 0))
		var row := PanelContainer.new()
		business_list.add_child(row)
		var box := VBoxContainer.new()
		row.add_child(box)
		var line := HBoxContainer.new()
		box.add_child(line)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = "%s  %s\nLevel %d  •  +%s/detik" % [item.icon, item.name, level, _money(float(item.income) * (1.0 + level * 0.5) / 60.0)]
		info.add_theme_font_size_override("font_size", 16)
		line.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(112, 48)
		if level == 0:
			button.text = "BELI\n" + _money(item.cost)
		else:
			button.text = "UPGRADE\n" + _money(float(item.cost) * (1.0 + level * 0.8))
		button.pressed.connect(_buy_or_upgrade.bind(i))
		line.add_child(button)

func _buy_or_upgrade(index: int) -> void:
	var item: Dictionary = BUSINESS[index]
	var level: int = int(levels.get(str(index), 0))
	var cost: float = float(item.cost) if level == 0 else float(item.cost) * (1.0 + level * 0.8)
	if cash < cost:
		status_label.text = "Uang belum cukup. Kumpulkan profit terlebih dahulu."
		return
	cash -= cost
	levels[str(index)] = level + 1
	if not owned.has(index):
		owned.append(index)
	status_label.text = "%s berhasil %s!" % [item.name, "dibeli" if level == 0 else "di-upgrade"]
	_recalculate_income()
	_refresh_ui()
	_save_game()

func _recalculate_income() -> void:
	income_per_second = 0.0
	for key in levels.keys():
		var index := int(key)
		var level := int(levels[key])
		income_per_second += float(BUSINESS[index].income) * (1.0 + (level - 1) * 0.5) / 60.0

func _on_tick() -> void:
	cash += income_per_second
	_refresh_ui()
	last_saved += 1
	if last_saved >= 30:
		_save_game()

func _refresh_ui() -> void:
	if is_instance_valid(cash_label):
		cash_label.text = "MODAL  " + _money(cash)
	if is_instance_valid(income_label):
		income_label.text = "PROFIT/MENIT  " + _money(income_per_second * 60.0)
	if is_instance_valid(business_list):
		_rebuild_business_buttons()

func _money(value: float) -> String:
	return "Rp " + _number_format(int(value))

func _number_format(value: int) -> String:
	var s := str(value)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s.substr(i, 1) + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out

func _apply_offline_income() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var previous := int(config.get_value("game", "timestamp", int(Time.get_unix_time_from_system())))
	var elapsed := clampi(int(Time.get_unix_time_from_system()) - previous, 0, MAX_OFFLINE_SECONDS)
	var bonus := income_per_second * elapsed
	if bonus > 0:
		cash += bonus
		status_label.text = "Kamu mendapat profit offline " + _money(bonus)

func _save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "cash", cash)
	config.set_value("game", "levels", levels)
	config.set_value("game", "timestamp", int(Time.get_unix_time_from_system()))
	config.save(SAVE_PATH)
	last_saved = 0
	if is_instance_valid(status_label):
		status_label.text = "Permainan berhasil disimpan."

func _load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		cash = float(config.get_value("game", "cash", cash))
		levels = config.get_value("game", "levels", {})
		for key in levels.keys():
			var idx := int(key)
			if int(levels[key]) > 0 and not owned.has(idx):
				owned.append(idx)
