extends Node3D
class_name LyraEmitter

var lyra_Core

# --- CONFIGURAÇÃO PADRÃO DE HZ E VOLUME ---
# Ajuste estes valores no Inspector para cada tipo de objeto (Limit, Goal, Enemy, etc.)
@export_group("Audio Behavior Settings")
@export var min_hz: float = 200.0      # Hz quando está "longe" (inicio da detecção)
@export var max_hz: float = 600.0      # Hz quando está "muito perto" (intensidade máxima)
@export var min_db: float = -20.0      # Volume inicial (sussurro)
@export var max_db: float = 0.0        # Volume máximo (perto)

@export_group("Trigger Settings")
@export var interaction_type: LyraCore.InteractionType = LyraCore.InteractionType.OBSTACLE 
@export var max_range: float = 10.0            # Alcance padrão para Goal/Outros
@export var limit_trigger_dist: float = 1.5    # Alcance específico curto para LIMIT (Bordas)

@export_group("System")
@export var audio_sample: AudioStream = load("res://addons/Lyra_Framework/wall_hum.ogg") 
@export var bus: String = "Master"

var _is_inside: bool = false
var _collision_shapes: Array = []
var _active_player: AudioStreamPlayer3D = null

func _ready():
	if LyraCore.instance == null:
		var new_core = load("res://addons/Lyra_Framework/lyra_core.gd").new()
		get_tree().root.add_child.call_deferred(new_core)
		lyra_Core = new_core
	else:
		lyra_Core = LyraCore.instance
	
	lyra_Core.register_emitter(self)
	_find_all_collision_shapes()

func _process(_delta):
	if not is_inside_tree() or is_queued_for_deletion(): return
	if not is_instance_valid(lyra_Core): return 
	
	var target_pos = _get_listener_pos()
	if target_pos == Vector3.ZERO: return

	var data = get_true_distance(target_pos)
	var dist = data.distance
	
	# --- PASSO 1: CALCULAR INTENSIDADE (0.0 a 1.0) ---
	# Aqui definimos QUANDO o som deve tocar.
	# intensity 0.0 = Fora de alcance ou muito longe
	# intensity 1.0 = Colado no objeto / no centro do alvo
	
	var intensity = 0.0
	var is_active_range = false
	
	if interaction_type == LyraCore.InteractionType.OBSTACLE:
		# Lógica LIMIT: Só ativa na "casca" da borda
		if dist < limit_trigger_dist:
			is_active_range = true
			# Quanto menor a distância, maior a intensidade
			intensity = 1.0 - (dist / limit_trigger_dist)
	else:
		# Lógica GOAL / OUTROS: Ativa no raio completo
		if dist < max_range:
			is_active_range = true
			# Gradiente suave ao longo de todo o raio
			intensity = 1.0 - (dist / max_range)
	
	intensity = clamp(intensity, 0.0, 1.0)

	# --- PASSO 2: GERENCIAR O PLAYER DE ÁUDIO ---
	
	if is_active_range:
		if not _is_inside:
			_enter_emitter(dist, target_pos)
		
		if is_instance_valid(_active_player):
			_active_player.global_position = data.position
			_update_audio_signal(intensity) # Passamos a intensidade limpa
			
	elif _is_inside:
		_exit_emitter(dist, target_pos)

# --- O CORAÇÃO DA CORREÇÃO: CÁLCULO DE ÁUDIO BASEADO EM INTENSIDADE ---
func _update_audio_signal(intensity: float):
	if not is_instance_valid(_active_player): return
	
	# Interpolação Linear (Lerp) limpa para os Hz
	# Se intensidade 0 (longe) -> usa min_hz
	# Se intensidade 1 (perto) -> usa max_hz
	var current_hz = lerp(min_hz, max_hz, intensity)
	
	# Converte Hz para Pitch Scale (assumindo base 440hz ou 1.0)
	# Se seu áudio original for neutro (1.0), isso modula corretamente.
	var base_sample_hz = 440.0 
	_active_player.pitch_scale = current_hz / base_sample_hz
	
	# Volume também segue a intensidade (opcional, mas recomendado)
	var target_vol_db = lerp(min_db, max_db, intensity)
	
	# Aplica o Master Volume do Core se existir
	var core_vol_mult = 1.0
	if "master_volume" in lyra_Core: core_vol_mult = lyra_Core.master_volume
	
	# Conversão final para DB real
	# Nota: linear_to_db(core_vol_mult) é somado ao DB calculado
	_active_player.volume_db = target_vol_db + linear_to_db(core_vol_mult)

func _enter_emitter(dist, pos):
	_active_player = lyra_Core.request_player(self)
	_is_inside = true
	
	if is_instance_valid(_active_player):
		_active_player.stream = audio_sample
		_active_player.bus = bus
		if not _active_player.playing:
			_active_player.play()
	
	lyra_Core.log_event("ENTER", get_parent().name, interaction_type, dist, pos)

func _exit_emitter(dist, pos):
	_is_inside = false
	if is_instance_valid(lyra_Core):
		lyra_Core.release_player(_active_player)
		lyra_Core.log_event("EXIT", get_parent().name, interaction_type, dist, pos)
	_active_player = null

# --- MÉTODOS AUXILIARES ---
func _find_all_collision_shapes():
	_find_shapes_recursive(self)

func _find_shapes_recursive(node: Node):
	for child in node.get_children():
		if child is CollisionShape3D:
			_collision_shapes.append(child)
		_find_shapes_recursive(child)

func get_true_distance(target_pos: Vector3) -> Dictionary:
	var min_dist = 99999.0
	var final_pos = self.global_position
	
	if _collision_shapes.is_empty():
		return {"distance": self.global_position.distance_to(target_pos), "position": self.global_position}

	for shape in _collision_shapes:
		if not is_instance_valid(shape): continue
		var d = shape.global_position.distance_to(target_pos)
		if d < min_dist:
			min_dist = d
			final_pos = shape.global_position
			
	return {"distance": min_dist, "position": final_pos}

func _get_listener_pos() -> Vector3:
	var players = get_tree().get_nodes_in_group("Player")
	if not players.is_empty(): return players[0].global_position
	var cam = get_viewport().get_camera_3d()
	if cam: return cam.global_position
	return Vector3.ZERO

func collect():
	if is_instance_valid(lyra_Core):
		lyra_Core.log_success_hit(get_parent().name, _get_listener_pos())
	queue_free()
