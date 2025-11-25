extends CharacterBody2D

# --- CONFIGURAÇÕES GERAIS ---
@export var speed: float = 400.0
@export var health: int = 100
@export var friction: float = 15.0 

# --- DASH ---
@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.3
@export var dash_cooldown: float = 0.6

# --- ATAQUE ---
@export var attack_damage: int = 10
@export var attack_duration: float = 0.25
@export var attack_cooldown: float = 0.1
@export var attack_range: float = 70.0
@export var attack_offset: float = 60.0
@export var attack_impulse: float = 600.0 

# --- STAGGER & SHAKE ---
@export var stagger_duration: float = 0.2 
@export var stagger_knockback: float = 500.0 
@export var invulnerability_duration: float = 1.0 
@export var shake_decay: float = 10.0 

# --- HIT STOP (SLOW MOTION) ---
@export var hit_stop_scale: float = 0.05 
@export var hit_stop_duration_hit: float = 0.1 
@export var hit_stop_duration_hurt: float = 0.3 

# --- ÁUDIO (NOVO) ---
@export_group("Audio FX")
@export var sfx_attack: AudioStream # Som do "Whoosh" da espada
@export var sfx_dash: AudioStream   # Som de vento/impulso
@export var sfx_hit: AudioStream    # Som de impacto molhado/carne
@export var sfx_hurt: AudioStream   # Som de dor/pancada no player

# --- ESTADOS ---
enum State { MOVE, ATTACK, DASH, STAGGER }
var current_state = State.MOVE

# Variáveis de Controle
var is_invulnerable: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var last_faced_direction: Vector2 = Vector2.RIGHT 

# Screen Shake
var current_shake_strength: float = 0.0
@onready var camera = $Camera2D 

# Debug
var debug_attack_active: bool = false
var attack_visual_angle: float = 0.0 

func _process(delta):
	if current_shake_strength > 0:
		current_shake_strength = lerp(current_shake_strength, 0.0, shake_decay * delta)
		if camera:
			camera.offset = Vector2(
				randf_range(-current_shake_strength, current_shake_strength),
				randf_range(-current_shake_strength, current_shake_strength)
			)

func _physics_process(delta):
	match current_state:
		State.MOVE:
			state_move(delta)
		State.ATTACK:
			state_attack(delta)
		State.DASH:
			state_dash(delta)
		State.STAGGER:
			state_stagger(delta)
	
	queue_redraw()

# --- ESTADO 1: MOVIMENTO LIVRE ---
func state_move(delta):
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		velocity = input_vector * speed
		last_faced_direction = input_vector
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	if Input.is_action_just_pressed("attack"):
		start_attack()
		return

	if Input.is_action_just_pressed("dash") and input_vector != Vector2.ZERO:
		start_dash(input_vector)

# --- ESTADO 2: ATAQUE ---
func start_attack():
	current_state = State.ATTACK
	
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var attack_dir = last_faced_direction
	
	if input_vector != Vector2.ZERO:
		attack_dir = input_vector

	var angle = attack_dir.angle()
	var snapped_angle = round(angle / (PI / 4.0)) * (PI / 4.0)
	attack_dir = Vector2(cos(snapped_angle), sin(snapped_angle))
	
	attack_visual_angle = snapped_angle
	
	velocity = attack_dir * attack_impulse
	
	# TOCA SOM DE ATAQUE (Antes de saber se acertou)
	play_sfx(sfx_attack, 0.9, 1.1)
	
	perform_hitbox_check(attack_dir)
	
	debug_attack_active = true
	var original_modulate = modulate
	modulate = Color(1.5, 1.5, 0)
	
	await get_tree().create_timer(attack_duration).timeout
	
	modulate = original_modulate
	debug_attack_active = false
	
	if current_state == State.ATTACK:
		await get_tree().create_timer(attack_cooldown).timeout
		current_state = State.MOVE

func state_attack(delta):
	velocity = velocity.move_toward(Vector2.ZERO, friction * 100 * delta)
	move_and_slide()

func perform_hitbox_check(dir: Vector2):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = attack_range
	
	query.shape = shape
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var center = global_position + (dir * attack_offset)
	query.transform = Transform2D(0, center)
	
	var results = space_state.intersect_shape(query)
	var hit_something = false
	
	for result in results:
		var collider = result.collider
		if collider.get("is_dead"): continue
		if collider.has_method("take_damage"):
			collider.take_damage(attack_damage)
			hit_something = true
	
	if hit_something:
		apply_shake(5.0)
		apply_hit_stop(hit_stop_duration_hit)
		# TOCA SOM DE IMPACTO (Crunch)
		play_sfx(sfx_hit, 0.8, 1.0)

# --- ESTADO 3: DASH ---
func start_dash(dir):
	current_state = State.DASH
	dash_direction = dir
	is_invulnerable = true 
	modulate.a = 0.5
	
	# TOCA SOM DE DASH
	play_sfx(sfx_dash, 1.0, 1.2)
	
	await get_tree().create_timer(dash_duration).timeout
	
	modulate.a = 1.0
	is_invulnerable = false 
	
	if current_state == State.DASH:
		current_state = State.MOVE

func state_dash(delta):
	velocity = dash_direction * dash_speed
	move_and_slide()

# --- ESTADO 4: STAGGER ---
func state_stagger(delta):
	velocity = velocity.move_toward(Vector2.ZERO, friction * 80 * delta)
	move_and_slide()

func take_damage(amount):
	if is_invulnerable: return
	
	current_state = State.STAGGER
	is_invulnerable = true
	health -= amount
	print("Dano! Vida: ", health)
	
	# TOCA SOM DE DOR
	play_sfx(sfx_hurt, 0.8, 1.2)
	
	apply_shake(20.0)
	apply_hit_stop(hit_stop_duration_hurt)
	
	velocity = -last_faced_direction.normalized() * stagger_knockback
	
	modulate = Color(1, 0, 0)
	
	await get_tree().create_timer(stagger_duration).timeout
	
	modulate = Color(1, 1, 1)
	
	if health > 0:
		current_state = State.MOVE
		modulate.a = 0.5 
		await get_tree().create_timer(invulnerability_duration - stagger_duration).timeout
		modulate.a = 1.0
		is_invulnerable = false
	else:
		print("MORREU")
		get_tree().reload_current_scene()

func apply_shake(strength: float):
	current_shake_strength = max(current_shake_strength, strength)

func apply_hit_stop(duration: float):
	if Engine.time_scale < 1.0: return
	Engine.time_scale = hit_stop_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

# --- SISTEMA DE SOM DINÂMICO ---
func play_sfx(stream: AudioStream, min_pitch: float = 0.9, max_pitch: float = 1.1):
	if not stream: return
	
	# Cria um player temporário para permitir sobreposição de sons
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(min_pitch, max_pitch) # Variação para soar orgânico
	
	# Adiciona à cena atual (não ao player, para o som não cortar se o player morrer/sumir)
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	
	# Auto-destruição quando acabar o som
	audio_player.finished.connect(audio_player.queue_free)

# --- VISUAIS ---
func _draw():
	if current_state == State.MOVE:
		var pointer_end = last_faced_direction.normalized() * 40
		draw_line(Vector2.ZERO, pointer_end, Color(1, 1, 1, 0.3), 2.0)
	
	if debug_attack_active:
		var dir = Vector2.RIGHT.rotated(attack_visual_angle)
		var center = dir * attack_offset
		draw_circle(center, attack_range, Color(1, 1, 0, 0.5))
		draw_line(Vector2.ZERO, center, Color(1, 1, 0, 0.8), 2.0)
