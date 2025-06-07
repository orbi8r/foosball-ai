extends Marker3D

var _team_color: Color = Color.WHITE_SMOKE

func _ready() -> void:
	set_team_color(Color.WHITE_SMOKE)

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
