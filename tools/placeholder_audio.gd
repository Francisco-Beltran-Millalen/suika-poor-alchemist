extends RefCounted
## Síntesis de los sonidos placeholder (44,1 kHz, 16 bits, mono). Sin `class_name`.
##
## Volumen bajo e igualado: todos los picos rondan `PEAK`.

const MIX_RATE: int = 44100
const PEAK: float = 0.3


static func drop() -> AudioStreamWAV:
	return _stream(_tone(110.0, 0.08, 18.0))


static func merge() -> AudioStreamWAV:
	return _stream(_tone(440.0, 0.15, 12.0))


## Dos tonos tipo campana, el segundo un poco después y más agudo.
static func merge_high() -> AudioStreamWAV:
	var samples: PackedFloat32Array = _tone(660.0, 0.6, 5.0)
	_mix_in(samples, _tone(990.0, 0.5, 6.0), 0.1)
	return _stream(samples)


## Pulso grave de 1 s. Empieza y termina en silencio, así el bucle no chasquea.
static func danger_loop() -> AudioStreamWAV:
	var count: int = MIX_RATE
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var envelope: float = 0.0
		if t < 0.3:
			envelope = pow(sin(PI * t / 0.3), 2.0)
		samples[i] = sin(TAU * 60.0 * t) * envelope
	return _stream(samples, true)


static func game_over() -> AudioStreamWAV:
	var count: int = int(1.2 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		phase += TAU * lerpf(400.0, 100.0, t / 1.2) / MIX_RATE
		samples[i] = sin(phase) * (1.0 - t / 1.2)
	return _stream(samples)


## Arpegio ascendente do–mi–sol–do con la última nota sostenida.
static func victory() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(2.2 * MIX_RATE))
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for i: int in notes.size():
		_mix_in(samples, _tone(notes[i], 1.6 if i == 3 else 0.5, 3.0), 0.2 * i)
	return _stream(samples)


static func ui_click() -> AudioStreamWAV:
	return _stream(_tone(1200.0, 0.03, 60.0))


## Zumbido de 4 s con bucle: frecuencias y trémolo de ciclos enteros en 4 s.
static func music() -> AudioStreamWAV:
	var count: int = 4 * MIX_RATE
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var tremolo: float = 0.75 + 0.25 * sin(TAU * 0.5 * t)
		samples[i] = (sin(TAU * 110.0 * t) + 0.5 * sin(TAU * 165.0 * t)) * tremolo
	return _stream(samples, true)


# Seno con ataque de 3 ms y caída exponencial.
static func _tone(frequency: float, seconds: float, decay: float) -> PackedFloat32Array:
	var count: int = int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var attack: float = minf(t / 0.003, 1.0)
		samples[i] = sin(TAU * frequency * t) * exp(-decay * t) * attack
	return samples


static func _mix_in(target: PackedFloat32Array, source: PackedFloat32Array, offset_seconds: float) -> void:
	var offset: int = int(offset_seconds * MIX_RATE)
	for i: int in source.size():
		if offset + i < target.size():
			target[offset + i] += source[i]


# Normaliza el pico a `PEAK` y empaqueta PCM de 16 bits.
static func _stream(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var peak: float = 0.0001
	for value: float in samples:
		peak = maxf(peak, absf(value))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] / peak * PEAK, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
