@tool
class_name Cliff
extends Breakable

enum Kind {
	CORNER_SW,
	CORNER_SE,
	WALL_1,
	WALL_2,
}

const CELL_SIZE := 32.0
const ADJACENCY_SLOP := 4.0

const _SHEET_PATHS: Dictionary = {
	Kind.CORNER_SW: "res://objects/cliff/desert_cliff_corner_SW.png",
	Kind.CORNER_SE: "res://objects/cliff/desert_cliff_corner_SE.png",
	Kind.WALL_1: "res://objects/cliff/desert_cliff_horizontal_wall_1.png",
	Kind.WALL_2: "res://objects/cliff/desert_cliff_horizontal_wall_2.png",
}

const _FRAME_COUNTS: Dictionary = {
	Kind.CORNER_SW: 4,
	Kind.CORNER_SE: 4,
	Kind.WALL_1: 4,
	Kind.WALL_2: 4,
}

@export_enum("corner_SW", "corner_SE", "wall_1", "wall_2")
var kind: int = Kind.WALL_1:
	set(value):
		kind = value as Kind
		frame_index = clampi(frame_index, 0, _frame_count() - 1)
		notify_property_list_changed()
		_apply_sheet()

## Editor preview / starting frame. Overwritten at runtime by adjacency refresh.
@export var frame_index: int = 0:
	set(value):
		frame_index = clampi(value, 0, _frame_count() - 1)
		_apply_sheet()

## When > 0, overrides the auto frame-sized collision box.
@export var collision_size_override: Vector2 = Vector2.ZERO:
	set(value):
		collision_size_override = value
		_apply_sheet()

## When size override is set, used as collision position. Zero + no size override = auto bottom-center box.
@export var collision_offset_override: Vector2 = Vector2.ZERO:
	set(value):
		collision_offset_override = value
		_apply_sheet()

@onready var hitbox_shape: CollisionShape2D = %HitboxShape


func _ready() -> void:
	add_to_group("breakables")
	add_to_group("cliffs")
	_setup_physics()
	_apply_sheet()

	var destroy: DestroyComponent = COMPONENTS.get(DestroyComponent)
	if destroy and not destroy.destroyed.is_connected(_on_cliff_destroyed):
		destroy.destroyed.connect(_on_cliff_destroyed)

	if not Engine.is_editor_hint():
		Cliff.refresh_all_frames.call_deferred(get_tree())


func _validate_property(property: Dictionary) -> void:
	if property.name == &"variants":
		property.usage = PROPERTY_USAGE_NONE
		return
	if property.name != &"frame_index":
		return
	var max_frame: int = maxi(_frame_count() - 1, 0)
	property.hint = PROPERTY_HINT_RANGE
	property.hint_string = "0,%d,1" % max_frame


func _frame_count() -> int:
	return int(_FRAME_COUNTS.get(kind, 1))


func _setup_physics() -> void:
	collision_layer = LevelObject.PHYSICS_LAYER_WORLD
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.bounce = 1.0
	mat.friction = 0.0
	physics_material_override = mat


static func refresh_all_frames(tree: SceneTree) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group("cliffs"):
		var cliff := node as Cliff
		if cliff == null or not is_instance_valid(cliff) or not cliff.is_inside_tree():
			continue
		if cliff.is_queued_for_deletion():
			continue
		cliff._refresh_frame_from_neighbors()


func _on_cliff_destroyed(_node: Node) -> void:
	# Drop out of adjacency immediately — queue_free may still leave us findable
	# until end-of-frame, which would keep neighbors on the "connected" frames.
	remove_from_group("cliffs")
	var tree := get_tree()
	if tree == null:
		return
	Cliff.refresh_all_frames.call_deferred(tree)


func _refresh_frame_from_neighbors() -> void:
	var has_left: bool = _has_cliff_at(Vector2(-CELL_SIZE, 0.0))
	var has_right: bool = _has_cliff_at(Vector2(CELL_SIZE, 0.0))
	var has_above: bool = _has_cliff_at(Vector2(0.0, -CELL_SIZE))
	frame_index = _resolve_frame(has_left, has_right, has_above)


func _resolve_frame(has_left: bool, has_right: bool, has_above: bool) -> int:
	match kind:
		Kind.CORNER_SW:
			if has_above and has_right:
				return 0
			if not has_above and has_right:
				return 1
			return 2
		Kind.CORNER_SE:
			if has_above and has_left:
				return 0
			if not has_above and has_left:
				return 1
			return 2
		Kind.WALL_1, Kind.WALL_2:
			if has_left and has_right:
				return 0
			if not has_left and has_right:
				return 1
			if has_left and not has_right:
				return 2
			return 3
		_:
			return 0


func _has_cliff_at(offset: Vector2) -> bool:
	var target: Vector2 = global_position + offset
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("cliffs"):
		var other := node as Cliff
		if other == null or other == self or not is_instance_valid(other):
			continue
		if not other.is_inside_tree() or other.is_queued_for_deletion():
			continue
		if other.global_position.distance_to(target) <= ADJACENCY_SLOP:
			return true
	return false


func _apply_sheet() -> void:
	if not is_node_ready():
		return
	if sprite == null or collision_shape == null:
		return

	var path: String = String(_SHEET_PATHS.get(kind, ""))
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_warning("Cliff: missing sheet at %s" % path)
		return

	var frame_count: int = _frame_count()
	sprite.texture = texture
	sprite.hframes = 1
	sprite.vframes = frame_count
	sprite.frame = clampi(frame_index, 0, frame_count - 1)

	var tex_size: Vector2 = texture.get_size()
	var frame_size := Vector2(tex_size.x / float(sprite.hframes), tex_size.y / float(frame_count))
	# Origin at bottom-center of the frame art.
	sprite.offset = Vector2(0.0, -frame_size.y * 0.5)

	var box_size: Vector2 = frame_size
	var box_offset := Vector2(0.0, -frame_size.y * 0.5)
	if collision_size_override.x > 0.0 and collision_size_override.y > 0.0:
		box_size = collision_size_override
		box_offset = collision_offset_override

	var body_rect := RectangleShape2D.new()
	body_rect.size = box_size
	collision_shape.shape = body_rect
	collision_shape.position = box_offset

	if hitbox_shape == null:
		return
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = box_size
	hitbox_shape.shape = hit_rect
	hitbox_shape.position = box_offset
