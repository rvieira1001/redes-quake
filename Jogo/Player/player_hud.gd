extends Control

@onready var crosshair = $Crosshair
@onready var indicator = $HitIndicator

func blink_crosshair():
	crosshair.modulate = Color.RED
	
	var tween: Tween = create_tween()
	tween.tween_property(crosshair, "modulate", Color.WHITE, 1.0)

func blink_indicator(color: Color):
	indicator.modulate = color
	
	var tween: Tween = create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, 1.0)
