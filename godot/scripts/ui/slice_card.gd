extends Control

signal slice_hovered(slice_name: String, description: String)
signal slice_selected(slice_name: String)

var slice_name: String = ""
var slice_color: Color = Color.WHITE
var description: String = ""
var selected: bool = false
var hovered: bool = false

const CARD_SIZE = Vector2(105, 140)
const SHAPE_SIZE = 44.0

func _init(p_name: String, p_color: Color, p_desc: String) -> void:
	slice_name = p_name
	slice_color = p_color
	description = p_desc
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	# Card background
	var bg_color = Color(0.22, 0.22, 0.25) if not selected else Color(0.28, 0.28, 0.35)
	draw_rect(Rect2(Vector2.ZERO, CARD_SIZE), bg_color)
	# Border
	var border_color = slice_color if selected else Color(0.4, 0.4, 0.4)
	draw_rect(Rect2(Vector2.ZERO, CARD_SIZE), border_color, false, 2.0)

	# Octagon shape centered in upper portion
	var center = Vector2(CARD_SIZE.x / 2.0, 54.0)
	var points = PackedVector2Array()
	var sides = 8
	for i in sides:
		var angle = (TAU / sides) * i - PI / sides
		points.append(center + Vector2(cos(angle), sin(angle)) * SHAPE_SIZE)
	draw_colored_polygon(points, slice_color)
	# Inner darker octagon
	var inner_points = PackedVector2Array()
	for i in sides:
		var angle = (TAU / sides) * i - PI / sides
		inner_points.append(center + Vector2(cos(angle), sin(angle)) * (SHAPE_SIZE * 0.6))
	draw_colored_polygon(inner_points, slice_color.darkened(0.4))

	# Slice name text drawn via Label child — handled in _ready

func _ready() -> void:
	var name_label = Label.new()
	name_label.text = slice_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -28
	name_label.offset_bottom = -6
	add_child(name_label)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected = true
		slice_selected.emit(slice_name)
		queue_redraw()

func _on_mouse_entered() -> void:
	hovered = true
	slice_hovered.emit(slice_name, description)

func _on_mouse_exited() -> void:
	hovered = false

func deselect() -> void:
	selected = false
	queue_redraw()
