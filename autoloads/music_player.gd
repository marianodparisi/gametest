extends Node

# Música generativa estilo chill/synth — sin assets de audio.
# Pads de acordes + arpegio suave. Progresión: Am → F → C → G.

const MIX_RATE = 22050.0
const CHORD_DURATION = 4.0   # Segundos por acorde
const ARP_INTERVAL = 0.25    # Segundos entre notas del arpegio

# Frecuencias (Hz) de cada acorde: [fundamental, tercera, quinta] una octava baja
const CHORDS = [
	[220.00, 261.63, 329.63],  # Am
	[174.61, 220.00, 261.63],  # F
	[130.81, 164.81, 196.00],  # C
	[196.00, 246.94, 293.66],  # G
]
# Notas del arpegio por acorde (octava arriba)
const ARP_NOTES = [
	[440.0, 523.25, 659.25, 523.25],
	[349.23, 440.0, 523.25, 440.0],
	[261.63, 329.63, 392.0, 329.63],
	[392.0, 493.88, 587.33, 493.88],
]

var _player: AudioStreamPlayer
var _phases: Array[float] = [0.0, 0.0, 0.0]  # Una fase por voz del pad
var _arp_phase: float = 0.0
var _time: float = 0.0
var _enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Sigue sonando en pausa

	_player = AudioStreamPlayer.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.15
	_player.stream = generator
	_player.volume_db = -16.0
	_player.bus = "Master"
	add_child(_player)
	_player.play()


func set_enabled(on: bool) -> void:
	_enabled = on
	if _player:
		_player.stream_paused = not on


func set_volume_db(db: float) -> void:
	if _player:
		_player.volume_db = db


func _process(delta: float) -> void:
	if not _enabled:
		return
	_fill_buffer(delta)


func _fill_buffer(_delta: float) -> void:
	var playback = _player.get_stream_playback()
	if playback == null:
		return

	var frames = playback.get_frames_available()
	if frames <= 0:
		return

	var progression_time = fmod(_time, CHORD_DURATION * CHORDS.size())
	var chord_index = int(progression_time / CHORD_DURATION)
	var chord = CHORDS[chord_index]
	var arp_notes = ARP_NOTES[chord_index]

	for i in frames:
		var sample = 0.0

		# Pad: tres voces sinusoidales suaves
		for v in 3:
			var inc = chord[v] / MIX_RATE
			_phases[v] = fmod(_phases[v] + inc, 1.0)
			sample += sin(_phases[v] * TAU) * 0.11

		# Arpegio: nota corta con envolvente
		var arp_t = fmod(_time, ARP_INTERVAL)
		var arp_index = int(fmod(_time / ARP_INTERVAL, arp_notes.size()))
		var envelope = max(0.0, 1.0 - arp_t / ARP_INTERVAL) * 0.5
		var arp_inc = arp_notes[arp_index] / MIX_RATE
		_arp_phase = fmod(_arp_phase + arp_inc, 1.0)
		sample += sin(_arp_phase * TAU) * envelope * 0.14

		# Fade entre acordes para evitar clicks
		var chord_t = fmod(_time, CHORD_DURATION)
		if chord_t < 0.1:
			sample *= chord_t / 0.1
		elif chord_t > CHORD_DURATION - 0.1:
			sample *= (CHORD_DURATION - chord_t) / 0.1

		playback.push_frame(Vector2(sample, sample))
		_time += 1.0 / MIX_RATE
