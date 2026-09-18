@tool
class_name InputPrompt
extends Control

const ICON_DIR: String = "res://ui/input_icons/"
const FRAME_SIZE := 16
const FRAME_COUNT := 4
const ANIM_PRESS := &"press"

@export var input_id: String = "square_down":
	set(value):
		input_id = value
		_apply_icon()

@export var prompt_text: String = "":
	set(value):
		prompt_text = value
		_apply_label()

@export var fps: float = 6.0:
	set(value):
		fps = maxf(value, 0.1)
		_apply_icon()

@onready var content: HBoxContainer = %Content
@onready var sprite: AnimatedSprite2D = %Sprite
@onready var prompt_label: Label = %PromptLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_icon()
	_apply_label()


func configure(p_input_id: String, p_text: String) -> void:
	input_id = p_input_id
	prompt_text = p_text


func _validate_property(property: Dictionary) -> void:
	if property.name != &"input_id":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(_input_ids())


func _input_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for file_name in DirAccess.get_files_at(ICON_DIR):
		if file_name.ends_with(".png"):
			ids.append(file_name.get_basename())
	ids.sort()
	return ids


func _apply_label() -> void:
	if not is_node_ready():
		return
	prompt_label.text = prompt_text
	prompt_label.visible = not prompt_text.is_empty()
	_fit_to_content()


func _apply_icon() -> void:
	if not is_node_ready():
		return
	var path: String = ICON_DIR.path_join("%s.png" % input_id)
	var texture: Texture2D = load(path)
	if texture == null:
		push_warning("InputPrompt: missing icon texture at %s" % path)
		return
	var frames := SpriteFrames.new()
	frames.add_animation(ANIM_PRESS)
	frames.set_animation_loop(ANIM_PRESS, true)
	frames.set_animation_speed(ANIM_PRESS, fps)
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(ANIM_PRESS, atlas)
	sprite.sprite_frames = frames
	sprite.play(ANIM_PRESS)
	_fit_to_content()


func _fit_to_content() -> void:
	var min_size: Vector2 = content.get_combined_minimum_size()
	custom_minimum_size = min_size
	size = min_size
