extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func run() -> void:
	var save := root.get_node("SaveSystem")
	var retention := root.get_node("CafeRetention")
	var progress := root.get_node("CafeProgress")
	var rewards := root.get_node("CollectibleRewards")
	save.set_section("daily_cafe",{})
	save.set_section("weekly_cafe",{})
	save.set_section("daily_first_win",{})
	save.set_section("collections",{})
	var daily: Dictionary = retention.ensure_daily()
	check(daily.goals.size()==3,"Daily Café generates exactly three goals")
	for goal: Dictionary in daily.goals: retention.add_progress(str(goal.id),int(goal.target))
	check(retention.daily_complete(),"Generated daily goals can all be completed")
	var first_claim: Dictionary = retention.claim_perfect_day()
	check(not first_claim.is_empty() and retention.stamp_count()==1,"Perfect day awards one forgiving stamp")
	check(retention.claim_perfect_day().is_empty(),"Perfect day reward cannot be claimed twice")
	check(progress.can_enter_stage(0,0),"Ordinary boards remain replayable")
	var first_bonus: Dictionary = retention.board_first_win_bonus(0,0)
	var repeated_bonus: Dictionary = retention.board_first_win_bonus(0,0)
	check(not first_bonus.is_empty() and repeated_bonus.is_empty(),"Daily first-win bonus is granted exactly once")
	var weekly: Dictionary = retention.ensure_weekly()
	weekly.score=retention.WEEKLY_MILESTONES[0]
	save.set_value("weekly_cafe","state",weekly)
	check(retention.claim_weekly_milestone(0)>0,"Reached weekly milestone can be claimed")
	check(retention.claim_weekly_milestone(0)==0,"Weekly milestone cannot be claimed twice")
	var collection := {}
	for item_id: String in rewards.CATALOG: collection[item_id]=1
	save.set_value("collections","items",collection)
	var before: int = rewards.sprinkles()
	rewards.award_random()
	check(rewards.sprinkles()==before+10,"Duplicate collectibles convert into sprinkles")
	var set_id: String = rewards.ALBUM_SETS.keys()[0]
	check(rewards.set_complete(set_id) and rewards.claim_set_reward(set_id)>0,"Completed album set grants its reward")
	check(rewards.claim_set_reward(set_id)==0,"Album set reward cannot be claimed twice")
	print("Cafe retention: %d failures" % failures)
	quit(failures)
