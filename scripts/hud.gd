extends CanvasLayer

# Com o %, a Godot acha o nó automaticamente na cena
@onready var health_bar = %HealthBar
@onready var xp_bar = %XPBar
@onready var level_label = %LevelLabel

func update_health(current_hp, max_hp):
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

func update_xp(current_xp, xp_required, level):
	if xp_bar:
		xp_bar.max_value = xp_required
		xp_bar.value = current_xp
	
	if level_label:
		level_label.text = "NÍVEL " + str(level)
