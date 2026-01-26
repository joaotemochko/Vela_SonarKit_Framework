extends Node
class_name LyraCore

enum InteractionType { GOAL, OBSTACLE, BOUNDARY, HAZARD }

static var instance: Node = null

var _session_id = str(Time.get_unix_time_from_system()).replace(".", "_")
var _log_data = []
var _available_players = []

func _init():
	# Instantiate the class
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	pass

# ---  AUDIO POOLING SYSTEM ---

func request_player(emitter: Node3D) -> AudioStreamPlayer3D:
	var p: AudioStreamPlayer3D
	
	if _available_players.is_empty():
		p = AudioStreamPlayer3D.new()
		var root = Engine.get_main_loop().root
		root.add_child.call_deferred(p)
	else:
		p = _available_players.pop_back()
	
	# SAFE CONFIGURATION:
	# Check if the transmitter has the 'audio_sample' and 'bus' properties.
	p.stream = emitter.audio_sample
	
	if "bus" in emitter:
		p.bus = emitter.bus
	else:
		p.bus = "Lyra"
	
	p.volume_db = emitter.audio_db
	p.max_distance = 20.0
	p.unit_size = 10.0 
	return p

func release_player(p: AudioStreamPlayer3D):
	if p:
		p.stop()
		_available_players.append(p)

# --- SUPPORT FUNCTIONS (MATHEMATICS AND LOGIC) ---

func get_presence_weight(distance: float, max_range: float) -> float:
	return clamp(1.0 - (distance / max_range), 0.0, 1.0)

func get_dynamic_pitch(weight: float, type_index: int) -> float:
	if type_index == InteractionType.GOAL:
		return lerp(1.0, 2.0, weight)
	return lerp(1.0, 0.5, weight)

func log_event(event_type: String, emitter_id: String, type_idx: int, distance: float, pos: Vector3):
	var time = Time.get_ticks_msec() / 1000.0
	
	var line = "%s;%s;%s;%d;%s;%s;%s;%s" % [
		str(time).replace(",", "."),
		event_type,
		emitter_id,
		type_idx,
		str(distance).replace(",", "."),
		str(pos.x).replace(",", "."),
		str(pos.y).replace(",", "."),
		str(pos.z).replace(",", ".")
	]
	_log_data.append(line)
	
	# Saves every 5 events to avoid data loss if the game crashes.
	if _log_data.size() % 5 == 0:
		_save_all_research_data()

func _save_all_research_data():
	var path = "user://lyra_log_" + _session_id + ".csv"
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_line("timestamp;event;id;type;dist;x;y;z") # Header
		for entry in _log_data:
			file.store_line(entry)
		file.close()

# Notify if save the log
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_all_research_data()
