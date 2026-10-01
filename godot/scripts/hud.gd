extends CanvasLayer

signal start_requested
signal exit_requested
signal quality_requested

const INK := Color("eee9dd")
const MUTED := Color("adb8b8")
const AMBER := Color("d7a05f")

var root: Control
var play_ui: Control
var menu: Control
var inventory_panel: PanelContainer
var inventory_text: Label
var objective: Label
var prompt: Label
var toast: Label
var stamina_bar: ProgressBar
var warmth_bar: ProgressBar
var performance: Label
var menu_title: Label
var menu_description: Label
var start_button: Button
var quality_button: Button
var toast_time := 0.0


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/BarlowCondensed-Regular.ttf")
	theme.default_font_size = 20
	root.theme = theme
	add_child(root)
	create_vignette()
	create_play_ui()
	create_menu()
	create_inventory()


func label(parent: Control, text: String, size: int, at: Vector2, color: Color = INK) -> Label:
	var control := Label.new()
	control.text = text
	control.position = at
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	control.add_theme_constant_override("shadow_offset_y", 2)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control


func create_vignette() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec2 p=UV*2.0-1.0; float v=smoothstep(0.45,1.35,length(p)); COLOR=vec4(0.015,0.023,0.028,v*0.35); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	overlay.material = material
	root.add_child(overlay)


