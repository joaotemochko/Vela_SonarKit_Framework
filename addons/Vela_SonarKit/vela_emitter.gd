extends Node3D
class_name VelaEmitter

var Vela_core: VelaCore

enum SearchMode { PARENT_COLLIDERS, PARENT_MESHES, PARENT_AREAS }

## ============================================================================
## CONFIGURAÇÃO
## ============================================================================

@export_group("Targeting")
## Como encontrar a geometria do objeto pai
@export var search_mode: SearchMode = SearchMode.PARENT_COLLIDERS
## Mostrar debug visual
@export var debug_mode: bool = false

@export_group("Logic")
## Tipo de categoria sonora
@export var category_type: VelaCore.CategoryType = VelaCore.CategoryType.BOUNDARY

@export_group("Audio")
## Som a ser emitido
@export var audio_sample: AudioStream
## Bus de áudio
@export var audio_bus: String = "Master"
## Volume base
@export_range(-20.0, 20.0, 0.5) var volume_db_base: float = 0.0

@export_subgroup("Frequency")
## Frequência mínima (longe)
@export var min_hz: float = 200.0
## Frequência máxima (perto)
@export var max_hz: float = 800.0

@export_group("Ranges")
## Distância de ativação do som contínuo
@export var activation_range: float = 4.0

## ============================================================================
## VARIÁVEIS INTERNAS
## ============================================================================

var _local_player: AudioStreamPlayer3D = null
var _geometry_nodes: Array[Node3D] = []
var _is_active: bool = false
var _retry_timer: float = 0.0
var _debug_mesh_instance: MeshInstance3D = null
var platform_tolerance_y: float = 0.1

## Tracking para métricas de GOAL
var _tracking_player: bool = false
var _tracking_start_time: float = 0.0
var _tracking_start_pos: Vector3 = Vector3.ZERO
var _tracking_distance: float = 0.0
var _tracking_last_pos: Vector3 = Vector3.ZERO
var _optimal_distance: float = 0.0

## ============================================================================
## INICIALIZAÇÃO
## ============================================================================

func _ready():
	_setup_local_audio()
	_connect_to_core()
	if debug_mode:
		_create_debug_mesh()
	_init_geometry_delayed()

func _setup_local_audio():
	if audio_sample == null:
		# Tentar som padrão
		var paths = ["res://addons/Vela_Framework/tone.ogg", "res://addons/Vela/tone.ogg"]
		for path in paths:
			if ResourceLoader.exists(path):
				audio_sample = load(path)
				break
	
	if audio_sample == null:
		push_warning("[Vela] Emitter sem som: " + name)
		return
	
	_local_player = AudioStreamPlayer3D.new()
	_local_player.name = "EmitterVoice"
	_local_player.stream = audio_sample
	_local_player.bus = audio_bus
	_local_player.unit_size = 15.0
	_local_player.max_distance = 60.0
	_local_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_local_player)

func _init_geometry_delayed():
	await get_tree().process_frame
	await get_tree().process_frame
	_find_geometry_nodes()
	
	# Iniciar tracking se for GOAL
	if category_type == VelaCore.CategoryType.GOAL:
		call_deferred("_start_tracking")

func _connect_to_core():
	if not is_inside_tree():
		await ready
	
	if VelaCore.instance:
		Vela_core = VelaCore.instance
	else:
		var tree = get_tree()
		if tree == null:
			push_error("[Vela] Emitter: get_tree() null")
			return
		
		var found = tree.root.find_child("VelaCore", true, false)
		if found:
			Vela_core = found
			VelaCore.instance = found
		else:
			var new_core = VelaCore.new()
			new_core.name = "VelaCore"
			tree.root.call_deferred("add_child", new_core)
			Vela_core = new_core
			VelaCore.instance = new_core
			await tree.process_frame
	
	if Vela_core:
		Vela_core.register_emitter(self)

func _start_tracking():
	"""Inicia tracking de distância para GOAL"""
	if not is_instance_valid(Vela_core):
		return
	if not Vela_core.is_inside_tree():
		return
	
	var p_pos = Vela_core._get_player_pos()
	if p_pos == Vector3.ZERO:
		return
	
	_tracking_player = true
	_tracking_start_time = Time.get_unix_time_from_system()
	_tracking_start_pos = p_pos
	_tracking_last_pos = p_pos
	_tracking_distance = 0.0
	_optimal_distance = p_pos.distance_to(global_position)

## ============================================================================
## LOOP PRINCIPAL
## ============================================================================

