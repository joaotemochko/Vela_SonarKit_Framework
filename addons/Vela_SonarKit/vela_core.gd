extends Node
class_name VelaCore

static var instance: VelaCore

enum CategoryType { BOUNDARY, OBSTACLE, GOAL, INTERACTABLE, HAZARD }

## ============================================================================
## CONFIGURAÇÃO
## ============================================================================

## Modo científico - gera CSV com dados para pesquisa
@export var science_mode: bool = true
## Intervalo de log em segundos (0.1 = 10Hz recomendado para pesquisa)
@export var log_interval: float = 0.1

## Radar SEMPRE ATIVO - essencial para navegação de pessoas cegas
@export var radar_enabled: bool = true
## Som do radar (ping/bip)
@export var scanner_ping_sound: AudioStream = load("res://addons/Vela_SonarKit/coin.ogg")
## Volume base do radar em dB
@export_range(-20.0, 10.0, 0.5) var scanner_volume_db: float = 0.0
## Distância máxima de detecção do radar
@export var scanner_max_dist: float = 50.0
## Intervalo mínimo entre bips (conforto auditivo)
@export var radar_min_interval: float = 0.15
## Intervalo máximo entre bips (quando longe)
@export var radar_max_interval: float = 1.2

## Inverter orientação (alguns jogos usam eixos diferentes)
@export var reverse_orientation: bool = false
## Debug visual da orientação
@export var debug_orientation: bool = false

## ============================================================================
## VARIÁVEIS INTERNAS
## ============================================================================

var _emitters: Array = []
var _file: FileAccess
var _timer_log: float = 0.0
var _radar_timer: float = 0.0
var _radar_players: Array[AudioStreamPlayer3D] = []
var _debug_mesh: MeshInstance3D = null
var _last_player_pos: Vector3 = Vector3.ZERO
var _last_timestamp: float = 0.0

## Tracking de interações (para ENTER/EXIT)
var _active_interactions: Dictionary = {}

## ============================================================================
## MÉTRICAS CIENTÍFICAS
## ============================================================================

var _session_id: String = ""
var _session_start_time: float = 0.0
var _total_distance_traveled: float = 0.0
var _goals_collected: int = 0
var _total_collisions: int = 0
var _heading_changes: int = 0
var _last_heading: Vector3 = Vector3.ZERO
var _time_in_danger_zone: float = 0.0

## ============================================================================
## INICIALIZAÇÃO
## ============================================================================

func _init(): 
	if instance == null: 
		instance = self

func _ready():
	if instance == null: 
		instance = self
	
	# Tentar carregar som padrão se não definido
	if scanner_ping_sound == null:
		var possible_paths = [
			"res://addons/Vela_Framework/coin.ogg",
			"res://addons/Vela/coin.ogg",
			"res://coin.ogg"
		]
		for path in possible_paths:
			if ResourceLoader.exists(path):
				scanner_ping_sound = load(path)
				break
	
	_setup_radar_audio()
	_session_id = _generate_session_id()
	_session_start_time = Time.get_unix_time_from_system()
	
	if science_mode:
		_setup_csv()
		print("[Vela] Science Mode: ON | Session: ", _session_id)
	else:
		print("[Vela] Science Mode: OFF")
	
	if debug_orientation: 
		_create_debug_arrow()
	
	_last_timestamp = Time.get_unix_time_from_system()
	
	# Radar sempre começa ativo
	print("[Vela] Radar: ALWAYS ON (accessibility mode)")

func _generate_session_id() -> String:
	var time = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d_%04d" % [
		time.year, time.month, time.day,
		time.hour, time.minute, time.second,
		randi() % 10000
	]

## ============================================================================
## LOOP PRINCIPAL
## ============================================================================

func _process(delta):
	# Radar SEMPRE ATIVO - não tem toggle, é essencial para acessibilidade
	if radar_enabled:
		_process_radar(delta)
	
	# Debug visual
	if debug_orientation and _debug_mesh:
		_update_debug_arrow()
	
	# Log científico
	if science_mode and _file:
		_timer_log += delta
		if _timer_log >= log_interval:
			_timer_log = 0.0
			_log_track_and_detect_interactions(delta)

