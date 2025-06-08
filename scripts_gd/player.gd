extends Marker3D

var _team_color: Color = Color.WHITE_SMOKE

@onready var goalkeeper: Marker3D = $goalkeeper
@onready var defenders: Marker3D = $defenders
@onready var middle: Marker3D = $middle
@onready var strikers: Marker3D = $strikers

@onready var rows := [goalkeeper, defenders, middle, strikers]
var z_clamp := [10.0, 8.0, 4.0, 6.0]

@export var move_speed = 10.0
@export var rot_speed = 10.0

func _ready() -> void:
	set_team_color(Color.WHITE_SMOKE)

func _process(delta):
	handle_input(delta, 2)

func set_team_color(color: Color) -> void:
	_team_color = color
	for row in get_children():
		for foosman in row.get_children():
			var mesh = foosman.get_node("MeshInstance3D")
			var mat = mesh.get_active_material(0).duplicate()
			mat.albedo_color = color
			mesh.set_surface_override_material(0, mat)

func get_team_color() -> Color:
	return _team_color

func handle_input(delta, foosmen_group):
	var input = Vector3.ZERO
	if Input.is_action_pressed("ui_up"):
		input.z -= move_speed * delta
	if Input.is_action_pressed("ui_down"):
		input.z += move_speed * delta
	
	rows[foosmen_group].translate(input)
	var max_z = z_clamp[foosmen_group]
	var t = rows[foosmen_group].transform
	t.origin.z = clamp(t.origin.z, -max_z, max_z)
	rows[foosmen_group].transform = t
	if Input.is_action_pressed("ui_left"):
		rows[foosmen_group].rotate_z(rot_speed * delta)
	if Input.is_action_pressed("ui_right"):
		rows[foosmen_group].rotate_z(-rot_speed * delta)
