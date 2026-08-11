class_name LevelObject
extends StaticBody2D

const PHYSICS_LAYER_WORLD := 1

@export var variants: Array[LevelObjectVariant] = []

@onready var sprite: Sprite2D = %Sprite2D
@onready var collision_shape: CollisionShape2D = %CollisionShape2D


func _ready() -> void:
	collision_layer = PHYSICS_LAYER_WORLD
	collision_mask = 0

	var mat := PhysicsMaterial.new()
	mat.bounce = 1.0
	mat.friction = 0.0
	physics_material_override = mat

	if variants.is_empty():
		push_error("%s has no variants configured" % name)
		return

	_apply_variant(variants[randi() % variants.size()])


func _apply_variant(variant: LevelObjectVariant) -> void:
	sprite.texture = variant.texture
	if variant.texture != null:
		var tex_size := variant.texture.get_size()
		# Origin at bottom-center of the art.
		sprite.offset = Vector2(0.0, -tex_size.y * 0.5) + variant.texture_offset
	else:
		sprite.offset = variant.texture_offset

	var rect := RectangleShape2D.new()
	rect.size = variant.collision_size
	collision_shape.shape = rect
	collision_shape.position = variant.collision_offset
