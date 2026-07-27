extends Node

var streams: Dictionary = {}


func _ready() -> void:
	streams = {
		"ui": _make_tone(520.0, 0.055, 0.18),
		"hit": _make_tone(150.0, 0.11, 0.28),
		"pickup": _make_tone(760.0, 0.13, 0.2),
		"quest": _make_tone(620.0, 0.25, 0.18),
	}


func play_ui() -> void:
	_play("ui")


func play_hit() -> void:
	_play("hit")


func play_pickup() -> void:
	_play("pickup")


func play_quest() -> void:
	_play("quest")


func stop_all() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()


func _play(sound_name: String) -> void:
	if not streams.has(sound_name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = streams[sound_name]
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _make_tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in range(sample_count):
		var progress := float(index) / float(maxi(1, sample_count - 1))
		var envelope := sin(PI * progress)
		var sample := int(
			sin(TAU * frequency * float(index) / float(sample_rate))
			* 32767.0 * amplitude * envelope
		)
		data.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
