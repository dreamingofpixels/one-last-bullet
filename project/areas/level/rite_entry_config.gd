@tool
class_name RiteEntryConfig
extends Resource

@export var rite_id: StringName = &""


func _validate_property(property: Dictionary) -> void:
	if property.name != &"rite_id":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(RiteSlot.rite_ids_for_inspector(rite_id))
