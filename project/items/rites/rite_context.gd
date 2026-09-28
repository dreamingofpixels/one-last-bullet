class_name RiteContext
extends RefCounted

## Shared payload for rite notify / resolve hooks. Unused fields stay at defaults.

var status_id: StatusComponent.StatusId = StatusComponent.StatusId.BLIGHT
var stacks: int = 0
var source: Node = null
var victim: Node = null
var other: Node = null
var position: Vector2 = Vector2.ZERO
## Ward (and similar) set this to skip HealthComponent.take_damage entirely.
var blocked: bool = false
