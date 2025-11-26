extends Node2D

var cell_scene = preload("res://scenes/enemy_cell.tscn")

# --- CONFIGURAÇÕES DE COMPORTAMENTO ---
@export var speed: float = 200.0      
@export var turn_speed: float = 4.0   
@export var length: int = 6           
@export var cell_gap: float = 18.0    

# --- CONFIGURAÇÕES DE COMBATE ---
@export var cell_damage: int = 10     
@export var cell_health: int = 5      

# --- CONFIGURAÇÕES FÍSICAS ---
@export var body_alignment_speed: float = 5.0 
@export var path_smoothing: float = 10.0 

var cells: Array = []
var point_history: Array[Vector2] = [] 
var living_cells_count: int = 0
var is_dead: bool = false

var player_ref: Node2D
var head_angle: float = 0.0

func _ready():
	player_ref = get_tree().current_scene.find_child("Player")
	living_cells_count = length
	
	head_angle = randf() * TAU
	
	var initial_back_dir = Vector2.LEFT.rotated(head_angle)
	for i in range(length * 5):
		var hist_pos = global_position + (initial_back_dir * (i * cell_gap))
		point_history.append(hist_pos)
	
	for i in range(length):
		var new_cell = cell_scene.instantiate()
		
		if "damage" in new_cell: new_cell.damage = cell_damage
		if "health" in new_cell: new_cell.health = cell_health
			
		add_child(new_cell)
		cells.append(new_cell)
		
		new_cell.top_level = true 
		new_cell.z_index = 5 
		new_cell.scale = Vector2(0.8, 0.8) 
		
		if new_cell.has_signal("on_death"):
			new_cell.on_death.connect(_on_cell_death)
		
		if new_cell.has_method("set_damage_active"):
			new_cell.set_damage_active(true)
		elif new_cell.has_method("set_deferred"):
			new_cell.set_deferred("monitoring", true)
			new_cell.modulate = Color(2, 0.5, 0.5) 
			
		var target_distance = i * cell_gap
		new_cell.global_position = solve_position_at_distance(target_distance)

func _process(delta):
	if is_dead: return
	
	# IA: PERSEGUIR
	if is_instance_valid(player_ref):
		var dir_to_player = (player_ref.global_position - global_position).normalized()
		var target_angle = dir_to_player.angle()
		
		head_angle = rotate_toward(head_angle, target_angle, turn_speed * delta)
		var move_dir = Vector2.RIGHT.rotated(head_angle)
		global_position += move_dir * speed * delta
	
	# RASTRO
	var head_pos = global_position
	var ideal_back_angle = head_angle + PI
	
	for k in range(1, point_history.size()):
		var point = point_history[k]
		var vec_from_head = point - head_pos
		var dist = vec_from_head.length()
		
		if dist < 1.0: continue
		
		var lag = 1.0 / (1.0 + (dist * 0.05)) 
		var rotate_speed = body_alignment_speed * lag * delta
		
		var current_angle = vec_from_head.angle()
		var new_angle = lerp_angle(current_angle, ideal_back_angle, rotate_speed)
		
		point_history[k] = head_pos + Vector2(cos(new_angle), sin(new_angle)) * dist

	var dist_moved = global_position.distance_to(point_history[0])
	if dist_moved > 5.0:
		point_history.push_front(global_position)
	else:
		point_history[0] = global_position
		
	_maintain_history_integrity()
	
	# VISUAL
	if is_instance_valid(cells[0]):
		cells[0].global_position = global_position
		cells[0].rotation = head_angle
	
	for i in range(1, length):
		var cell = cells[i]
		if not is_instance_valid(cell): continue
		
		var target_distance = i * cell_gap
		var ideal_pos = solve_position_at_distance(target_distance)
		
		cell.global_position = cell.global_position.lerp(ideal_pos, path_smoothing * delta)
		
		var dist_prev = cell.global_position.distance_to(cells[i-1].global_position)
		if dist_prev < cell_gap * 0.6:
			var push = (cell.global_position - cells[i-1].global_position).normalized()
			if push == Vector2.ZERO: push = Vector2.RIGHT.rotated(head_angle + PI)
			cell.global_position = cells[i-1].global_position + (push * cell_gap * 0.7)
			
		var look_target = cells[i-1].global_position
		cell.rotation = (look_target - cell.global_position).angle()

func _maintain_history_integrity():
	var max_points = length * 15
	if point_history.size() > max_points:
		point_history.resize(max_points)
	
	var total_len = 0.0
	for k in range(point_history.size() - 1):
		total_len += point_history[k].distance_to(point_history[k+1])
	
	if total_len < length * cell_gap:
		var last = point_history.back()
		var tail_dir = Vector2.RIGHT.rotated(head_angle + PI)
		if point_history.size() > 1:
			tail_dir = (last - point_history[point_history.size()-2]).normalized()
		
		point_history.append(last + (tail_dir * 50.0))

func solve_position_at_distance(target_dist: float) -> Vector2:
	var traveled = 0.0
	for k in range(point_history.size() - 1):
		var p1 = point_history[k]
		var p2 = point_history[k+1]
		var len = p1.distance_to(p2)
		
		if traveled + len >= target_dist:
			var t = (target_dist - traveled) / len
			return p1.lerp(p2, t)
		traveled += len
	return point_history.back()

func _on_cell_death():
	living_cells_count -= 1
	if living_cells_count <= 0:
		die()

func die():
	is_dead = true
	
	# CORREÇÃO: Spawna XP ao morrer
	var game_manager = get_tree().current_scene.find_child("GameManager")
	if game_manager:
		game_manager.spawn_xp(global_position, 10) # 10 XP por Worm
	
	queue_free()
