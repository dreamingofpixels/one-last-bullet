class_name Players
extends Object

## Static roster helpers for the `player` group. No autoload — call with a SceneTree.


static func all(tree: SceneTree) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if tree == null:
		return result
	for node in tree.get_nodes_in_group("player"):
		if node is Node2D and is_instance_valid(node):
			result.append(node as Node2D)
	return result


static func count(tree: SceneTree) -> int:
	return all(tree).size()


static func closest_to(tree: SceneTree, pos: Vector2) -> Node2D:
	var closest: Node2D = null
	var best_dist_sq: float = INF
	for candidate in all(tree):
		var dist_sq: float = pos.distance_squared_to(candidate.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			closest = candidate
	return closest
