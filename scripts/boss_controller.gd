extends Node

enum State { IDLE_TRACKING, CHASE, TELEGRAPH, ATTACK }
var current_state = State.IDLE_TRACKING

# --- TEMPOS ---
@export var track_duration: float = 2.0 
@export var chase_timeout: float = 3.0    
@export var telegraph_duration: float = 0.8
@export var attack_duration: float = 0.6

# --- MOVIMENTO ---
@export var min_attack_distance: float = 300.0 
@export var chase_speed: float = 150.0         
@export var lunge_distance: float = 600.0      
@export var whip_strength: float = 40.0
@export var turn_speed: float = 3.0 

# --- RECUO ---
@export var coil_distance: float = 150.0 

# --- SPAWNER DE INIMIGOS (SWARM) ---
@export_group("Swarm Spawner")
@export var fast_enemy_scene: PackedScene # Arraste FastEnemy.tscn aqui
@export var spawn_interval: float = 3.0   # Tempo entre spawns
@export var spawn_distance: float = 550.0 # Distância do player (fora da tela)

# --- ÁUDIO ---
@export_group("Audio FX")
@export var sfx_telegraph: AudioStream 
@export var sfx_attack: AudioStream    

var state_timer: float = 0.0
var spawn_timer: float = 0.0
var tentacles: Array = []
var tentacle_initial_pos: Dictionary = {} 
var player_ref: Node2D

var current_attacker_index: int = 0
var locked_target_pos: Vector2
var attack_start_pos: Vector2

func _ready():
	player_ref = get_tree().current_scene.find_child("Player")
	
	# Carrega automaticamente se não definido no Inspector (Facilita testes)
	if not fast_enemy_scene:
		# Tenta carregar do caminho padrão, ajuste se sua pasta for diferente
		if ResourceLoader.exists("res://FastEnemy.tscn"):
			fast_enemy_scene = load("res://FastEnemy.tscn")
		elif ResourceLoader.exists("res://scenes/enemy_cell.tscn"): # Fallback
			fast_enemy_scene = load("res://scenes/enemy_cell.tscn")
	
	for child in get_children():
		if child.has_method("look_at_position"):
			tentacles.append(child)
			tentacle_initial_pos[child] = child.global_position
			
			if child.has_signal("on_tentacle_destroyed"):
				child.on_tentacle_destroyed.connect(_on_tentacle_death.bind(child))

