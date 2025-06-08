extends Node3D

const ROW_COUNT = 4
const DIR_COUNT = 4
const INPUT_SIZE = 1 + ROW_COUNT * DIR_COUNT
const OUTPUT_SIZE = ROW_COUNT * DIR_COUNT

@onready var player_a: Marker3D = $players/player_0
@onready var player_b: Marker3D = $players/player_1

var udp: PacketPeerUDP
var server_ip := "127.0.0.1"
var server_port := 18233

var real_start := false
var player_a_color_set := false
var player_b_color_set := false

func _ready() -> void:
	print("[DEBUG GD] _ready: setting up UDP")
	udp = PacketPeerUDP.new()
	var bind_err = udp.bind(0)
	if bind_err != OK:
		push_error("UDP bind failed: %s" % bind_err)
	# Set remote address
	udp.set_dest_address(server_ip, server_port)
	print("[DEBUG GD] UDP bound and set to %s:%d" % [server_ip, server_port])

func _physics_process(_delta: float) -> void:
	# Apply team colors once
	if not player_a_color_set and player_a:
		player_a.set_team_color(Color.DODGER_BLUE)
		player_a_color_set = true
	if not player_b_color_set and player_b:
		player_b.set_team_color(Color.CRIMSON)
		player_b_color_set = true

	# Start per-tick I/O once both players ready
	if not real_start and player_a_color_set and player_b_color_set:
		real_start = true
		print("[DEBUG GD] Initialization complete, starting UDP I/O")

	# Per-tick UDP I/O
	if real_start:
		# send state for each player
		for pid in [0, 1]:
			var state = _pack_game_state(pid)
			var req = {"player_id": pid, "state": state}
			var msg = JSON.stringify(req) + "\n"
			var send_err = udp.put_packet(msg.to_utf8_buffer())
			if send_err != OK:
				push_error("UDP send failed: %s" % send_err)
		# process incoming packets
		while udp.get_available_packet_count() > 0:
			var pkt = udp.get_packet()
			var resp_str = pkt.get_string_from_utf8()
			var js2 = JSON.new()
			if js2.parse(resp_str) == OK:
				_unpack_and_apply(js2.get_data())

func _pack_game_state(player_id: int) -> Array:
	var arr = []
	arr.append(player_id)
	for i in range(INPUT_SIZE - 1):
		arr.append(0.0)
	return arr

func _unpack_and_apply(resp: Dictionary) -> void:
	var pid = int(resp.get("player_id", 0))
	var out = resp.get("output", [])
	if pid == 0:
		player_a.apply_nn_output(out)
	else:
		player_b.apply_nn_output(out)
