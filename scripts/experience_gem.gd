extends Area2D

var xp_value: int = 10
var magnet_speed: float = 0.0
var player_ref: Node2D

func _ready():
	# Detecta o player na área de coleta
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Efeito de magnetismo (se o player tiver imã ou chegar perto)
	if is_instance_valid(player_ref):
		magnet_speed += 1000.0 * delta
		global_position = global_position.move_toward(player_ref.global_position, magnet_speed * delta)
		
		if global_position.distance_to(player_ref.global_position) < 10.0:
			collect()

func _on_body_entered(body):
	if body.name == "Player":
		# Começa a ser sugado em vez de coletar instantaneamente (Game Feel)
		player_ref = body

func collect():
	var gm = get_tree().current_scene.find_child("GameManager")
	if gm:
		gm.add_xp(xp_value)
	
	# Som de "Plim"
	queue_free()