func _process(delta):
	if not is_instance_valid(player_ref): return
	
	if tentacles.is_empty():
		print("BOSS ELIMINADO!")
		set_process(false)
		return
	
	# --- LÓGICA DO SPAWNER ---
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_swarm_enemy()
	
	# --- LÓGICA DO BOSS ---
	state_timer += delta
	
	if current_attacker_index >= tentacles.size():
		current_attacker_index = 0
		
	var active_tentacle = tentacles[current_attacker_index]
	
	if not is_instance_valid(active_tentacle):
		change_state(State.IDLE_TRACKING)
		return

	update_background_tentacles(active_tentacle, delta)
	
	match current_state:
		# 1. RASTREAMENTO
		State.IDLE_TRACKING:
			update_single_idle_tentacle(active_tentacle, delta)
			active_tentacle.modulate = Color(1, 1, 1)
			
			if state_timer >= track_duration:
				var dist = active_tentacle.global_position.distance_to(player_ref.global_position)
				if dist > min_attack_distance:
					change_state(State.CHASE)
				else:
					change_state(State.TELEGRAPH)

		# 2. PERSEGUIÇÃO
		State.CHASE:
			var direction = (player_ref.global_position - active_tentacle.global_position).normalized()
			active_tentacle.global_position += direction * chase_speed * delta
			tentacle_initial_pos[active_tentacle] = active_tentacle.global_position
			
			smooth_look_at(active_tentacle, player_ref.global_position, delta)
			
			var dist = active_tentacle.global_position.distance_to(player_ref.global_position)
			if dist <= min_attack_distance or state_timer >= chase_timeout:
				change_state(State.TELEGRAPH)

		# 3. AVISO
		State.TELEGRAPH:
			active_tentacle.modulate = Color(10, 0, 0)
			
			var start_pos = tentacle_initial_pos[active_tentacle]
			var retreat_dir = (start_pos - player_ref.global_position).normalized()
			var coil_pos = start_pos + (retreat_dir * coil_distance)
			
			var shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0
			var target_pos = coil_pos + shake
			
			active_tentacle.global_position = active_tentacle.global_position.lerp(target_pos, 8.0 * delta)
			
			smooth_look_at(active_tentacle, player_ref.global_position, delta)
			
			if state_timer >= telegraph_duration:
				locked_target_pos = player_ref.global_position
				attack_start_pos = active_tentacle.global_position
				change_state(State.ATTACK)

		# 4. ATAQUE
		State.ATTACK:
			if state_timer <= delta:
				active_tentacle.set_damage_active(true)

			var t = state_timer / attack_duration
			var ease_t = 1.0 - pow(1.0 - t, 3.0) 
			
			var attack_vector = (locked_target_pos - attack_start_pos).normalized()
			var move_vec = attack_vector * lunge_distance
			
			var current_pos = attack_start_pos.lerp(attack_start_pos + move_vec, ease_t)
			active_tentacle.global_position = current_pos
			
			if t < 0.2:
				active_tentacle.look_at_position(active_tentacle.global_position + attack_vector)
			else:
				active_tentacle.head_angle += whip_strength * delta 
				
			if state_timer >= attack_duration:
				active_tentacle.set_damage_active(false)
				tentacle_initial_pos[active_tentacle] = active_tentacle.global_position
				next_turn()
				change_state(State.IDLE_TRACKING)

# --- FUNÇÃO DE SPAWN ---
func spawn_swarm_enemy():
	if not fast_enemy_scene: return
	
	var enemy = fast_enemy_scene.instantiate()
	
	# Posição aleatória em anel ao redor do player
	var angle = randf() * TAU
	var pos = player_ref.global_position + Vector2(cos(angle), sin(angle)) * spawn_distance
	
	enemy.global_position = pos
	
	# Adiciona na cena principal (irmão do BossController) para não se mover junto com o Boss
	get_parent().add_child(enemy)

# --- FUNÇÕES AUXILIARES ---

func _on_tentacle_death(tentacle):
	tentacles.erase(tentacle)
	change_state(State.IDLE_TRACKING)

func update_background_tentacles(except_tentacle, delta):
	for t in tentacles:
		if t != except_tentacle:
			update_single_idle_tentacle(t, delta)

func update_single_idle_tentacle(t, delta):
	var start_pos = tentacle_initial_pos[t]
	
	var dir_to_player = (player_ref.global_position - start_pos).normalized()
	var perp_vec = Vector2(-dir_to_player.y, dir_to_player.x)
	var unique_offset = float(t.get_instance_id())
	var wave = sin((Time.get_ticks_msec() / 1000.0 * 2.0) + unique_offset) * 40.0
	
	t.global_position = start_pos + (perp_vec * wave)
	smooth_look_at(t, player_ref.global_position, delta)

func smooth_look_at(t, target_pos, delta):
	var target_angle = (target_pos - t.global_position).angle()
	t.head_angle = rotate_toward(t.head_angle, target_angle, turn_speed * delta)

func next_turn():
	current_attacker_index += 1
	if current_attacker_index >= tentacles.size():
		current_attacker_index = 0

func change_state(new_state):
	current_state = new_state
	state_timer = 0.0
	
	match new_state:
		State.TELEGRAPH:
			play_sfx(sfx_telegraph, 0.9, 1.1)
		State.ATTACK:
			play_sfx(sfx_attack, 0.8, 1.2)

func play_sfx(stream: AudioStream, min_pitch: float = 0.9, max_pitch: float = 1.1):
	if not stream: return
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(min_pitch, max_pitch)
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
