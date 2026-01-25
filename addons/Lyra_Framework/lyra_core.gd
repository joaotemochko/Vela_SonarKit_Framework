# res://addons/lyrasound/lyra_core.gd
extends Node
class_name LyraCore

enum InteractionType { GOAL, OBSTACLE, BOUNDARY, HAZARD }

static var instance: Node = null

var _log_data = []
var _session_id = str(Time.get_unix_time_from_system())
var _available_players = []

func _init():
	if instance == null:
		instance = self
	else:
		# Se alguém tentar criar um segundo Core, ele se deleta para não dar conflito
		queue_free()

func _ready():
	_log_data.append("timestamp;event;id;dist;x;y;z")

# --- SISTEMA DE AUDIO POOLING ---

func request_player(emitter: Node3D) -> AudioStreamPlayer3D:
	var p: AudioStreamPlayer3D
	
	if _available_players.is_empty():
		p = AudioStreamPlayer3D.new()
		var root = Engine.get_main_loop().root
		root.add_child.call_deferred(p)
	else:
		p = _available_players.pop_back()
	
	# CONFIGURAÇÃO SEGURA:
	# Verifica se o emissor tem a propriedade 'audio_sample' e 'bus'
	p.stream = emitter.audio_sample
	
	if "bus" in emitter:
		p.bus = emitter.bus
	else:
		p.bus = "Lyra" # Fallback caso a variável não exista
	
	p.volume_db = emitter.audio_db
	p.max_distance = 20.0
	p.unit_size = 10.0 
	return p

func release_player(p: AudioStreamPlayer3D):
	if p:
		p.stop()
		_available_players.append(p)

# --- FUNÇÕES DE APOIO (MATEMÁTICA E LOG) ---

func get_presence_weight(distance: float, max_range: float) -> float:
	return clamp(1.0 - (distance / max_range), 0.0, 1.0)

func get_dynamic_pitch(weight: float, type_index: int) -> float:
	if type_index == InteractionType.GOAL:
		return lerp(1.0, 2.0, weight)
	return lerp(1.0, 0.5, weight)

func log_event(event_type: String, emitter_id: String, distance: float, pos: Vector3):
	var time = Time.get_ticks_msec() / 1000.0
	var line = "%f;%s;%s;%f;%f;%f;%f" % [time, event_type, emitter_id, distance, pos.x, pos.y, pos.z]
	_log_data.append(line)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_all_research_data()

func _save_all_research_data():
	var file = FileAccess.open("user://lyra_log_" + _session_id + ".csv", FileAccess.WRITE)
	if file:
		for line in _log_data:
			file.store_line(line)
		file.close()
		print("LYRA: Dados da pesquisa salvos com sucesso.")
