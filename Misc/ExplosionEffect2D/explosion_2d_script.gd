extends Node2D

## 2D爆炸粒子 - 播放后自动销毁

func play_explosion():
	$Particles.emitting = true
	await get_tree().create_timer(0.8).timeout
	queue_free()

func play_small_explosion():
	$Particles.amount = 12
	$Particles.lifetime = 0.4
	$Particles.emitting = true
	await get_tree().create_timer(0.6).timeout
	queue_free()
