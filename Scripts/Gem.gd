extends Area3D
class_name GemCollectible

enum GemType { RED, GREEN, BLUE, YELLOW }

@export var type: GemType = GemType.RED

const FLY_DURATION: float = 0.65
const FLY_TARGET_DISTANCE: float = 3.5
const FLY_TARGET_HEIGHT: float = -0.4

var values: Dictionary = {
	GemType.RED: 1,
	GemType.GREEN: 2,
	GemType.BLUE: 5,
	GemType.YELLOW: 10
}

var colors: Dictionary = {
	GemType.RED: Color.RED,
	GemType.GREEN: Color.GREEN,
	GemType.BLUE: Color.BLUE,
	GemType.YELLOW: Color.YELLOW
}

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _gem_material: StandardMaterial3D
var _collected: bool = false
var _base_y: float = 0.0

func _ready() -> void:
	_base_y = global_position.y

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = colors[type]
	mat.roughness = 0.2
	mat.rim_enabled = true
	mat.emission_enabled = true
	mat.emission = colors[type] * 0.35
	mesh.set_surface_override_material(0, mat)
	_gem_material = mat

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return

	rotate_y(2.0 * delta)
	global_position.y = _base_y + sin(Time.get_ticks_msec() * 0.005) * 0.15

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not (body is Player):
		return

	_collected = true
	monitoring = false
	monitorable = false
	if collision_shape:
		collision_shape.disabled = true

	Global.add_gems(values[type])

	var camera: Camera3D = body.get_node_or_null("SpringArm3D/Camera3D")
	await _play_collect_fly(camera)
	queue_free()

func _play_collect_fly(camera: Camera3D) -> void:
	if camera == null:
		return

	var target_pos: Vector3 = camera.global_position
	target_pos -= camera.global_transform.basis.z * FLY_TARGET_DISTANCE
	target_pos += camera.global_transform.basis.y * FLY_TARGET_HEIGHT

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_pos, FLY_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE * 0.2, FLY_DURATION)

	if _gem_material:
		tween.tween_property(_gem_material, "emission_energy_multiplier", 2.0, FLY_DURATION * 0.5)

	await tween.finished
