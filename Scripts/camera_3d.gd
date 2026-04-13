extends Camera3D

@export var speed := 10.0
@export var mouse_sensitivity := 0.003

var rotation_x := 0.0
var rotation_y := 0.0

func _input(event):
	if event is InputEventMouseMotion:
		rotation_y -= event.relative.x * mouse_sensitivity
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, -1.5, 1.5)
		rotation_degrees.x = rad_to_deg(rotation_x)
		rotation_degrees.y = rad_to_deg(rotation_y)

func _process(delta):
	var dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		dir += transform.basis.x
	if Input.is_action_pressed("move_up"):
		dir += transform.basis.y
	if Input.is_action_pressed("move_down"):
		dir -= transform.basis.y

	if dir != Vector3.ZERO:
		dir = dir.normalized()
		global_translate(dir * speed * delta)
