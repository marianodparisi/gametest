extends Node3D

# Efectos visuales y de sonido del auto: polvo al driftear, skidmarks,
# y sonido de motor procedural (pitch según velocidad).
# Se agrega como hijo de Car.tscn — encuentra todo solo.

const SKID_LIFETIME = 6.0
const DRIFT_THRESHOLD = 4.0  # Velocidad lateral mínima para considerar drift

var _car: RigidBody3D
var _dust_particles: Array[GPUParticles3D] = []
var _engine_player: AudioStreamPlayer3D
var _squeal_player: AudioStreamPlayer3D
var _skid_meshes: Array = []  # [{mesh, time}]
var _is_drifting: bool = false


func _ready() -> void:
	_car = get_parent()
	_setup_dust()
	_setup_engine_sound()
	_setup_squeal_sound()


# ── POLVO ────────────────────────────────────────────────────────────────────

func _setup_dust() -> void:
	# Un emisor de polvo por rueda trasera
	for side in [-0.75, 0.75]:
		var particles = GPUParticles3D.new()
		particles.emitting = false
		particles.amount = 24
		particles.lifetime = 0.9
		particles.position = Vector3(side, 0.0, 1.2)

		var mat = ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0.5)
		mat.spread = 35.0
		mat.initial_velocity_min = 1.5
		mat.initial_velocity_max = 3.5
		mat.gravity = Vector3(0, -2.0, 0)
		mat.scale_min = 0.4
		mat.scale_max = 1.2
		mat.color = Color(0.65, 0.58, 0.45, 0.5)
		particles.process_material = mat

		var mesh = SphereMesh.new()
		mesh.radius = 0.15
		mesh.height = 0.3
		mesh.radial_segments = 4
		mesh.rings = 2
		particles.draw_pass_1 = mesh

		var dust_mat = StandardMaterial3D.new()
		dust_mat.albedo_color = Color(0.65, 0.58, 0.45, 0.4)
		dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dust_mat.vertex_color_use_as_albedo = true
		mesh.material = dust_mat

		add_child(particles)
		_dust_particles.append(particles)


# ── SONIDO DE MOTOR ──────────────────────────────────────────────────────────

func _setup_engine_sound() -> void:
	# Generador de tono procedural — sin assets de audio externos
	_engine_player = AudioStreamPlayer3D.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.1
	_engine_player.stream = generator
	_engine_player.volume_db = -12.0
	_engine_player.max_distance = 40.0
	add_child(_engine_player)
	_engine_player.play()


func _setup_squeal_sound() -> void:
	# Chirrido de neumáticos: ruido blanco filtrado, solo audible al driftear
	_squeal_player = AudioStreamPlayer3D.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.1
	_squeal_player.stream = generator
	_squeal_player.volume_db = -60.0  # Arranca inaudible
	_squeal_player.max_distance = 30.0
	add_child(_squeal_player)
	_squeal_player.play()


var _squeal_phase: float = 0.0
var _squeal_volume: float = -60.0

func _fill_squeal_buffer(delta: float) -> void:
	# Volumen con fade según estado de drift
	var target_db = -14.0 if _is_drifting else -60.0
	_squeal_volume = lerp(_squeal_volume, target_db, 8.0 * delta)
	_squeal_player.volume_db = _squeal_volume

	var playback = _squeal_player.get_stream_playback()
	if playback == null:
		return

	# Tono agudo modulado + ruido = chirrido de goma
	var lateral = abs(_car.linear_velocity.dot(_car.global_transform.basis.x))
	var freq = 900.0 + lateral * 25.0
	var increment = freq / 22050.0

	var frames = playback.get_frames_available()
	for i in frames:
		var tone = sin(_squeal_phase * TAU)
		var noise = randf_range(-1.0, 1.0) * 0.45
		var v = clamp(tone * 0.5 + noise, -0.7, 0.7)
		playback.push_frame(Vector2(v, v) * 0.3)
		# Vibrato para que suene orgánico
		_squeal_phase = fmod(_squeal_phase + increment * (1.0 + sin(_squeal_phase * 0.01) * 0.1), 1.0)


var _phase: float = 0.0

func _fill_engine_buffer() -> void:
	var playback = _engine_player.get_stream_playback()
	if playback == null:
		return

	var speed = _car.linear_velocity.length()
	# Frecuencia base 50Hz en idle, sube hasta ~190Hz a fondo
	var freq = 50.0 + speed * 3.2
	var mix_rate = 22050.0
	var increment = freq / mix_rate

	var frames = playback.get_frames_available()
	for i in frames:
		# Onda con armónicos para sonar a motor y no a sinusoide pura
		var v = sin(_phase * TAU) * 0.5
		v += sin(_phase * TAU * 2.0) * 0.25
		v += sin(_phase * TAU * 0.5) * 0.25
		# Saturación leve
		v = clamp(v * 1.4, -0.8, 0.8)
		playback.push_frame(Vector2(v, v) * 0.4)
		_phase = fmod(_phase + increment, 1.0)


# ── LOOP PRINCIPAL ───────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	_update_drift_state()
	_update_dust()
	_update_skidmarks(delta)
	_fill_engine_buffer()
	_fill_squeal_buffer(delta)


func _update_drift_state() -> void:
	var right = _car.global_transform.basis.x
	var lateral_speed = abs(_car.linear_velocity.dot(right))
	_is_drifting = lateral_speed > DRIFT_THRESHOLD and _car.linear_velocity.length() > 5.0


func _update_dust() -> void:
	for p in _dust_particles:
		p.emitting = _is_drifting


func _update_skidmarks(delta: float) -> void:
	# Expirar marcas viejas
	var i = _skid_meshes.size() - 1
	while i >= 0:
		_skid_meshes[i]["time"] += delta
		if _skid_meshes[i]["time"] > SKID_LIFETIME:
			_skid_meshes[i]["mesh"].queue_free()
			_skid_meshes.remove_at(i)
		i -= 1

	if not _is_drifting:
		return

	# Dejar una marca por rueda trasera cada frame de física (decimado a 1 de cada 2)
	if Engine.get_physics_frames() % 2 != 0:
		return

	for side in [-0.75, 0.75]:
		var world_pos = _car.global_transform * Vector3(side, 0.02, 1.2)
		_drop_skid_mark(world_pos)


func _drop_skid_mark(pos: Vector3) -> void:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.22, 0.01, 0.5)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.08, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat

	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	# Las marcas viven en la escena raíz, no en el auto (quedan fijas en el piso)
	_car.get_parent().add_child(mi)
	mi.global_position = pos
	mi.global_rotation.y = _car.global_rotation.y

	_skid_meshes.append({"mesh": mi, "time": 0.0})
