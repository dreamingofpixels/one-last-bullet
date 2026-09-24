@tool
class_name InputPrompt
extends Control

const ICON_DIR: String = "res://ui/input_icons/"
const FRAME_SIZE := 16
const FRAME_COUNT := 4
const ANIM_PRESS := &"press"

## Keyboard/mouse vs gamepad sheet basenames per logical action.
const ACTION_ICONS: Dictionary = {
	&"upgrade": {&"kb": "keyboard_e_down", &"pad": "square_down"},
	&"activate": {&"kb": "keyboard_space_down", &"pad": "triangle_down"},
	&"ritual_cancel": {&"kb": "keyboard_q_down", &"pad": "circle_down"},
	&"toggle_orb_info": {&"kb": "keyboard_C_down", &"pad": "cross_down"},
	&"pickup": {&"kb": "mouse_right_click", &"pad": "L2_down"},
}

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


func configure_action(action: StringName, text: String, keyboard_mouse: bool) -> void:
	var icons: Variant = ACTION_ICONS.get(action)
	if icons == null or typeof(icons) != TYPE_DICTIONARY:
		push_warning("InputPrompt: unknown action %s" % String(action))
		configure("square_down", text)
		return
	var table: Dictionary = icons as Dictionary
	var key: StringName = &"kb" if keyboard_mouse else &"pad"
	var sheet: String = String(table.get(key, "square_down"))
	configure(sheet, text)


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
