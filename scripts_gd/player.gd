extends Marker3D

@onready var goalkeeper: Marker3D = $goalkeeper
@onready var defenders: Marker3D = $defenders
@onready var middle: Marker3D = $middle
@onready var strikers: Marker3D = $strikers
@onready var rows := [goalkeeper, defenders, middle, strikers]
var z_clamp := [10.0, 8.0, 4.0, 6.0]

@export var move_speed = 10.0
@export var rot_speed = 10.0

const ROW_COUNT = 4

var last_row_rotations := []

func _ready() -> void:
	set_team_color(Color.WHITE_SMOKE)
	last_row_rotations = []
	for row in rows:
		last_row_rotations.append(row.rotation.z)

func set_team_color(color: Color) -> void:
	for row in get_children():
		for foosman in row.get_children():
			if not foosman.name.begins_with("foosmen"):
				continue
			var mesh = foosman.get_node("MeshInstance3D")
			var mat = mesh.get_active_material(0).duplicate()
			mat.albedo_color = color
			mesh.set_surface_override_material(0, mat)

func apply_nn_output(output: Array) -> void:
	var delta = get_process_delta_time()
	if output.size() != ROW_COUNT * 2:
		return
	for row_idx in range(ROW_COUNT):
		var t_idx = row_idx * 2
		if output.size() < t_idx + 2:
			continue
		var t_state = int(output[t_idx])
		var r_state = int(output[t_idx+1])
		var dz = 0.0
		if t_state == -1:
			dz -= move_speed * delta
		elif t_state == 1:
			dz += move_speed * delta
		rows[row_idx].translate(Vector3(0, 0, dz))
		var t = rows[row_idx].transform
		t.origin.z = clamp(t.origin.z, -z_clamp[row_idx], z_clamp[row_idx])
		rows[row_idx].transform = t
		if r_state == -1:
			rows[row_idx].rotate_z(rot_speed * delta)
		elif r_state == 1:
			rows[row_idx].rotate_z(-rot_speed * delta)

func compute_row_translation_reward() -> float:
	# Reward is highest at center (z=0), decreases toward left/right, 0 at two points either side of center
	# We'll use a quadratic function: reward = 1 - (z / max_z_for_row)^2, but shifted so reward=0 at +/-half_max
	# For each row, compute normalized z in [-1,1] (centered), then apply gradient
	var reward := 0.0
	for i in range(ROW_COUNT):
		var z = rows[i].transform.origin.z
		var max_z = z_clamp[i]
		var half_max = max_z * 0.5
		# reward = 1 at z=0, 0 at z=+/-half_max, negative beyond
		var abs_z = abs(z)
		if abs_z <= half_max:
			reward += 1.0 - (abs_z / half_max)
		else:
			# linearly negative beyond half_max to max_z
			reward += -((abs_z - half_max) / (max_z - half_max))
	return reward / ROW_COUNT

func compute_rotation_reward() -> float:
	var reward := 0.0
	for i in range(ROW_COUNT):
		var prev_rot = last_row_rotations[i]
		var curr_rot = rows[i].rotation.z
		var delta_rot = curr_rot - prev_rot
		if delta_rot > 0.01:
			reward += 1.0
		elif abs(delta_rot) <= 0.01:
			reward -= 1.0
		elif delta_rot < -0.01:
			reward -= 2.0
		last_row_rotations[i] = curr_rot
	return reward / ROW_COUNT

func compute_total_reward() -> float:
	# Keep rotation reward as is, add translation reward as described
	return compute_rotation_reward() + compute_row_translation_reward()

func get_observation() -> Array:
	var obs = []
	for row in rows:
		var rel_z = row.transform.origin.z - transform.origin.z
		var rel_rot = row.rotation.z - rotation.z
		obs.append(rel_z)
		obs.append(rel_rot)
	return obs
