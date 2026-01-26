extends Node
class_name LyraCore

enum InteractionType { GOAL, OBSTACLE, BOUNDARY, HAZARD }

static var instance: Node = null

var _session_id = str(Time.get_unix_time_from_system()).replace(".", "_")
var _log_data = []
var _available_players = []

var _registered_goals: Array = []
var _registered_boundaries: Array = []

# Timer para gravação automática (5x por segundo)
var _track_timer: float = 0.0

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	await get_tree().process_frame
	_log_level_layout()

# --- AUTOMAÇÃO DE RASTREIO (CAIXA PRETA) ---
func _process(delta):
	# Grava a telemetria automaticamente para o gráfico ficar liso
	_track_timer += delta
	if _track_timer > 0.2: # A cada 0.2 segundos
		_track_timer = 0.0
		_perform_auto_track()

func _perform_auto_track():
	# Encontra o jogador automaticamente
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty(): return
	var pos = players[0].global_position
	
	# Calcula as distâncias reais para os gráficos
	var d_goal = _get_global_dist(pos, _registered_goals)
	var d_bound = _get_global_dist(pos, _registered_boundaries)
	
	# Grava evento silencioso "TRACK"
	_write_line("TRACK", "Player", -1, 0, d_goal, d_bound, pos)

# --- FUNÇÃO DE COLETA (CHAMADA PELO EMITTER) ---
func log_success_hit(id: String, pos: Vector3):
	# Calcula distância real do perigo no momento da vitória
	var d_bound = _get_global_dist(pos, _registered_boundaries)
	
	# FORÇA O ZERO: Grava 0.000m explicitamente para o Goal
	_write_line("ENTER", id, 0, 0.0, 0.0, d_bound, pos)

# --- SISTEMA DE LOG E DISTÂNCIA ---
func _get_global_dist(pos: Vector3, list: Array) -> float:
	var min_dist = -1.0
	for node in list:
		if is_instance_valid(node):
			# Usa a matemática precisa do Emitter
			var d = node.get_true_distance(pos).distance
			if min_dist == -1.0 or d < min_dist: min_dist = d
	return min_dist

func _write_line(evt, id, type, d_local, d_goal, d_bound, pos):
	var time = Time.get_ticks_msec() / 1000.0
	# Formato CSV: timestamp;event;id;type;dist_local;dist_goal;dist_bound;x;y;z
	var line = "%s;%s;%s;%d;%s;%s;%s;%s;%s;%s" % [
		str(time).replace(",", "."), evt, id, type,
		str(d_local).replace(",", "."), str(d_goal).replace(",", "."), str(d_bound).replace(",", "."),
		str(pos.x).replace(",", "."), str(pos.y).replace(",", "."), str(pos.z).replace(",", ".")
	]
	_log_data.append(line)
	if _log_data.size() % 10 == 0: _save_all_research_data()

func _log_level_layout():
	for g in _registered_goals:
		if is_instance_valid(g): _write_line("MAP_GOAL", g.get_parent().name, 0, -1, -1, -1, g.global_position)
	for b in _registered_boundaries:
		if is_instance_valid(b): _write_line("MAP_BOUND", b.get_parent().name, 2, -1, -1, -1, b.global_position)

func _save_all_research_data():
	var path = "user://lyra_log_" + _session_id + ".csv"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_line("timestamp;event;id;type;dist_local;dist_goal;dist_bound;x;y;z") 
		for entry in _log_data: file.store_line(entry)
		file.close()

# --- AUDIO POOLING ---
func register_emitter(emitter):
	if emitter.interaction_type == InteractionType.GOAL:
		if not _registered_goals.has(emitter): _registered_goals.append(emitter)
	elif emitter.interaction_type == InteractionType.BOUNDARY:
		if not _registered_boundaries.has(emitter): _registered_boundaries.append(emitter)

func request_player(emitter: Node3D) -> AudioStreamPlayer3D:
	var p: AudioStreamPlayer3D
	if _available_players.is_empty():
		p = AudioStreamPlayer3D.new()
		var root = Engine.get_main_loop().root
		root.add_child.call_deferred(p)
	else: p = _available_players.pop_back()
	p.stream = emitter.audio_sample
	if "bus" in emitter: p.bus = emitter.bus
	else: p.bus = "Lyra"
	p.volume_db = emitter.audio_db
	p.max_distance = 20.0
	p.unit_size = 10.0 
	return p

func release_player(p: AudioStreamPlayer3D):
	if p: p.stop(); _available_players.append(p)

func get_presence_weight(distance: float, max_range: float) -> float:
	return clamp(1.0 - (distance / max_range), 0.0, 1.0)

func get_dynamic_pitch(weight: float, type_index: int) -> float:
	match type_index:
		InteractionType.GOAL: return lerp(1.0, 2.0, weight)
		InteractionType.BOUNDARY: 
			var vib = sin(Time.get_ticks_msec() * 0.03) * 0.2
			return lerp(1.0, 1.3, weight) + (vib * weight)
	return 1.0

func log_event(event_type: String, emitter_id: String, type_idx: int, local_dist: float, pos: Vector3):
	var d_goal = _get_global_dist(pos, _registered_goals)
	var d_bound = _get_global_dist(pos, _registered_boundaries)
	_write_line(event_type, emitter_id, type_idx, local_dist, d_goal, d_bound, pos)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _save_all_research_data()
