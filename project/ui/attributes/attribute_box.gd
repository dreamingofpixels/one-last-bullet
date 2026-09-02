@tool
class_name AttributeBox
extends HBoxContainer

enum ValueFormat {
	DECIMAL,
	PERCENT,
}

enum DecimalPlaces {
	ZERO,
	ONE,
	TWO,
}

const ICON_DIR: String = "res://ui/attributes/"

@export var icon_id: String = "damage_icon":
	set(value):
		icon_id = value
		_apply_icon()

@export var value: float = 10.4:
	set(new_value):
		value = new_value
		_apply_value()

@export var value_format: ValueFormat = ValueFormat.DECIMAL:
	set(value):
		value_format = value
		_apply_value()

@export var decimal_places: DecimalPlaces = DecimalPlaces.TWO:
	set(new_value):
		decimal_places = new_value
		_apply_value()

@onready var icon: TextureRect = %Icon
@onready var value_label: Label = %Value


func _ready() -> void:
	_apply_icon()
	_apply_value()


func _validate_property(property: Dictionary) -> void:
	if property.name != &"icon_id":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(_icon_ids())


func _icon_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for file_name in DirAccess.get_files_at(ICON_DIR):
		if file_name.ends_with(".png"):
			ids.append(file_name.get_basename())
	ids.sort()
	return ids


func _apply_icon() -> void:
	if not is_node_ready():
		return
	var path: String = ICON_DIR.path_join("%s.png" % icon_id)
	var texture: Texture2D = load(path)
	if texture == null:
		push_warning("AttributeBox: missing icon texture at %s" % path)
		return
	if icon.texture == texture:
		return
	icon.texture = texture


func _apply_value() -> void:
	if not is_node_ready():
		return
	var text: String = _format_value(value, value_format, decimal_places)
	if value_label.text == text:
		return
	value_label.text = text


static func _format_value(raw_value: float, format: ValueFormat, places: DecimalPlaces) -> String:
	var display_value: float = raw_value
	if format == ValueFormat.PERCENT:
		display_value = raw_value * 100.0
	var step: float = pow(10.0, -float(places))
	display_value = snappedf(display_value, step)
	var formatted: String = ("%." + str(int(places)) + "f") % display_value
	if format == ValueFormat.PERCENT:
		return formatted + "%"
	return formatted