func _process(delta):
	# Retry se geometria não encontrada
	if _geometry_nodes.is_empty():
		_retry_timer += delta
		if _retry_timer > 2.0:
			_retry_timer = 0.0
			_find_geometry_nodes()
		return
	
	if not is_instance_valid(Vela_core):
		return
	
	var p_pos = Vela_core._get_player_pos()
	if p_pos == Vector3.ZERO:
		return
	
	# Atualizar tracking para GOAL
	if _tracking_player and category_type == VelaCore.CategoryType.GOAL:
		var moved = p_pos.distance_to(_tracking_last_pos)
		_tracking_distance += moved
		_tracking_last_pos = p_pos
	
	# Calcular distância
	var data = get_smart_distance(p_pos)
	var dist = data.distance
	var pos = data.position
	
	# Debug visual
	if debug_mode and _debug_mesh_instance:
		_draw_debug_lines(p_pos)
	
	# Atualizar áudio contínuo
	var should_play = false
	var intensity = 0.0
	if dist < activation_range:
		should_play = true
		intensity = clamp(1.0 - (dist / activation_range), 0.0, 1.0)
	
	_update_audio(should_play, intensity, pos)

## ============================================================================
## CÁLCULO DE DISTÂNCIA INTELIGENTE
## ============================================================================

func get_smart_distance(target_pos: Vector3) -> Dictionary:
	"""
	Calcula distância inteligente baseada no tipo:
	- GOAL/INTERACTABLE: ponto a ponto
	- BOUNDARY/OBSTACLE/HAZARD: distância à superfície
	"""
	if category_type == VelaCore.CategoryType.GOAL or category_type == VelaCore.CategoryType.INTERACTABLE:
		return {"distance": global_position.distance_to(target_pos), "position": global_position}
	
	var min_dist = 99999.0
	var best_pos = global_position
	
	for node in _geometry_nodes:
		if not is_instance_valid(node):
			continue
		
		var local_aabb = _get_aabb_from_node(node)
		var trans = node.global_transform
		var center = trans * (local_aabb.position + local_aabb.size / 2)
		var size = local_aabb.size * trans.basis.get_scale()
		var global_aabb = AABB(center - size / 2, size)
		
		var is_platform = target_pos.y >= (global_aabb.end.y - platform_tolerance_y)
		var extents = size / 2.0
		var offset = target_pos - center
		var dist_calculated = 0.0
		var snap_pos = Vector3.ZERO
		
		if is_platform:
			# PLATAFORMA: distância à borda
			var dx = abs(offset.x) - extents.x
			var dz = abs(offset.z) - extents.z
			var dist_outside = Vector2(max(dx, 0), max(dz, 0)).length()
			
			if dist_outside > 0:
				dist_calculated = dist_outside
			else:
				var dist_edge_x = abs(abs(offset.x) - extents.x)
				var dist_edge_z = abs(abs(offset.z) - extents.z)
				dist_calculated = min(dist_edge_x, dist_edge_z)
			
			var sx = clamp(offset.x, -extents.x, extents.x)
			var sz = clamp(offset.z, -extents.z, extents.z)
			if (extents.x - abs(offset.x)) < (extents.z - abs(offset.z)):
				sx = extents.x * sign(offset.x)
			else:
				sz = extents.z * sign(offset.z)
			snap_pos = Vector3(sx, 0, sz) + center
			snap_pos.y = target_pos.y
		else:
			# PAREDE: distância 3D
			var dx = abs(offset.x) - extents.x
			var dy = abs(offset.y) - extents.y
			var dz = abs(offset.z) - extents.z
			var d_out = Vector3(max(dx, 0), max(dy, 0), max(dz, 0)).length()
			var d_in = min(max(dx, max(dy, dz)), 0.0)
			dist_calculated = d_out + abs(d_in)
			
			var sx = clamp(offset.x, -extents.x, extents.x)
			var sy = clamp(offset.y, -extents.y, extents.y)
			var sz = clamp(offset.z, -extents.z, extents.z)
			var dist_x = abs(abs(offset.x) - extents.x)
			var dist_y = abs(abs(offset.y) - extents.y)
			var dist_z = abs(abs(offset.z) - extents.z)
			if dist_x < dist_y and dist_x < dist_z:
				sx = extents.x * sign(offset.x)
			elif dist_y < dist_z:
				sy = extents.y * sign(offset.y)
			else:
				sz = extents.z * sign(offset.z)
			snap_pos = Vector3(sx, sy, sz) + center
		
		if dist_calculated < min_dist:
			min_dist = dist_calculated
			best_pos = snap_pos
	
	return {"distance": min_dist, "position": best_pos}

## ============================================================================
## ÁUDIO CONTÍNUO
## ============================================================================

func _update_audio(active: bool, intensity: float, pos: Vector3):
	if not _local_player:
		return
	
	if active:
		_local_player.global_position = pos
		var hz = lerp(min_hz, max_hz, intensity)
		_local_player.pitch_scale = hz / 440.0
		var db = lerp(-15.0, 0.0, intensity) + volume_db_base
		_local_player.volume_db = db
		if not _local_player.playing:
			_local_player.play()
	else:
		if _local_player.playing:
			_local_player.stop()

## ============================================================================
## COLETA (GOAL)
## ============================================================================

