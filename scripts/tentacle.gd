extends Node2D

signal on_tentacle_destroyed

var cell_scene = preload("res://scenes/enemy_cell.tscn")

# CONFIGURAÇÕES ESTRUTURAIS
@export var length: int = 20
@export var cell_gap: float = 20.0 

# CONFIGURAÇÃO DE FORMA (SHAPE)
@export var thickness_curve: Curve 
@export var cell_spacing_width: float = 22.0 

# CONFIGURAÇÕES DE COMBATE (NOVO)
@export var cell_damage: int = 10
@export var cell_health: int = 10

# CONFIGURAÇÕES VISUAIS
@export var saw_rotation_speed: float = 3.0 
@export var idle_wave_strength: float = 2.0 
@export var idle_wave_speed: float = 2.0    
@export var body_alignment_speed: float = 1.0 

# SUAVIZAÇÃO
@export var path_smoothing: float = 15.0 

# VARIÁVEIS INTERNAS
var segments: Array[Node2D] = [] 
var point_history: Array[Vector2] = [] 
var total_living_cells: int = 0
var is_active: bool = true 
var time_alive: float = 0.0

var head_angle: float = 0.0 

func _ready():
	# Inicializa histórico
	var initial_back_dir = Vector2.LEFT.rotated(rotation)
	for i in range(length * 5):
		var hist_pos = global_position + (initial_back_dir * (i * cell_gap))
		point_history.append(hist_pos)
	
	for i in range(length):
		var segment_root = Node2D.new()
		segment_root.name = "Segment_%d" % i
		add_child(segment_root)
		segments.append(segment_root)
		
		segment_root.top_level = true 
		
		var progress = float(i) / float(length - 1)
		var thickness_value = 1.0
		if thickness_curve:
			thickness_value = thickness_curve.sample(progress)
		
		var cell_count = max(1, round(thickness_value))
		_spawn_cluster(segment_root, cell_count, i)
		
		var target_distance = i * cell_gap
		segment_root.global_position = solve_position_at_distance(target_distance)
	
	# Começa seguro (Dano desligado)
	set_damage_active(false)

func _spawn_cluster(parent_bone: Node2D, count: int, segment_index: int):
	var start_x = -(count - 1) * (cell_spacing_width / 2.0)
	
	for k in range(count):
		var new_cell = cell_scene.instantiate()
		
		# Configura atributos de combate
		if "damage" in new_cell:
			new_cell.damage = cell_damage
		if "health" in new_cell:
			new_cell.health = cell_health
			
		parent_bone.add_child(new_cell)
		
		var offset_y = start_x + (k * cell_spacing_width)
		new_cell.position = Vector2(0, offset_y)
		new_cell.z_index = length - segment_index
		new_cell.on_death.connect(_on_cell_death)
		total_living_cells += 1

func _process(delta):
	if not is_active: return
	time_alive += delta

	# --- 1. RELAXAMENTO ANGULAR ---
	var head_pos = global_position
	var ideal_angle = head_angle + PI 
	
	for k in range(1, point_history.size()):
		var point = point_history[k]
		var vec_to_point = point - head_pos
		var dist = vec_to_point.length()
		var current_angle = vec_to_point.angle()
		
		if dist < 1.0: continue
		
		var lag = 1.0 / (1.0 + (dist * 0.02)) 
		var rotate_speed = body_alignment_speed * lag * delta
		
		var new_angle = lerp_angle(current_angle, ideal_angle, rotate_speed)
		
		var wave = sin((time_alive * idle_wave_speed) - (dist * 0.05)) * (idle_wave_strength * 0.01)
		wave *= clamp(dist / 100.0, 0.0, 2.0)
		
		var final_angle = new_angle + wave
		var new_pos = head_pos + Vector2(cos(final_angle), sin(final_angle)) * dist
		
		point_history[k] = new_pos

	_smooth_history()

	# --- 2. GRAVAR RASTRO ---
	var dist_moved = global_position.distance_to(point_history[0])
	if dist_moved > 5.0: 
		point_history.push_front(global_position)
	else:
		point_history[0] = global_position

	_maintain_history_integrity()

	# --- 3. ATUALIZAR SEGMENTOS ---
	
	if is_instance_valid(segments[0]):
		segments[0].global_position = global_position
		segments[0].rotation = head_angle + (time_alive * saw_rotation_speed)

	for i in range(1, length):
		var bone = segments[i]
		if not is_instance_valid(bone): continue
		
		var target_distance = i * cell_gap
		var ideal_pos = solve_position_at_distance(target_distance)
		
		bone.global_position = bone.global_position.lerp(ideal_pos, path_smoothing * delta)
		
		var dist_to_prev = bone.global_position.distance_to(segments[i-1].global_position)
		if dist_to_prev < cell_gap * 0.6: 
			var push_dir = (bone.global_position - segments[i-1].global_position).normalized()
			if push_dir == Vector2.ZERO: push_dir = Vector2.RIGHT.rotated(head_angle + PI)
			bone.global_position = segments[i-1].global_position + (push_dir * cell_gap * 0.7)

		var look_target = segments[i-1].global_position
		var path_rotation = (look_target - bone.global_position).angle()
		bone.rotation = path_rotation + head_angle + (time_alive * saw_rotation_speed)

# --- CONTROLE DE DANO ---
func set_damage_active(enabled: bool):
	for segment in segments:
		if not is_instance_valid(segment): continue
		for child in segment.get_children():
			if child.has_method("set_deferred"): 
				if "monitoring" in child:
					child.set_deferred("monitoring", enabled)
				
				if enabled:
					child.modulate = Color(2, 0.5, 0.5) 
				else:
					if child.get("is_dead"):
						child.modulate = Color(0.3, 0.3, 0.3, 0.5)
					else:
						child.modulate = Color(1, 1, 1)

# --- FUNÇÕES AUXILIARES ---

func _smooth_history():
	for k in range(1, point_history.size() - 1):
		var prev = point_history[k-1]
		var curr = point_history[k]
		var next = point_history[k+1]
		point_history[k] = (prev + curr + next) / 3.0

func _maintain_history_integrity():
	var max_points = length * 10
	if point_history.size() > max_points:
		point_history.resize(max_points)
	
	var total_len = 0.0
	for k in range(point_history.size() - 1):
		total_len += point_history[k].distance_to(point_history[k+1])
	
	var required_len = length * cell_gap
	
	if total_len < required_len:
		var last_point = point_history.back()
		var tail_dir = Vector2.ZERO
		if point_history.size() > 1:
			tail_dir = (last_point - point_history[point_history.size()-2]).normalized()
		if tail_dir == Vector2.ZERO:
			tail_dir = Vector2.RIGHT.rotated(head_angle + PI)
		
		var missing = required_len - total_len
		var extension = last_point + (tail_dir * (missing + 100.0)) 
		point_history.append(extension)

func solve_position_at_distance(target_dist: float) -> Vector2:
	var traveled = 0.0
	for k in range(point_history.size() - 1):
		var p1 = point_history[k]
		var p2 = point_history[k+1]
		var segment_len = p1.distance_to(p2)
		
		if traveled + segment_len >= target_dist:
			var remaining = target_dist - traveled
			var t = remaining / segment_len
			return p1.lerp(p2, t)
		
		traveled += segment_len
	
	return point_history.back()

func look_at_position(target_pos: Vector2):
	head_angle = (target_pos - global_position).angle()

func _on_cell_death():
	total_living_cells -= 1
	if total_living_cells <= 0:
		die()

func die():
	is_active = false
	on_tentacle_destroyed.emit()
	modulate = Color(0.3, 0.3, 0.3, 0.5)
