extends Node3D

@onready var player_a: Marker3D = $players/player_a
@onready var player_b: Marker3D = $players/player_b


func _ready() -> void:
	player_a.set_team_color(Color.DODGER_BLUE)
	player_b.set_team_color(Color.CRIMSON)