func collect():
	"""Coleta este emitter (para GOALs)"""
	print("[Vela] Collecting: ", name)
	
	if is_instance_valid(Vela_core) and Vela_core.science_mode:
		var dist_traveled = _tracking_distance if _tracking_distance > 0 else 0.0
		var optimal = _optimal_distance if _optimal_distance > 0 else 1.0
		
		Vela_core.log_event_collect(
			name,
			category_type,
			global_position,
			dist_traveled,
			optimal
		)
	
	if is_instance_valid(Vela_core):
		Vela_core.unregister_emitter(self)
	
	# Destruir
	if get_parent() and get_parent() != get_tree().current_scene:
		get_parent().queue_free()
	else:
		queue_free()

func reset_tracking():
	"""Reseta tracking (para múltiplos goals)"""
	call_deferred("_start_tracking")

## ============================================================================
## GEOMETRIA
## ============================================================================

func _find_geometry_nodes():
	_geometry_nodes.clear()
	var root = get_parent()
	if not root:
		return
	
	var target_class = "CollisionShape3D"
	if search_mode == SearchMode.PARENT_MESHES:
		target_class = "MeshInstance3D"
	elif search_mode == SearchMode.PARENT_AREAS:
		target_class = "Area3D"
	
	_scan_recursive(root, target_class)

func _scan_recursive(node: Node, target_class: String):
	if not is_instance_valid(node):
		return
	
	if node is Node3D:
		var s = node.scale
		if is_zero_approx(s.x) or is_zero_approx(s.y) or is_zero_approx(s.z):
			return
	
	if node.is_class(target_class):
		if target_class == "Area3D":
			_scan_recursive(node, "CollisionShape3D")
		else:
			_geometry_nodes.append(node)
	
	if target_class == "CollisionShape3D" and node is CollisionShape3D:
		if not _geometry_nodes.has(node):
			_geometry_nodes.append(node)
	
	for child in node.get_children():
		_scan_recursive(child, target_class)

func _get_aabb_from_node(node: Node3D) -> AABB:
	if node is MeshInstance3D:
		return node.get_aabb()
	
	if node is CollisionShape3D and node.shape:
		var s = node.shape
		if s is BoxShape3D:
			return AABB(-s.size / 2, s.size)
		elif s is SphereShape3D:
			var r = s.radius
			return AABB(Vector3(-r, -r, -r), Vector3(r * 2, r * 2, r * 2))
		elif s is CapsuleShape3D:
			return AABB(Vector3(-s.radius, -s.height / 2, -s.radius), Vector3(s.radius * 2, s.height, s.radius * 2))
		elif s is CylinderShape3D:
			return AABB(Vector3(-s.radius, -s.height / 2, -s.radius), Vector3(s.radius * 2, s.height, s.radius * 2))
		elif s is ConcavePolygonShape3D or s is ConvexPolygonShape3D:
			var debug_mesh = s.get_debug_mesh()
			if debug_mesh:
				return debug_mesh.get_aabb()
			return AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	
	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))

## ============================================================================
## DEBUG
## ============================================================================

func _create_debug_mesh():
	if _debug_mesh_instance:
		return
	var m = ImmediateMesh.new()
	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.mesh = m
	_debug_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	_debug_mesh_instance.material_override = mat
	add_child(_debug_mesh_instance)

func _draw_debug_lines(player_pos: Vector3):
	var m: ImmediateMesh = _debug_mesh_instance.mesh
	m.clear_surfaces()
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for node in _geometry_nodes:
		if not is_instance_valid(node):
			continue
		
		var local_aabb = _get_aabb_from_node(node)
		var trans = node.global_transform
		var center = trans * (local_aabb.position + local_aabb.size / 2)
		var size = local_aabb.size * trans.basis.get_scale()
		var global_aabb = AABB(center - size / 2, size)
		
		var is_platform = player_pos.y >= (global_aabb.end.y - platform_tolerance_y)
		var color = Color.CYAN if is_platform else Color.ORANGE
		
		var data = get_smart_distance(player_pos)
		if data.distance < activation_range:
			color = Color.GREEN
		
		_draw_aabb_box(m, global_aabb, color)
	
	m.surface_end()

func _draw_aabb_box(m: ImmediateMesh, aabb: AABB, c: Color):
	var to_local = _debug_mesh_instance.global_transform.affine_inverse()
	var min_p = aabb.position
	var max_p = aabb.end
	var points = [
		Vector3(min_p.x, min_p.y, min_p.z),
		Vector3(max_p.x, min_p.y, min_p.z),
		Vector3(max_p.x, max_p.y, min_p.z),
		Vector3(min_p.x, max_p.y, min_p.z),
		Vector3(min_p.x, min_p.y, max_p.z),
		Vector3(max_p.x, min_p.y, max_p.z),
		Vector3(max_p.x, max_p.y, max_p.z),
		Vector3(min_p.x, max_p.y, max_p.z)
	]
	var p = []
	for pt in points:
		p.append(to_local * pt)
	var lines = [
		p[0], p[1], p[1], p[2], p[2], p[3], p[3], p[0],
		p[4], p[5], p[5], p[6], p[6], p[7], p[7], p[4],
		p[0], p[4], p[1], p[5], p[2], p[6], p[3], p[7]
	]
	for pt in lines:
		m.surface_set_color(c)
		m.surface_add_vertex(pt)
