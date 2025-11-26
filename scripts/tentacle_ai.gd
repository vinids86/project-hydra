extends Node2D

# Estados da IA Individual
enum State { IDLE, CHASE, PREPARE_ATTACK, ATTACK, RECOVER }
var current_state = State.IDLE

# REFERÊNCIAS
@onready var body = $TentacleBody 
var player: Node2D

# CONFIGURAÇÕES DE COMBATE
@export var attack_range: float = 300.0
@export var aggro_range: float = 800.0
@export var move_speed: float = 120.0
@export var damage: int = 10

# ÁUDIO
@export_group("Audio FX")
@export var sfx_telegraph: AudioStream 
@export var sfx_attack: AudioStream    

# TIMERS INTERNOS
var state_timer: float = 0.0
var attack_cooldown: float = 0.0

# VARIÁVEIS DE ATAQUE
var attack_start_pos: Vector2
var attack_target_pos: Vector2

func _ready():
	player = get_tree().current_scene.find_child("Player")
	
	if body:
		if body.has_method("set_damage_active"):
			body.set_damage_active(false)
		body.cell_damage = damage
		
		# CORREÇÃO CRÍTICA: Conecta o sinal de morte do corpo à IA
		if body.has_signal("on_tentacle_destroyed"):
			body.on_tentacle_destroyed.connect(_on_body_destroyed)

func _process(delta):
	if not is_instance_valid(player) or not body: return
	
	state_timer += delta
	attack_cooldown -= delta
	
	match current_state:
		# 1. IDLE
		State.IDLE:
			body.look_at_position(player.global_position)
			var dist = global_position.distance_to(player.global_position)
			
			if dist < attack_range and attack_cooldown <= 0:
				change_state(State.PREPARE_ATTACK)
			elif dist < aggro_range:
				change_state(State.CHASE)

		# 2. PERSEGUIÇÃO
		State.CHASE:
			body.look_at_position(player.global_position)
			var dir = (player.global_position - global_position).normalized()
			global_position += dir * move_speed * delta
			
			var dist = global_position.distance_to(player.global_position)
			if dist < attack_range and attack_cooldown <= 0:
				change_state(State.PREPARE_ATTACK)

		# 3. PREPARAÇÃO
		State.PREPARE_ATTACK:
			attack_target_pos = player.global_position
			attack_start_pos = global_position
			
			var retreat_dir = (global_position - player.global_position).normalized()
			var coil_pos = attack_start_pos + (retreat_dir * 100.0)
			global_position = global_position.lerp(coil_pos, 3.0 * delta)
			
			body.head_angle += sin(state_timer * 20.0) * 0.1
			
			if state_timer >= 0.8: 
				change_state(State.ATTACK)

		# 4. ATAQUE
		State.ATTACK:
			if state_timer == 0.0 + delta: 
				if body.has_method("set_damage_active"): body.set_damage_active(true)
			
			var duration = 0.5
			var t = state_timer / duration
			var ease_t = 1.0 - pow(1.0 - t, 3.0) 
			
			var lunge_vec = (attack_target_pos - attack_start_pos).normalized() * (attack_range + 200.0)
			global_position = attack_start_pos.lerp(attack_start_pos + lunge_vec, ease_t)
			
			body.head_angle += 30.0 * delta
			
			if state_timer >= duration:
				change_state(State.RECOVER)

		# 5. RECUPERAÇÃO
		State.RECOVER:
			if body.has_method("set_damage_active"): body.set_damage_active(false)
			
			if state_timer >= 1.0:
				attack_cooldown = 1.0
				change_state(State.IDLE)

func change_state(new_state):
	current_state = new_state
	state_timer = 0.0
	
	if body:
		match new_state:
			State.PREPARE_ATTACK: 
				body.modulate = Color(3, 0.5, 0.5)
				play_sfx(sfx_telegraph, 0.9, 1.1) 
			State.ATTACK: 
				body.modulate = Color(5, 1, 1)
				play_sfx(sfx_attack, 0.8, 1.2) 
			State.RECOVER: 
				body.modulate = Color(0.7, 0.7, 0.7)
			_: 
				body.modulate = Color(1, 1, 1)

func _on_body_destroyed():
	# Dropa XP
	var game_manager = get_tree().current_scene.find_child("GameManager")
	if game_manager:
		game_manager.spawn_xp(global_position, 50) # Valor alto para Elite
	
	# Remove a IA (Isso para os sons e o processamento imediatamente)
	queue_free()

func play_sfx(stream: AudioStream, min_pitch: float = 0.9, max_pitch: float = 1.1):
	if not stream: return
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(min_pitch, max_pitch)
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
