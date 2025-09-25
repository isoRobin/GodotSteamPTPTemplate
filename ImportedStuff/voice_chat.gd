extends Node3D

@export var voice_player : RaytracedAudioPlayer3D
@export var mic : AudioStreamPlayer

var buffer_size : int = 512
var bus : String 
var bus_idx : int
var capture : AudioEffectCapture 
var stream : AudioStreamGeneratorPlayback 


func _ready() -> void:
	bus = mic.bus
	bus_idx = AudioServer.get_bus_index(bus)
	capture = AudioServer.get_bus_effect(bus_idx, 0)
	if is_multiplayer_authority():
		mic.stream = AudioStreamMicrophone.new()
		mic.play()
		$RaytracedAudioListener.make_current()
	else: 
		mic.stop()
		voice_player.play()
		stream = voice_player.get_stream_playback()
	if multiplayer.get_unique_id() == 1:
		voice_player.stop()

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		check_mic()

func check_mic():
	buffer_size = capture.get_frames_available()

	var voice_data : PackedVector2Array = capture.get_buffer(buffer_size)
	send_voice.rpc(voice_data)
	capture.clear_buffer()
	pass

@rpc("any_peer", "call_remote", "reliable", 2)
func send_voice(data : PackedVector2Array):
	if not data.is_empty():
		for i in range(0, data.size() - 1):
			stream.push_frame(data[i])
