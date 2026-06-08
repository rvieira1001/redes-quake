extends Control

@onready var crosshair = $Crosshair

func blink_crosshair():
	crosshair.modulate = Color.RED
	
	var tween: Tween = create_tween()
	tween.tween_property(crosshair, "modulate", Color.WHITE, 1.0)
