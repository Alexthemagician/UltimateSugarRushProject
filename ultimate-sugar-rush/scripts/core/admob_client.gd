extends Admob

# The scene stays in production mode so Android exports receive the real App ID.
# Debug builds switch to Google's test ad units before Admob._ready() runs.
func _enter_tree() -> void:
	is_real = not OS.is_debug_build()

func _ready() -> void:
	if OS.has_feature("android"):
		super._ready()
