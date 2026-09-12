from pathlib import Path
p=Path('ultimate-sugar-rush/scripts/core/cafe_progress.gd');s=p.read_text(encoding='utf-8').replace('\t\tregion = 0\n\t\tboard_source','\t\tregion = 0\n\t\tstage = 0\n\t\tboard_source');p.write_text(s,encoding='utf-8')
p=Path('ultimate-sugar-rush/scripts/cafe/cafe_hub.gd');s=p.read_text(encoding='utf-8').replace('str(stats.get("coins",0))','str(int(stats.get("coins",0)))');p.write_text(s,encoding='utf-8')
p=Path('ultimate-sugar-rush/scripts/cafe/cafe_scene.gd');s=p.read_text(encoding='utf-8').replace('actor.wait = 3.0','actor.wait = 3.0\n\t\t\t\tnode.rotation.y = -PI*0.75 if node.name == "Mint" else PI');p.write_text(s,encoding='utf-8')
