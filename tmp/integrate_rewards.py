from pathlib import Path
root=Path('ultimate-sugar-rush')
p=root/'project.godot';s=p.read_text(encoding='utf-8').replace('CollectibleRewards="*res://scripts/core/collectible_rewards.gd"','CollectibleRewards="*res://scripts/core/collectible_rewards.gd"\nCafeProgress="*res://scripts/core/cafe_progress.gd"');p.write_text(s,encoding='utf-8')
p=root/'scripts/core/scene_router.gd';s=p.read_text(encoding='utf-8').replace('\tvar result: Error = get_tree().change_scene_to_file(scene_path)','\tif scene_path.begins_with("res://scenes/merge/") or scene_path.begins_with("res://scenes/match3/"):\n\t\tCafeProgress.begin_board(scene_path)\n\tvar result: Error = get_tree().change_scene_to_file(scene_path)');p.write_text(s,encoding='utf-8')
p=root/'scripts/core/collectible_rewards.gd';s=p.read_text(encoding='utf-8').replace('\tawait board.play_completion_clear()','\tvar receipt := CafeProgress.award_board(root.scene_file_path)\n\tawait board.play_completion_clear()').replace('reward_name.size = Vector2(900, 130)','reward_name.size = Vector2(900, 130)\n\tvar pantry_reward := Label.new()\n\tpantry_reward.text = CafeProgress.reward_text(receipt)\n\tpantry_reward.position = Vector2(60,1190)\n\tpantry_reward.size = Vector2(960,160)\n\tpantry_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\tpantry_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\tpantry_reward.add_theme_font_size_override("font_size",28)\n\tshade.add_child(pantry_reward)');p.write_text(s,encoding='utf-8')
for name in ['merge_game','cake_merge_game','cookie_merge_game','ice_cream_merge_game','mixed_merge_game','candy_match_game','variant_match_game']:
 p=root/f'scripts/ui/{name}.gd';s=p.read_text(encoding='utf-8');lines=s.splitlines()
 for i,line in enumerate(lines):
  if 'replace_scene("res://scenes/map/world_map.tscn")' in line and any('play_completion(' in x for x in lines[max(0,i-3):i]):
   lines[i]=line.replace('"res://scenes/map/world_map.tscn"','CafeProgress.HUB')
 p.write_text('\n'.join(lines)+'\n',encoding='utf-8')
p=root/'scripts/ui/boot_screen.gd';s=p.read_text(encoding='utf-8').replace('SceneRouter.go_to_scene("res://scenes/map/world_map.tscn")','SceneRouter.go_to_scene(CafeProgress.HUB)');p.write_text(s,encoding='utf-8')