## ============================================================================
## RADAR - SEMPRE BUSCA O GOAL MAIS PRÓXIMO
## ============================================================================

func _process_radar(delta):
	if not scanner_ping_sound: 
		return
	
	var p_pos = _get_player_pos()
	if p_pos == Vector3.ZERO: 
		return
	
	# SEMPRE busca o GOAL mais próximo
	var closest_goal = _find_closest_goal(p_pos)
	
	if closest_goal == null:
		# Sem goals, radar silencioso mas pronto
		return
	
	var dist_data = closest_goal.get_smart_distance(p_pos)
	var dist = dist_data.distance
	var goal_pos = dist_data.position
	
	# Clampar distância
	var safe_dist = clamp(dist, 0.1, scanner_max_dist)
	
	# Calcular intervalo baseado na distância
	# Perto = rápido, Longe = lento (confortável para o usuário)
	var t = safe_dist / scanner_max_dist  # 0 = perto, 1 = longe
	var interval = lerp(radar_min_interval, radar_max_interval, t)
	
	# Calcular pitch baseado no alinhamento
	var alignment = _get_alignment_to_target(goal_pos)
	var pitch = _calculate_pitch_from_alignment(alignment)
	
	# Atualizar timer e tocar
	_radar_timer -= delta
	if _radar_timer <= 0.0:
		_play_radar_ping(goal_pos, pitch, dist)
		_radar_timer = interval

func _find_closest_goal(player_pos: Vector3):
	"""Encontra o GOAL mais próximo do player"""
	var closest = null
	var min_dist = INF
	
	for e in _emitters:
		if not is_instance_valid(e):
			continue
		if e.category_type != CategoryType.GOAL:
			continue
		
		var dist_data = e.get_smart_distance(player_pos)
		if dist_data.distance < min_dist:
			min_dist = dist_data.distance
			closest = e
	
	return closest

func _get_alignment_to_target(target_pos: Vector3) -> float:
	"""
	Retorna o alinhamento entre a direção do player e o target
	-1 = olhando para trás, 0 = lateral, 1 = olhando direto
	"""
	if not is_inside_tree():
		return 0.0
	
	var tree = get_tree()
	if tree == null:
		return 0.0
	
	var nodes = tree.get_nodes_in_group("Player")
	if nodes.is_empty():
		return 0.0
	
	var player = nodes[0]
	var p_pos = player.global_position
	
	# Direção ao alvo (ignorar Y)
	var to_target = target_pos - p_pos
	to_target.y = 0
	if to_target.length() < 0.01:
		return 1.0  # Já está no alvo
	to_target = to_target.normalized()
	
	# Direção do player
	var forward = _get_player_forward(player)
	
	if reverse_orientation:
		forward = -forward
	
	# Dot product = alinhamento
	return forward.dot(to_target)

func _get_player_forward(player) -> Vector3:
	"""Obtém a direção frontal do player de forma robusta"""
	var forward = Vector3.FORWARD
	
	# Prioridade 1: Câmera (mais confiável em primeira pessoa)
	var viewport = get_viewport()
	if viewport:
		var camera = viewport.get_camera_3d()
		if camera:
			forward = -camera.global_transform.basis.z
			forward.y = 0
			if forward.length() > 0.01:
				return forward.normalized()
	
	# Prioridade 2: Velocidade do player
	if "velocity" in player:
		var vel = player.velocity
		vel.y = 0
		if vel.length() > 0.3:
			return vel.normalized()
	
	# Prioridade 3: Transform do player
	forward = -player.global_transform.basis.z
	forward.y = 0
	if forward.length() > 0.01:
		return forward.normalized()
	
	return Vector3.FORWARD

func _calculate_pitch_from_alignment(alignment: float) -> float:
	"""
	Calcula o pitch baseado no alinhamento
	Alinhado = pitch alto (som agudo = "certo")
	Desalinhado = pitch baixo (som grave = "errado")
	"""
	if alignment > 0.8:
		# Muito alinhado: pitch alto
		return remap(alignment, 0.8, 1.0, 2.0, 2.8)
	elif alignment > 0.4:
		# Parcialmente alinhado
		return remap(alignment, 0.4, 0.8, 1.4, 2.0)
	elif alignment > 0.0:
		# Lateral
		return remap(alignment, 0.0, 0.4, 1.0, 1.4)
	elif alignment > -0.5:
		# Parcialmente atrás
		return remap(alignment, -0.5, 0.0, 0.7, 1.0)
	else:
		# Atrás
		return remap(alignment, -1.0, -0.5, 0.5, 0.7)

