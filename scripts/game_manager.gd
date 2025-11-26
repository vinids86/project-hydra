extends Node

signal level_up_options_ready(options) 

# REFERÊNCIAS
@export var player: Node2D
@export var hud: CanvasLayer 
@export var xp_gem_scene: PackedScene 
@export var health_potion_scene: PackedScene

# INIMIGOS
@export var worm_scene: PackedScene     
@export var tentacle_scene: PackedScene 

# PROGRESSÃO
@export var base_spawn_rate: float = 2.0 
@export var tentacle_frequency: int = 20 
@export var potion_spawn_interval: float = 30.0

# SISTEMA DE UPGRADES (SCRIPT-ONLY)
# Arraste os arquivos .gd (Scripts) das cartas para cá!
# Mudei de Array[GDScript] para Array[Script] para corrigir o erro de atribuição no Editor.
@export var available_upgrades_scripts: Array[Script]

# ÁUDIO
@export_group("Audio FX")
@export var sfx_gem_collect: AudioStream 
@export var sfx_level_up: AudioStream    

# ESTADO DO JOGO
var game_time: float = 0.0
var spawn_timer: float = 0.0
var potion_timer: float = 0.0
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
	
	# SPAWN INIMIGOS
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_wave()
		var difficulty_factor = 1.0 + (game_time / 60.0) 
		spawn_timer = base_spawn_rate / difficulty_factor

	# SPAWN CURA
	potion_timer += delta
	if potion_timer >= potion_spawn_interval:
		spawn_health_potion()
		potion_timer = 0.0

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

# --- FUNÇÃO DE SPAWN CURA (RESTAURADA) ---
func spawn_health_potion():
	if not health_potion_scene: return
	
	var potion = health_potion_scene.instantiate()
	var angle = randf() * TAU
	var distance = randf_range(100.0, 500.0) 
	var pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	
	potion.global_position = pos
	get_tree().current_scene.call_deferred("add_child", potion)

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
	
	get_tree().paused = true
	
	# Gera as opções instanciando os scripts
	var options = get_random_upgrades(3)
	level_up_options_ready.emit(options)

# --- LÓGICA DE UPGRADES (SCRIPT BASED) ---

func get_random_upgrades(amount: int) -> Array[UpgradeCard]:
	var pool_scripts = available_upgrades_scripts.duplicate()
	pool_scripts.shuffle()
	
	var selected_scripts = pool_scripts.slice(0, min(amount, pool_scripts.size()))
	var instances: Array[UpgradeCard] = []
	
	# Instancia cada script para ler os dados do _init()
	for script in selected_scripts:
		var card_instance = script.new()
		if card_instance is UpgradeCard:
			instances.append(card_instance)
			
	return instances

func apply_upgrade(upgrade_id: String):
	# Procura o script correto pelo ID
	# Isso exige instanciar para checar o ID, o que não é super otimizado 
	# mas para 30-50 cartas num menu de pausa é imperceptível.
	
	var found_card = null
	
	for script in available_upgrades_scripts:
		var temp_instance = script.new()
		if temp_instance.id == upgrade_id:
			found_card = temp_instance
			break
	
	if found_card:
		print("Aplicando Upgrade: ", found_card.title)
		found_card.apply_upgrade(player)
	else:
		print("ERRO: Script da carta não encontrado para ID: ", upgrade_id)
			
	get_tree().paused = false

# --- HELPER DE ÁUDIO ---
func play_sfx(stream: AudioStream, min_pitch: float = 1.0, max_pitch: float = 1.0):
	if not stream: return
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(min_pitch, max_pitch)
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
