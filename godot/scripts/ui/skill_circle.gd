extends Control

var filled: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(16, 16)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _draw() -> void:
	var center = size / 2.0
	var r = 6.0
	if filled:
		draw_circle(center, r, Color(1.0, 0.85, 0.2, 1.0))
		draw_arc(center, r, 0, TAU, 24, Color(1.0, 0.9, 0.3, 1.0), 1.5)
	else:
		draw_circle(center, r, Color(0.25, 0.25, 0.28, 1.0))
		draw_arc(center, r, 0, TAU, 24, Color(0.6, 0.6, 0.6, 1.0), 1.5)

func set_filled(value: bool) -> void:
	filled = value
	queue_redraw()
