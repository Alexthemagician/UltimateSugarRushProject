extends "res://scripts/cafe/cafe_region.gd"

func _ready() -> void:
	CafeProgress.region = 0
	_reconcile_saved_unlocks()
	# Preserve the original development access to boards 5–8.
	for level in [5,6,7,8]: SaveSystem.set_value("progression","level_%d_unlocked" % level,true)
	super._ready()

func _reconcile_saved_unlocks() -> void:
	var cookie_objectives := SaveSystem.get_section("cookie_merge_objectives")
	var cookie_boxes := [
		"chocolate_chip_cookie_box",
		"pink_sugar_cookie_box",
		"sandwich_cookie_box",
		"lucky_cookie_box",
	]
	for item_id: String in cookie_boxes:
		if int(cookie_objectives.get(item_id, 0)) < 8:
			return
	SaveSystem.set_value("progression", "level_3_complete", true)
	SaveSystem.set_value("progression", "level_4_unlocked", true)
	SaveSystem.save_now()