func create_play_ui() -> void:
	play_ui = Control.new()
	play_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_ui)
	label(play_ui, "KÜL ŞEHİR", 29, Vector2(32, 23))
	label(play_ui, "KARANTİNA BÖLGESİ  /  07", 14, Vector2(33, 62), MUTED)
	var mission_box := Control.new()
	mission_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mission_box.position = Vector2(-305, 27)
	play_ui.add_child(mission_box)
	label(mission_box, "İLK IŞIK", 17, Vector2.ZERO, AMBER)
	objective = label(mission_box, "Sokaktaki malzemeleri topla   0 / 3", 21, Vector2(0, 24))
	label(mission_box, "Yakıt · Erzak · Metal parça", 16, Vector2(0, 55), MUTED)
	var status := Control.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.position = Vector2(32, -118)
	play_ui.add_child(status)
	label(status, "DAYANIKLILIK", 13, Vector2.ZERO, MUTED)
	stamina_bar = meter(status, Vector2(0, 24), INK)
	label(status, "VÜCUT ISISI", 13, Vector2(0, 42), AMBER)
	warmth_bar = meter(status, Vector2(0, 66), AMBER)
	var keys := label(play_ui, "W A S D  Hareket     SHIFT  Koş     E  Etkileşim     B  Çanta     F  Fener     ESC  Menü", 17, Vector2.ZERO, MUTED)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	keys.offset_left = -655
	keys.offset_top = -42
	keys.offset_right = -25
	keys.offset_bottom = -15
	prompt = label(play_ui, "", 24, Vector2.ZERO)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.offset_left = -230
	prompt.offset_right = 230
	prompt.offset_top = 86
	prompt.offset_bottom = 125
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = label(play_ui, "", 22, Vector2.ZERO, AMBER)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -400
	toast.offset_right = 400
	toast.offset_top = 103
	toast.offset_bottom = 142
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	performance = label(play_ui, "", 15, Vector2(32, 93), MUTED)
	performance.hide()
	var dot := ColorRect.new()
	dot.color = Color(0.94, 0.91, 0.85, 0.55)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-1, -1)
	dot.size = Vector2(2, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_ui.add_child(dot)


func meter(parent: Control, at: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size", 1)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.8, 0.8, 0.8, 0.13)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	bar.size = Vector2(165, 4)
	parent.add_child(bar)
	bar.set_deferred("size", Vector2(165, 4))
	return bar


func create_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float a=mix(0.93,0.08,smoothstep(0.1,0.9,UV.x)); COLOR=vec4(0.025,0.037,0.045,a); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	backdrop.material = material
	menu.add_child(backdrop)
	label(menu, "BİR HAYATTA KALMA HİKÂYESİ", 17, Vector2(58, 54), AMBER)
	menu_title = label(menu, "KÜL\nŞEHİR", 108, Vector2(54, 98))
	menu_title.add_theme_font_override("font", load("res://assets/fonts/BarlowCondensed-SemiBold.ttf"))
	menu_title.add_theme_constant_override("line_spacing", -26)
	menu_description = label(menu, "Şehir sustu. Hayat devam ediyor.\n\nSoğuk sokakta malzeme ara.\nSobaya dön. İlk geceye hazırlan.", 23, Vector2(60, 352), MUTED)
	start_button = button(menu, "SOKAĞA GİR    →", Vector2(60, 493), true)
	start_button.pressed.connect(func(): start_requested.emit())
	quality_button = button(menu, "GÖRÜNTÜ  /  DENGELİ", Vector2(60, 553), false)
	quality_button.pressed.connect(func(): quality_requested.emit())
	var exit_button := button(menu, "MASAÜSTÜNE DÖN", Vector2(60, 600), false)
	exit_button.pressed.connect(func(): exit_requested.emit())
	var version := label(menu, "İLK SOKAK  /  OYNANABİLİR GÖRSEL PROTOTİP", 15, Vector2.ZERO, MUTED)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -348
	version.offset_right = -20
	version.offset_top = -65
	version.offset_bottom = -43
	var credits := label(menu, "Çevre: Poly Haven · Karakter: Mixamo · Motor: Godot", 13, Vector2.ZERO, MUTED)
	credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	credits.offset_left = -348
	credits.offset_right = -20
	credits.offset_top = -40
	credits.offset_bottom = -18
	play_ui.hide()


func button(parent: Control, text: String, at: Vector2, primary: bool) -> Button:
	var control := Button.new()
	control.text = text
	control.position = at
	control.size = Vector2(295, 46)
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT
	control.add_theme_font_size_override("font_size", 22 if primary else 17)
	control.add_theme_color_override("font_color", Color("171e20") if primary else MUTED)
	var normal := StyleBoxFlat.new()
	normal.bg_color = AMBER if primary else Color(0, 0, 0, 0)
	normal.content_margin_left = 15.0 if primary else 0.0
	control.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("ebbc7e") if primary else Color(0.6, 0.65, 0.65, 0.12)
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_stylebox_override("pressed", hover)
	parent.add_child(control)
	return control


func create_inventory() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inventory_panel.position = Vector2(-210, -155)
	inventory_panel.size = Vector2(420, 310)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.065, 0.96)
	style.border_color = Color("6f746b")
	style.set_border_width_all(1)
	style.content_margin_left = 28
	style.content_margin_top = 24
	style.content_margin_right = 28
	style.content_margin_bottom = 24
	inventory_panel.add_theme_stylebox_override("panel", style)
	root.add_child(inventory_panel)
	inventory_text = label(inventory_panel, "", 24, Vector2.ZERO)
	inventory_panel.hide()


func show_menu(paused: bool) -> void:
	menu.show()
	play_ui.hide()
	inventory_panel.hide()
	start_button.text = "DEVAM ET    →" if paused else "SOKAĞA GİR    →"
	menu_description.text = "Bir nefes al.\n\nSokak seni bekliyor.\nKaldığın yerden devam edebilirsin." if paused else "Şehir sustu. Hayat devam ediyor.\n\nSoğuk sokakta malzeme ara.\nSobaya dön. İlk geceye hazırlan."
	start_button.grab_focus()


func show_game() -> void:
	menu.hide()
	play_ui.show()
	inventory_panel.hide()


func notify(text: String) -> void:
	toast.text = text
	toast_time = 4.0


func update_status(stamina: float, warmth: float, count: int, completed: bool) -> void:
	stamina_bar.value = stamina
	warmth_bar.value = warmth
	objective.text = "Hazırlık tamamlandı. Sokak senin." if completed else ("Sobaya dön. Hazırlığını tamamla." if count == 3 else "Malzemeleri topla   %d / 3" % count)
	performance.text = "%d FPS  ·  %.1f ms  ·  %d draw" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


func show_inventory(items: Array[String]) -> void:
	inventory_text.text = "ÇANTA\n────────────────────\n" + ("Henüz malzeme yok." if items.is_empty() else "\n".join(items)) + "\n\nB / ESC   Kapat"
	inventory_panel.show()


func _process(delta: float) -> void:
	toast_time = maxf(0.0, toast_time - delta)
	toast.modulate.a = minf(1.0, toast_time)
