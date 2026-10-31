extends Node2D
## 震屏效果 - 在关卡Canvas上叠加偏移

var _intensity := 0.0
var _decay := 8.0
var _noise := FastNoiseLite.new()
var _time := 0.0

func _ready():
	_noise.seed = randi()
	_noise.frequency = 0.08

func add_shake(intensity: float) -> void:
	_intensity = max(_intensity, intensity)

func _process(delta: float) -> void:
	if _intensity <= 0.01:
		_intensity = 0.0
		position = Vector2.ZERO
		return
	
	_time += delta * 30
	_intensity = lerp(_intensity, 0.0, _decay * delta)
	
	var offset_x := _noise.get_noise_1d(_time) * _intensity * 8
	var offset_y := _noise.get_noise_1d(_time + 100) * _intensity * 6
	position = Vector2(offset_x, offset_y)
