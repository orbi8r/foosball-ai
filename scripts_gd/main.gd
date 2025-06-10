extends Node3D

const ROW_COUNT = 4
const OBS_SIZE = ROW_COUNT * 2

@onready var player_a: Marker3D = $players/player_0
@onready var player_b: Marker3D = $players/player_1

var udp: PacketPeerUDP
var server_ip := "127.0.0.1"
var server_port := 18233

var real_start := false
var player_a_color_set := false
var player_b_color_set := false
var comm_count := 0
var comm_last_report := 0

func _ready() -> void:
	udp = PacketPeerUDP.new()
	var bind_err = udp.bind(0)
	if bind_err != OK:
		push_error("UDP bind failed: %s" % bind_err)
	udp.set_dest_address(server_ip, server_port)

func _physics_process(_delta: float) -> void:
	if not player_a_color_set and player_a:
		player_a.set_team_color(Color.DODGER_BLUE)
		player_a_color_set = true
	if not player_b_color_set and player_b:
		player_b.set_team_color(Color.CRIMSON)
		player_b_color_set = true
	if not real_start and player_a_color_set and player_b_color_set:
		real_start = true
	# Per-tick UDP I/O
	if real_start:
		for pid in [0, 1]:
			var state = _pack_game_state(pid)
			var reward = _compute_player_reward(pid)
			var req = {"player_id": pid, "state": state, "reward": reward}
			var msg = JSON.stringify(req) + "\n"
			udp.put_packet(msg.to_utf8_buffer())
		while udp.get_available_packet_count() > 0:
			var pkt = udp.get_packet()
			var resp_str = pkt.get_string_from_utf8()
			var js2 = JSON.new()
			if js2.parse(resp_str) == OK:
				_unpack_and_apply(js2.get_data())
				comm_count += 1
		if Time.get_ticks_msec() - comm_last_report > 10000:
			print("[GD COMM] UDP comms in last 10s:", comm_count)
			comm_count = 0
			comm_last_report = Time.get_ticks_msec()

func _pack_game_state(player_id: int) -> Array:
	var arr = []
	arr.append(player_id)
	var obs = []
	if player_id == 0:
		obs = player_a.get_observation()
	else:
		obs = player_b.get_observation()
	for val in obs:
		arr.append(val)
	return arr

func _compute_player_reward(player_id: int) -> float:
	if player_id == 0:
		return player_a.compute_total_reward()
	else:
		return player_b.compute_total_reward()

func _unpack_and_apply(resp: Dictionary) -> void:
	var pid = int(resp.get("player_id", 0))
	var out = resp.get("output", [])
	if pid == 0:
		player_a.apply_nn_output(out)
	else:
		player_b.apply_nn_output(out)