## ============================================================================
## SISTEMA DE ÁUDIO
## ============================================================================

func _setup_radar_audio():
	"""Cria pool de AudioStreamPlayer3D para o radar"""
	_radar_players.clear()
	for i in range(4):
		var p = AudioStreamPlayer3D.new()
		p.name = "RadarPing_" + str(i)
		p.bus = "Master"
		p.unit_size = 10.0
		p.max_distance = 1000.0
		p.panning_strength = 1.5
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		add_child(p)
		_radar_players.append(p)

func _play_radar_ping(pos: Vector3, pitch: float, distance: float):
	"""Toca o ping do radar na posição do goal"""
	var player = null
	
	# Encontrar player livre
	for p in _radar_players:
		if not p.playing:
			player = p
			break
	
	if not player:
		player = _radar_players[0]
	
	player.global_position = pos
	player.stream = scanner_ping_sound
	player.pitch_scale = clamp(pitch, 0.4, 3.0)
	
	# Volume baseado na distância (mais perto = mais alto)
	var vol = remap(distance, 0.0, scanner_max_dist, 3.0, -6.0)
	player.volume_db = clamp(vol + scanner_volume_db, -20.0, 6.0)
	
	player.play()

## ============================================================================
## REGISTRO DE EMITTERS
## ============================================================================

func register_emitter(e):
	if not _emitters.has(e):
		_emitters.append(e)
		print("[Vela] Registered: ", e.name, " (", CategoryType.keys()[e.category_type], ")")

func unregister_emitter(e):
	if _emitters.has(e):
		_emitters.erase(e)

## ============================================================================
## SISTEMA DE LOG CIENTÍFICO COMPLETO
## ============================================================================

func _setup_csv():
	"""Cria arquivo CSV com cabeçalho científico completo"""
	var fname = "user://Vela_SESSION_" + _session_id + ".csv"
	var real_path = ProjectSettings.globalize_path(fname)
	
	print("[Vela] CSV: ", real_path)
	
	_file = FileAccess.open(fname, FileAccess.WRITE)
	if _file:
		# Cabeçalho científico completo (22 colunas)
		var header = "session_id;timestamp;elapsed_time;event;id;category;"
		header += "dist_local;dist_goal;dist_boundary;dist_obstacle;dist_hazard;"
		header += "x;y;z;velocity;heading_x;heading_z;"
		header += "radar_active;total_distance;goals_collected;collisions;heading_changes"
		_file.store_line(header)
		_file.flush()

func _log_track_and_detect_interactions(delta: float):
	"""Log TRACK com todas as métricas científicas"""
	var p_pos = _get_player_pos()
	if p_pos == Vector3.ZERO:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - _session_start_time
	var dt = current_time - _last_timestamp
	
	# Calcular velocidade
	var velocity = 0.0
	var distance_moved = 0.0
	if dt > 0.001:
		distance_moved = p_pos.distance_to(_last_player_pos)
		velocity = distance_moved / dt
		_total_distance_traveled += distance_moved
	
	# Obter distâncias por categoria
	var dists = _get_distances_by_category(p_pos)
	
	# Atualizar tempo em zona de perigo
	if dists.hazard > 0 and dists.hazard < 3.0:
		_time_in_danger_zone += delta
	if dists.boundary > 0 and dists.boundary < 2.0:
		_time_in_danger_zone += delta
	
	# Heading atual
	var heading = _last_heading if _last_heading != Vector3.ZERO else Vector3.FORWARD
	
	# Detectar mudança de heading
	var current_forward = _get_player_forward_safe()
	if current_forward != Vector3.ZERO and _last_heading != Vector3.ZERO:
		if _last_heading.dot(current_forward) < 0.7:
			_heading_changes += 1
	_last_heading = current_forward
	
	_last_player_pos = p_pos
	_last_timestamp = current_time
	
	# Construir linha CSV
	var line = "%s;%.3f;%.2f;TRACK;Player;-1;" % [_session_id, current_time, elapsed]
	line += "%.2f;%.2f;%.2f;%.2f;%.2f;" % [dists.goal, dists.goal, dists.boundary, dists.obstacle, dists.hazard]
	line += "%.2f;%.2f;%.2f;%.2f;%.3f;%.3f;" % [p_pos.x, p_pos.y, p_pos.z, velocity, heading.x, heading.z]
	line += "1;%.2f;%d;%d;%d" % [_total_distance_traveled, _goals_collected, _total_collisions, _heading_changes]
	
	_file.store_line(line)
	
	# Detectar ENTER/EXIT
	_detect_enter_exit(p_pos, current_time, elapsed, velocity, heading)
	
	_file.flush()

