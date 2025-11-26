extends Node

# SINAIS PARA A UI
signal level_up_options_ready(options) # Avisa a HUD para mostrar as cartas

# REFERÊNCIAS
@export var player: Node2D
@export var hud: CanvasLayer 
@export var xp_gem_scene: PackedScene 

# INIMIGOS
@export var worm_scene: PackedScene     
@export var tentacle_scene: PackedScene 

# PROGRESSÃO
@export var base_spawn_rate: float = 2.0 
@export var tentacle_frequency: int = 20 

# ÁUDIO
@export_group("Audio FX")
@export var sfx_gem_collect: AudioStream 
@export var sfx_level_up: AudioStream    

# BANCO DE DADOS DE UPGRADES (DEFINIÇÃO)
# Aqui definimos o "Deck" de cartas possíveis
var upgrade_database = [
	{
		"id": "damage_up",
		"title": "Lâmina Voraz",
		"description": "Aumenta o dano dos seus ataques em +5.",
		"rarity": "comum"
	},
	{
		"id": "attack_speed",
		"title": "Fúria Célere",
		"description": "Reduz o tempo entre ataques em 15%.",
		"rarity": "comum"
	},
	{
		"id": "move_speed",
		"title": "Passo Fantasma",
		"description": "Aumenta sua velocidade de movimento em +15%.",
		"rarity": "comum"
	}
]

# ESTADO DO JOGO
var game_time: float = 0.0
var spawn_timer: float = 0.0
var spawn_counter: int = 0 

# SISTEMA DE XP
var current_xp: int = 0
var current_level: int = 1
var xp_to_next_level: int = 100
@export var xp_growth_factor: float = 1.5 

@export var max_enemies: int = 100

func _ready():
	await get_tree().process_frame
	
	if not player:
		player = get_tree().current_scene.find_child("Player")
	
	if player and hud:
		player.health_changed.connect(hud.update_health)
		if hud.has_method("update_health"):
			hud.update_health(player.health, player.max_health)
		if hud.has_method("update_xp"):
			hud.update_xp(current_xp, xp_to_next_level, current_level)

func _process(delta):
	if not is_instance_valid(player): return
	
	game_time += delta
	
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_wave()
		var difficulty_factor = 1.0 + (game_time / 60.0) 
		spawn_timer = base_spawn_rate / difficulty_factor

func spawn_wave():
	if get_tree().get_node_count_in_group("Enemies") >= max_enemies:
		return

	var scene_to_spawn = worm_scene
	spawn_counter += 1
	
	if spawn_counter >= tentacle_frequency:
		scene_to_spawn = tentacle_scene
		spawn_counter = 0 
		print("ALERTA: TENTÁCULO SPAWNOU!")
	
	if not scene_to_spawn: return
	
	var enemy = scene_to_spawn.instantiate()
	enemy.add_to_group("Enemies")
	
	var angle = randf() * TAU
	var distance = 700.0 
	var pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	
	enemy.global_position = pos
	
	if "damage" in enemy:
		enemy.damage += int(game_time / 60.0) * 2
	
	get_parent().add_child(enemy)

# --- SISTEMA DE XP ---
func spawn_xp(pos: Vector2, amount: int):
	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate()
		gem.global_position = pos
		gem.xp_value = amount
		get_tree().current_scene.call_deferred("add_child", gem)

func add_xp(amount: int):
	current_xp += amount
	play_sfx(sfx_gem_collect, 0.9, 1.2)
	
	if current_xp >= xp_to_next_level:
		level_up()
	
	if hud and hud.has_method("update_xp"):
		hud.update_xp(current_xp, xp_to_next_level, current_level)

func level_up():
	current_level += 1
	play_sfx(sfx_level_up, 1.0, 1.0)
	
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * xp_growth_factor)
	
	print("LEVEL UP! Nível: ", current_level)
	
	if hud and hud.has_method("update_xp"):
		hud.update_xp(current_xp, xp_to_next_level, current_level)
	
	# 1. PAUSA O JOGO
	get_tree().paused = true
	
	# 2. SORTEIA AS CARTAS
	var options = get_random_upgrades(3)
	
	# 3. ENVIA PARA A UI (HUD)
	# A HUD deve se conectar a este sinal para abrir o menu
	level_up_options_ready.emit(options)

# --- LÓGICA DE UPGRADES ---

func get_random_upgrades(amount: int) -> Array:
	var pool = upgrade_database.duplicate()
	pool.shuffle()
	# Pega os X primeiros (ou todos se tiver menos que X)
	return pool.slice(0, min(amount, pool.size()))

# Função chamada pela UI quando o jogador clica numa carta
func apply_upgrade(upgrade_id: String):
	print("Aplicando Upgrade: ", upgrade_id)
	
	match upgrade_id:
		"damage_up":
			player.attack_damage += 5
		"attack_speed":
			player.attack_cooldown = max(0.1, player.attack_cooldown * 0.85) # Reduz 15%
		"move_speed":
			player.speed += 50.0
			
	# 4. DESPAUSA O JOGO
	get_tree().paused = false

# --- HELPER DE ÁUDIO ---
func play_sfx(stream: AudioStream, min_pitch: float = 1.0, max_pitch: float = 1.0):
	if not stream: return
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(min_pitch, max_pitch)
	# IMPORTANTE: O som precisa ser process_mode = ALWAYS para tocar durante a pausa
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
