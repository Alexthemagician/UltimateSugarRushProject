extends Node

signal retention_changed

const DAILY_TEMPLATES := [
	{"id":"boards", "label":"Clear %d puzzle boards", "target":2},
	{"id":"craft", "label":"Collect %d finished recipe batches", "target":2},
	{"id":"sales", "label":"Serve %d café customers", "target":5},
	{"id":"coins", "label":"Earn %d coins from café sales", "target":35},
	{"id":"regular", "label":"Fulfill a regular's exact request", "target":1},
	{"id":"decorate", "label":"Refresh one café decoration", "target":1},
	{"id":"visit", "label":"Visit a friend's café", "target":1}
]
const STAMP_REWARDS := [60,80,100,125,150,200,350]
const WEEKLY_MILESTONES := [5,12,22,35]

func _ready() -> void:
	ensure_daily()
	ensure_weekly()

func today() -> String:
	return Time.get_date_string_from_system()

func week_id() -> String:
	var date := Time.get_date_dict_from_system()
	var unix := Time.get_unix_time_from_datetime_dict({"year":date.year,"month":date.month,"day":date.day,"hour":12,"minute":0,"second":0})
	return str(int(unix / 604800.0))

func _available_templates() -> Array:
	var result := DAILY_TEMPLATES.duplicate(true)
	if CafeLife.REGULARS.is_empty(): result = result.filter(func(goal: Dictionary) -> bool: return goal.id != "regular")
	if not CafeOnline.configured(): result = result.filter(func(goal: Dictionary) -> bool: return goal.id != "visit")
	return result

func ensure_daily() -> Dictionary:
	var saved: Variant = SaveSystem.get_value("daily_cafe","state",{})
	if saved is Dictionary and str(saved.get("date","")) == today(): return saved
	var pool := _available_templates()
	var seed_value := hash(today() + str(SaveSystem.get_value("cafe_profile","name","Mallow")))
	var daily_rng := RandomNumberGenerator.new()
	daily_rng.seed = seed_value
	for index in range(pool.size()-1,0,-1):
		var swap_index := daily_rng.randi_range(0,index)
		var value: Variant = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = value
	var goals: Array = []
	for index in mini(3,pool.size()):
		var goal: Dictionary = pool[index].duplicate(true)
		goal.progress = 0
		goals.append(goal)
	var state := {"date":today(),"goals":goals,"claimed":false}
	SaveSystem.set_value("daily_cafe","state",state)
	SaveSystem.save_now()
	return state

func daily_state() -> Dictionary:
	return ensure_daily().duplicate(true)

func add_progress(kind: String, amount := 1) -> void:
	if amount <= 0: return
	var state := ensure_daily()
	var changed := false
	for goal: Dictionary in state.goals:
		if str(goal.id) != kind: continue
		goal.progress = mini(int(goal.target),int(goal.get("progress",0))+amount)
		changed = true
	if changed:
		SaveSystem.set_value("daily_cafe","state",state)
		_add_weekly_progress(kind,amount)
		SaveSystem.save_now()
		retention_changed.emit()

func daily_complete() -> bool:
	for goal: Dictionary in ensure_daily().goals:
		if int(goal.get("progress",0)) < int(goal.target): return false
	return true

func claim_perfect_day() -> Dictionary:
	var state := ensure_daily()
	if bool(state.claimed) or not daily_complete(): return {}
	state.claimed = true
	SaveSystem.set_value("daily_cafe","state",state)
	var stamps := int(SaveSystem.get_value("daily_cafe","stamps",0))
	var day := stamps % 7
	var coins: int = int(STAMP_REWARDS[day])
	var stats := GameDatabase.get_player_stats()
	stats.coins = int(stats.coins)+coins
	GameDatabase.upsert_record("player_stats",stats)
	SaveSystem.set_value("daily_cafe","stamps",stamps+1)
	var bonus := ""
	if day == 6:
		for id: String in CafeProgress.POOLS[(stamps/7)%CafeProgress.POOLS.size()]: CafeProgress.add_ingredient(id,2)
		bonus = " and a regional ingredient basket"
	SaveSystem.save_now()
	retention_changed.emit()
	return {"coins":coins,"stamp":day+1,"bonus":bonus}

func stamp_count() -> int:
	return int(SaveSystem.get_value("daily_cafe","stamps",0)) % 7

func ensure_weekly() -> Dictionary:
	var saved: Variant = SaveSystem.get_value("weekly_cafe","state",{})
	if saved is Dictionary and str(saved.get("week","")) == week_id(): return saved
	var categories := ["bakery","coffee","candy","cake","tea"]
	var state := {"week":week_id(),"category":categories[abs(hash(week_id()))%categories.size()],"score":0,"streak":0,"claimed":[]}
	SaveSystem.set_value("weekly_cafe","state",state)
	SaveSystem.save_now()
	return state

func weekly_state() -> Dictionary:
	return ensure_weekly().duplicate(true)

func _add_weekly_progress(kind: String, amount: int) -> void:
	var state := ensure_weekly()
	if kind in ["boards","craft","sales","regular"]:
		state.score = int(state.score)+amount
		SaveSystem.set_value("weekly_cafe","state",state)

func record_board_result(won: bool) -> void:
	var state := ensure_weekly()
	state.streak = int(state.streak)+1 if won else maxi(0,int(state.streak)-1)
	SaveSystem.set_value("weekly_cafe","state",state)
	if won: add_progress("boards",1)
	else:
		SaveSystem.save_now()
		retention_changed.emit()

func claim_weekly_milestone(index: int) -> int:
	var state := ensure_weekly()
	if index < 0 or index >= WEEKLY_MILESTONES.size() or int(state.score) < WEEKLY_MILESTONES[index] or index in state.claimed: return 0
	state.claimed.append(index)
	SaveSystem.set_value("weekly_cafe","state",state)
	var reward := 100*(index+1)
	var stats := GameDatabase.get_player_stats(); stats.coins=int(stats.coins)+reward; GameDatabase.upsert_record("player_stats",stats)
	SaveSystem.save_now(); retention_changed.emit()
	return reward

func board_first_win_bonus(region_index: int, stage_index: int) -> Dictionary:
	var key := "%s_%d_%d" % [today(),region_index,stage_index]
	if bool(SaveSystem.get_value("daily_first_win",key,false)): return {}
	SaveSystem.set_value("daily_first_win",key,true)
	var ingredient: String = CafeProgress.POOLS[region_index][stage_index % CafeProgress.POOLS[region_index].size()]
	CafeProgress.add_ingredient(ingredient,2)
	var stats := GameDatabase.get_player_stats(); stats.coins=int(stats.coins)+40; GameDatabase.upsert_record("player_stats",stats)
	SaveSystem.save_now()
	return {"coins":40,"ingredient":ingredient,"quantity":2}