func _detect_enter_exit(p_pos: Vector3, timestamp: float, elapsed: float, velocity: float, heading: Vector3):
	"""Detecta eventos ENTER/EXIT nas zonas de ativação"""
	var threshold = 0.5
	
	for emitter in _emitters:
		if not is_instance_valid(emitter):
			continue
		
		var dist_data = emitter.get_smart_distance(p_pos)
		var distance = dist_data.distance
		var emitter_id = emitter.name
		var activation_range = emitter.activation_range if "activation_range" in emitter else 4.0
		var category = emitter.category_type
		
		var is_close = distance < (activation_range + threshold)
		var was_active = _active_interactions.has(emitter_id)
		
		if is_close and not was_active:
			# ENTER
			_active_interactions[emitter_id] = {"entered_at": timestamp, "distance": distance}
			
			if category == CategoryType.HAZARD or category == CategoryType.OBSTACLE:
				_total_collisions += 1
			
			_log_event("ENTER", emitter_id, category, distance, p_pos, velocity, heading, timestamp, elapsed)
		
		elif not is_close and was_active:
			# EXIT
			_active_interactions.erase(emitter_id)
			_log_event("EXIT", emitter_id, category, distance, p_pos, velocity, heading, timestamp, elapsed)

func _log_event(event: String, id: String, category: int, dist_local: float, pos: Vector3, vel: float, heading: Vector3, timestamp: float, elapsed: float):
	"""Log de evento (ENTER, EXIT, COLLECT)"""
	var dists = _get_distances_by_category(pos)
	
	var line = "%s;%.3f;%.2f;%s;%s;%d;" % [_session_id, timestamp, elapsed, event, id, category]
	line += "%.2f;%.2f;%.2f;%.2f;%.2f;" % [dist_local, dists.goal, dists.boundary, dists.obstacle, dists.hazard]
	line += "%.2f;%.2f;%.2f;%.2f;%.3f;%.3f;" % [pos.x, pos.y, pos.z, vel, heading.x, heading.z]
	line += "1;%.2f;%d;%d;%d" % [_total_distance_traveled, _goals_collected, _total_collisions, _heading_changes]
	
	_file.store_line(line)
	print("[Vela] ", event, ": ", id)

func log_event_collect(id: String, category: int, emitter_pos: Vector3, dist_traveled: float, optimal_dist: float):
	"""Log evento COLLECT (chamado pelo emitter)"""
	if not science_mode or not _file:
		return
	
	var p_pos = _get_player_pos()
	var vel = _get_player_velocity()
	var heading = _last_heading if _last_heading != Vector3.ZERO else Vector3.FORWARD
	var dists = _get_distances_by_category(p_pos)
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - _session_start_time
	
	_goals_collected += 1
	
	var line = "%s;%.3f;%.2f;COLLECT;%s;%d;" % [_session_id, current_time, elapsed, id, category]
	line += "0.00;%.2f;%.2f;%.2f;%.2f;" % [dists.goal, dists.boundary, dists.obstacle, dists.hazard]
	line += "%.2f;%.2f;%.2f;%.2f;%.3f;%.3f;" % [p_pos.x, p_pos.y, p_pos.z, vel, heading.x, heading.z]
	line += "1;%.2f;%d;%d;%d" % [_total_distance_traveled, _goals_collected, _total_collisions, _heading_changes]
	
	_file.store_line(line)
	_file.flush()
	
	print("[Vela] COLLECT: ", id, " | Goals: ", _goals_collected)

