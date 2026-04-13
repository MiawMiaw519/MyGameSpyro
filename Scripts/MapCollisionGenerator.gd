class_name MapCollisionGenerator
extends Node3D

const COLLIDER_BODY_NAME: String = "__auto_collision_body"
const COLLIDER_SHAPE_NAME: String = "__auto_collision_shape"

@export var include_nested_meshes: bool = true
@export var exclude_name_keywords: PackedStringArray = [
	"plane",
	"circle",
	"cloud",
	"sky",
	"fog",
	"fx",
	"vfx",
	"particle",
	"water"
]
@export var require_parent_keywords: PackedStringArray = []

func _ready() -> void:
	_generate_collisions()

func _generate_collisions() -> void:
	_clear_existing_collisions()
	var meshes: Array[Node] = find_children("*", "MeshInstance3D", include_nested_meshes, false)

	for node in meshes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		if mesh_instance.mesh == null:
			continue
		if not _should_generate_collision(mesh_instance):
			continue

		var collision_shape_resource: Shape3D = mesh_instance.mesh.create_trimesh_shape()
		if collision_shape_resource == null:
			continue

		var body: StaticBody3D = StaticBody3D.new()
		body.name = COLLIDER_BODY_NAME
		body.collision_layer = 1
		body.collision_mask = 1
		mesh_instance.add_child(body)

		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = COLLIDER_SHAPE_NAME
		shape.shape = collision_shape_resource
		body.add_child(shape)

func _clear_existing_collisions() -> void:
	var bodies: Array[Node] = find_children(COLLIDER_BODY_NAME, "StaticBody3D", true, false)
	for node in bodies:
		node.queue_free()

func _should_generate_collision(mesh_instance: MeshInstance3D) -> bool:
	var lineage: String = _build_lineage_name(mesh_instance).to_lower()

	for keyword in exclude_name_keywords:
		if keyword.is_empty():
			continue
		if lineage.find(keyword.to_lower()) != -1:
			return false

	if require_parent_keywords.is_empty():
		return true

	for keyword in require_parent_keywords:
		if keyword.is_empty():
			continue
		if lineage.find(keyword.to_lower()) != -1:
			return true

	return false

func _build_lineage_name(node: Node) -> String:
	var parts: PackedStringArray = []
	var current: Node = node
	while current != null and current != self:
		parts.append(current.name)
		current = current.get_parent()
	return " ".join(parts)
