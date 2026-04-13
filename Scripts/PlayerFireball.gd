extends Area3D
class_name PlayerFireball

@export var speed: float = 46.0
@export var lifetime: float = 2.2
@export var damage_type: String = "flame"

var direction: Vector3 = Vector3.FORWARD
var owner_node: Node = null

@onready var shot_sfx: AudioStreamPlayer3D = $ShotSFX

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = true
	set_physics_process(true)

	_play_shot_sound()

	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()

func _play_shot_sound() -> void:
	if shot_sfx == null:
		return

	if shot_sfx.stream:
		shot_sfx.play()
		return

	# Fallback: synthesize a short "whoosh" if no audio file is assigned.
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.12
	shot_sfx.stream = generator
	shot_sfx.play()

	var playback: AudioStreamGeneratorPlayback = shot_sfx.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(generator.mix_rate * 0.1)
	for i in sample_count:
		var t: float = float(i) / float(sample_count)
		var freq: float = lerp(980.0, 220.0, t)
		var amp: float = (1.0 - t) * 0.18
		var wave: float = sin(TAU * freq * (float(i) / generator.mix_rate)) * amp
		playback.push_frame(Vector2(wave, wave))

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta

func _on_body_entered(body: Node) -> void:
	if body == owner_node:
		return

	if body.has_method("take_damage"):
		var is_vulnerable: bool = true
		if body.has_method("is_vulnerable_to_damage_type"):
			is_vulnerable = bool(body.call("is_vulnerable_to_damage_type", damage_type))

		if not is_vulnerable:
			if owner_node != null and owner_node.has_method("show_fire_immune_hint") and damage_type == "flame":
				owner_node.call("show_fire_immune_hint")
			queue_free()
			return

		body.call("take_damage", damage_type)
		queue_free()
		return

	# Hit world geometry or non-damageable object
	if body is StaticBody3D or body is CSGShape3D or body is CharacterBody3D or body is RigidBody3D:
		queue_free()
