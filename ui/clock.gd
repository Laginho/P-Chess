extends Label

# One side's clock on the side panel (§8.7): redrawn every frame from core/clock.gd.

const Clock = preload("res://core/clock.gd")

# "w" or "b".
@export var side := "w"
# A core/clock.gd; blank until a game starts.
var clock


func _process(_delta: float) -> void:
	text = Clock.format(clock.left(side)) if clock else ""
