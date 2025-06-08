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

const ROW_COUNT = 4
const DIR_COUNT = 4

func _ready() -> void:
	set_team_color(Color.WHITE_SMOKE)

func _process(_delta):
	pass

func set_team_color(color: Color) -> void:
	_team_color = color
	for row in get_children():
		for foosman in row.get_children():
			# only color nodes named "foosmen*"
			if not foosman.name.begins_with("foosmen"):
				continue
			var mesh = foosman.get_node("MeshInstance3D")
			var mat = mesh.get_active_material(0).duplicate()
			mat.albedo_color = color
			mesh.set_surface_override_material(0, mat)

func get_team_color() -> Color:
	return _team_color

func apply_nn_output(output: Array) -> void:
	var delta = get_process_delta_time()
	for row_idx in range(ROW_COUNT):
		var base = row_idx * DIR_COUNT
		var up = output[base]
		var down = output[base + 1]
		var left = output[base + 2]
		var right = output[base + 3]
		var dz = 0.0
		if up:
			dz -= move_speed * delta
		if down:
			dz += move_speed * delta
		rows[row_idx].translate(Vector3(0, 0, dz))
		var t = rows[row_idx].transform
		t.origin.z = clamp(t.origin.z, -z_clamp[row_idx], z_clamp[row_idx])
		rows[row_idx].transform = t
		if left:
			rows[row_idx].rotate_z(rot_speed * delta)
		if right:
			rows[row_idx].rotate_z(-rot_speed * delta)
