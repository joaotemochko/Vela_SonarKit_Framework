extends Node3D
class_name LyraEmitter

var lyra_Core

@export_group("Topology Configuration")
@export var interaction_type: LyraCore.InteractionType = LyraCore.InteractionType.OBSTACLE 
@export var max_range: float = 12.0 
@export var audio_sample: AudioStream = load("res://addons/Lyra_Framework/wall_hum.ogg") 
@export var audio_db: float = 0.0
@export_enum("Collision3D", "Area3D", "Mesh3D") var radar: int
@export var bus: String = "Master"

var _is_inside: bool = false
var _collision_shapes: Array = []
var _active_player: AudioStreamPlayer3D = null

func _ready():
	# Search for the Core in the tree or create one if it's the first emitter to run.
	if LyraCore.instance == null:
		var new_core = load("res://addons/Lyra_Framework/lyra_core.gd").new()
		get_tree().root.add_child.call_deferred(new_core)
		lyra_Core = new_core
	else:
		lyra_Core = LyraCore.instance
	
	_find_all_collision_shapes()

func _find_all_collision_shapes():
	_collision_shapes.clear()
	var parent = get_parent()
	for child in parent.get_children():
		# We checked radar == number for type
		if child is CollisionShape3D and radar == 0:
			_collision_shapes.append(child)
		elif child is Area3D and radar == 1:
			_collision_shapes.append(child)
		elif child is MeshInstance3D and radar == 2:
			_collision_shapes.append(child)

func _process(_delta):
	# Safety: If the LyraCore Singleton does not exist in the tree, it will not process.
	if not is_instance_valid(lyra_Core): return 
	
	# Filter the list to remove references to objects that have been deleted.
	_collision_shapes = _collision_shapes.filter(func(node): return is_instance_valid(node) and node.is_inside_tree())
	
	if _collision_shapes.is_empty():
		if _is_inside: _exit_emitter(0.0, Vector3.ZERO)
		return
	# --------------------------------------------------

	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	var nearest_data = _get_nearest_collision_point(cam.global_position)
	var dist = nearest_data.distance
	
	if dist < max_range:
		if not _is_inside:
			# The player is being asked to contact Singleton Global.
			_active_player = lyra_Core.request_player(self)
			_is_inside = true
			lyra_Core.log_event("ENTER", get_parent().name, interaction_type, dist, cam.global_position)
		
		if is_instance_valid(_active_player) and _active_player.is_inside_tree():
			_active_player.global_position = nearest_data.position
			_update_audio_parameters(dist)
	elif _is_inside:
		_exit_emitter(dist, cam.global_position)

func _get_nearest_collision_point(target_pos: Vector3) -> Dictionary:
	var best_dist = 9999.0
	var best_pos = global_position
	for shape in _collision_shapes:
		var d = shape.global_position.distance_to(target_pos)
		if d < best_dist:
			best_dist = d
			best_pos = shape.global_position
	return {"distance": best_dist, "position": best_pos}

func _update_audio_parameters(dist: float):
	if not is_instance_valid(_active_player) or not _active_player.is_inside_tree(): 
		return
	
	var weight = lyra_Core.get_presence_weight(dist, max_range)
	_active_player.pitch_scale = lyra_Core.get_dynamic_pitch(weight, interaction_type)
	_active_player.volume_db = linear_to_db(weight)
	
	if not _active_player.playing:
		_active_player.play()

func _exit_emitter(dist, cam_pos):
	_is_inside = false
	lyra_Core.log_event("EXIT", get_parent().name, interaction_type, dist, cam_pos) 
	if is_instance_valid(_active_player):
		lyra_Core.release_player(_active_player)
	_active_player = null