func _get_distances_by_category(pos: Vector3) -> Dictionary:
	"""Calcula distância mínima a cada categoria"""
	var result = {"goal": -1.0, "boundary": -1.0, "obstacle": -1.0, "hazard": -1.0}
	var mins = {"goal": INF, "boundary": INF, "obstacle": INF, "hazard": INF}
	
	for e in _emitters:
		if not is_instance_valid(e):
			continue
		
		var dist_data = e.get_smart_distance(pos)
		var d = dist_data.distance
		
		match e.category_type:
			CategoryType.GOAL:
				if d < mins.goal: mins.goal = d
			CategoryType.BOUNDARY:
				if d < mins.boundary: mins.boundary = d
			CategoryType.OBSTACLE:
				if d < mins.obstacle: mins.obstacle = d
			CategoryType.HAZARD:
				if d < mins.hazard: mins.hazard = d
	
	if mins.goal < INF: result.goal = mins.goal
	if mins.boundary < INF: result.boundary = mins.boundary
	if mins.obstacle < INF: result.obstacle = mins.obstacle
	if mins.hazard < INF: result.hazard = mins.hazard
	
	return result

## ============================================================================
## UTILIDADES
## ============================================================================

func _get_player_pos() -> Vector3:
	if not is_inside_tree():
		return Vector3.ZERO
	var tree = get_tree()
	if tree == null:
		return Vector3.ZERO
	var nodes = tree.get_nodes_in_group("Player")
	if nodes.is_empty():
		return Vector3.ZERO
	return nodes[0].global_position

func _get_player_velocity() -> float:
	if not is_inside_tree():
		return 0.0
	var tree = get_tree()
	if tree == null:
		return 0.0
	var nodes = tree.get_nodes_in_group("Player")
	if nodes.is_empty():
		return 0.0
	if "velocity" in nodes[0]:
		return nodes[0].velocity.length()
	return 0.0

func _get_player_forward_safe() -> Vector3:
	if not is_inside_tree():
		return Vector3.ZERO
	var tree = get_tree()
	if tree == null:
		return Vector3.ZERO
	var nodes = tree.get_nodes_in_group("Player")
	if nodes.is_empty():
		return Vector3.ZERO
	return _get_player_forward(nodes[0])

func get_session_summary() -> Dictionary:
	"""Retorna resumo da sessão"""
	var elapsed = Time.get_unix_time_from_system() - _session_start_time
	return {
		"session_id": _session_id,
		"duration": elapsed,
		"total_distance": _total_distance_traveled,
		"goals_collected": _goals_collected,
		"collisions": _total_collisions,
		"heading_changes": _heading_changes,
		"time_in_danger": _time_in_danger_zone,
		"avg_speed": _total_distance_traveled / max(elapsed, 0.1)
	}

## ============================================================================
## DEBUG
## ============================================================================

func _create_debug_arrow():
	if _debug_mesh:
		return
	var m = ImmediateMesh.new()
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.mesh = m
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.MAGENTA
	_debug_mesh.material_override = mat
	_debug_mesh.top_level = true
	add_child(_debug_mesh)

func _update_debug_arrow():
	var p = _get_player_pos()
	if p == Vector3.ZERO:
		return
	
	var forward = _get_player_forward_safe()
	if forward == Vector3.ZERO:
		forward = Vector3.FORWARD
	forward = forward * 2.0
	
	var m: ImmediateMesh = _debug_mesh.mesh
	m.clear_surfaces()
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	m.surface_add_vertex(p + Vector3(0, 2, 0))
	m.surface_add_vertex(p + Vector3(0, 2, 0) + forward)
	m.surface_end()

## ============================================================================
## CLEANUP
## ============================================================================

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_close_csv()

func _exit_tree():
	_close_csv()

func _close_csv():
	if _file:
		_file.flush()
		_file.close()
		_file = null
		print("[Vela] CSV saved")
		print("[Vela] Summary: ", get_session_summary())
